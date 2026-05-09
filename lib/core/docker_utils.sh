#!/usr/bin/env bash
# Docker and Docker Compose utility functions

# Source common functions
# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/common.sh"

# Get script directory (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICES_DIR="${SCRIPT_DIR}/services"

# Allow custom Docker Compose file via environment variable
COMPOSE_FILE=${COMPOSE_FILE:-docker-compose.yml}

# Sanitize COMPOSE_FILE
# Reject any value containing non-alphanumeric, dash, underscore, dot or slash
# Updated regex to properly handle file paths and prevent directory traversal
if [[ ! "$COMPOSE_FILE" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ "$COMPOSE_FILE" =~ \.\. ]] || [[ "$COMPOSE_FILE" =~ ^/ ]]; then
    echo "❌ Invalid COMPOSE_FILE value: $COMPOSE_FILE" >&2
    echo "   Allowed characters: A-Z, a-z, 0-9, ., _, -, /" >&2
    echo "   Cannot start with / or contain .." >&2
    exit 1
fi

# Default compose command (before set_compose_cmd detects GPU/ARM overrides)
# Initialize with a basic command that will be updated by set_compose_cmd
COMPOSE_CMD=(docker-compose -f "${SERVICES_DIR}/${COMPOSE_FILE}")
COMPOSE_WORKDIR="${SERVICES_DIR}"

# Build docker-compose command with optional GPU and ARM overrides if present
# Podman is preferred over Docker for rootless security
set_compose_cmd() {
    local files=( -f "${SERVICES_DIR}/${COMPOSE_FILE}" )

    # Check for ARM64 architecture
    if is_arm64 && [ -f "${SERVICES_DIR}/docker-compose.arm.yml" ]; then
        if [ "${AIXCL_VERBOSE:-0}" = "1" ]; then
            echo "Detected ARM64 architecture. Enabling ARM platform overrides."
        fi
        files+=( -f "${SERVICES_DIR}/docker-compose.arm.yml" )
    fi

    # Detect container runtime first — GPU overlay selection depends on it
    local cmd=()
    local bin="docker"

    # Podman preferred for rootless security
    if command -v podman &>/dev/null && podman info &>/dev/null; then
        if command -v podman-compose &>/dev/null; then
            bin="podman"
            cmd=(podman-compose)
            [ "${AIXCL_VERBOSE:-0}" = "1" ] && echo "Using Podman (rootless mode) with podman-compose"
        else
            echo "⚠️  Podman found but podman-compose not installed" >&2
            echo "   Install: pip3 install podman-compose" >&2
            echo "   Falling back to Docker..." >&2
        fi
    fi

    # Docker fallback
    if [[ "$bin" == "docker" ]]; then
        if command -v docker &>/dev/null; then
            [ "${AIXCL_VERBOSE:-0}" = "1" ] && echo "Using Docker (daemon mode)"
        else
            echo "❌ Error: Neither Podman nor Docker found. Cannot continue." >&2
            exit 1
        fi
    fi

    # Export DOCKER_BIN for use in other scripts
    export DOCKER_BIN="$bin"
    if [ "${AIXCL_VERBOSE:-0}" = "1" ]; then
        echo "Using container engine: $DOCKER_BIN"
    fi

    # Check for NVIDIA GPU hardware AND toolkit availability
    # Runtime must be detected above before this block runs
    if has_nvidia && has_nvidia_container_toolkit && [ -f "${SERVICES_DIR}/docker-compose.gpu.yml" ]; then
        if [ "${AIXCL_VERBOSE:-0}" = "1" ]; then
            echo "Detected NVIDIA GPU hardware and Container Toolkit. Enabling GPU overrides."
        fi
        files+=( -f "${SERVICES_DIR}/docker-compose.gpu.yml" )
        # Podman ignores deploy.resources.reservations.devices — load CDI overlay instead
        if [[ "$bin" == "podman" ]] && [ -f "${SERVICES_DIR}/docker-compose.gpu-podman.yml" ]; then
            if [ "${AIXCL_VERBOSE:-0}" = "1" ]; then
                echo "Podman runtime detected: enabling CDI GPU device overlay."
            fi
            files+=( -f "${SERVICES_DIR}/docker-compose.gpu-podman.yml" )
        fi
    else
        if [ "${AIXCL_VERBOSE:-0}" = "1" ]; then
            echo "No NVIDIA GPU support detected. Running without GPU overrides."
        fi
    fi

    if [ ${#cmd[@]} -eq 0 ]; then
        if command -v docker &>/dev/null && docker compose version &> /dev/null; then
            cmd=(docker compose)
        elif command -v docker-compose &>/dev/null; then
            cmd=(docker-compose)
        elif command -v podman-compose &>/dev/null; then
            cmd=(podman-compose)
        else
            echo "❌ Error: No Docker Compose compatible tool found (docker compose, docker-compose, or podman-compose)" >&2
            exit 1
        fi
    fi

    COMPOSE_CMD=("${cmd[@]}" -p "aixcl" "${files[@]}")
    COMPOSE_WORKDIR="${SERVICES_DIR}"
    
    # Set and export DOCKER_SOCK for use in docker-compose files
    DOCKER_SOCK=$(get_docker_sock)
    export DOCKER_SOCK
    if [ "${AIXCL_VERBOSE:-0}" = "1" ]; then
        echo "Using Docker socket: $DOCKER_SOCK"
    fi
}

# Helper function to run docker-compose commands from the services directory
# Filters out verbose podman-compose output (env vars, volumes, JSON config)
# Only shows errors and important status messages
run_compose() {
    if [ -z "${COMPOSE_WORKDIR:-}" ]; then
        echo "❌ Error: COMPOSE_WORKDIR is not set. Please call set_compose_cmd() first." >&2
        return 1
    fi
    if [ ! -d "${COMPOSE_WORKDIR}" ]; then
        echo "❌ Error: Services directory does not exist: ${COMPOSE_WORKDIR}" >&2
        return 1
    fi
    # Export ENABLE_DB_STORAGE explicitly if it's set, to ensure it's available to docker-compose
    # This fixes the issue where the variable might not be visible in the subshell
    if [ -n "${ENABLE_DB_STORAGE:-}" ]; then
        export ENABLE_DB_STORAGE
    fi
    
    # Run compose command and filter output in real-time
    # Only show lines that look like actual status messages or errors
    # Suppress: JSON fragments, flag lines (-e, -v, --), command traces, "** merged:**" header
    (cd "${COMPOSE_WORKDIR}" && "${COMPOSE_CMD[@]}" "$@" 2>&1) | \
    awk '
        # Skip lines that are clearly JSON or command flags
        /^[[:space:]]*-[ev][[:space:]]/ { next }
        /^[[:space:]]*--/ { next }
        /^[[:space:]]*\{/ { next }
        /^[[:space:]]*\}/ { next }
        /^[[:space:]]*\[/ { next }
        /^[[:space:]]*\]/ { next }
        /^[[:space:]]*"/ { next }
        /^[[:space:]]*\x27/ { next }
        /^[[:space:]]*,[[:space:]]*$/ { next }
        /^[[:space:]]*\}[,[:space:]]*$/ { next }
        /^[[:space:]]*\][,[:space:]]*$/ { next }
        /^\*\* / { next }
        /^podman run/ { next }
        /^\[.podman/ { next }
        /^exit code:/ { next }
        /^podman volume/ { next }
        /^\*\* merged:/ { next }
        /^\*\* excluding:/ { next }
        /^recreating:/ { next }
        /^podman-compose version:/ { next }
        /^using podman version:/ { next }
        # Print everything else
        { print }
    '
    
    return ${PIPESTATUS[0]:-0}
}

# Check if a container is running (handles both exact name and hash-prefixed names)
is_container_running() {
    local container_name="$1"
    # Check for exact match or hash-prefixed match (e.g., "a9f302029b81_ollama")
    ${DOCKER_BIN:-docker} ps --format "{{.Names}}" 2>/dev/null | grep -qE "^${container_name}$|_[0-9a-f]+_${container_name}$|^[0-9a-f]+_${container_name}$"
}

# Get the actual engine container name (handles hash-prefixed containers)
get_engine_container() {
    local engine="$1"
    ${DOCKER_BIN:-docker} ps --format "{{.Names}}" 2>/dev/null | grep -E "^${engine}$|_[0-9a-f]+_${engine}$|^[0-9a-f]+_${engine}$" 2>/dev/null | head -1 || true
}


