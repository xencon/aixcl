#!/usr/bin/env bash
# Docker and Docker Compose utility functions

# Source common functions
source "${BASH_SOURCE%/*}/common.sh"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
COMPOSE_CMD=(docker-compose -f "${SERVICES_DIR}/${COMPOSE_FILE}")
COMPOSE_WORKDIR="${SERVICES_DIR}"

# Build docker-compose command with optional GPU and ARM overrides if present
set_compose_cmd() {
    local files=( -f "${SERVICES_DIR}/${COMPOSE_FILE}" )
    
    # Check for ARM64 architecture
    if is_arm64 && [ -f "${SERVICES_DIR}/docker-compose.arm.yml" ]; then
        echo "Detected ARM64 architecture. Enabling ARM platform overrides."
        files+=( -f "${SERVICES_DIR}/docker-compose.arm.yml" )
    fi
    
    # Check for NVIDIA GPU
    if has_nvidia && [ -f "${SERVICES_DIR}/docker-compose.gpu.yml" ]; then
        echo "Detected NVIDIA GPU. Enabling GPU overrides."
        files+=( -f "${SERVICES_DIR}/docker-compose.gpu.yml" )
    else
        echo "No NVIDIA GPU detected. Running without GPU overrides."
    fi
    
    COMPOSE_CMD=(docker-compose "${files[@]}")
    COMPOSE_WORKDIR="${SERVICES_DIR}"
}

# Helper function to run docker-compose commands from the services directory
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
    (cd "${COMPOSE_WORKDIR}" && "${COMPOSE_CMD[@]}" "$@")
}

# Check if a container is running (handles both exact name and hash-prefixed names)
is_container_running() {
    local container_name="$1"
    # Check for exact match or hash-prefixed match (e.g., "a9f302029b81_ollama")
    docker ps --format "{{.Names}}" 2>/dev/null | grep -qE "^${container_name}$|_[0-9a-f]+_${container_name}$|^[0-9a-f]+_${container_name}$"
}

# Get the actual Ollama container name (handles hash-prefixed containers)
get_ollama_container() {
    docker ps --format "{{.Names}}" 2>/dev/null | grep -E "^ollama$|_[0-9a-f]+_ollama$|^[0-9a-f]+_ollama$" | head -1
}

# Check if any service containers are running
are_services_running() {
    local pattern="$1"
    docker ps --format "{{.Names}}" 2>/dev/null | grep -qE "$pattern"
}
