#!/usr/bin/env bash
# Common utility functions for AIXCL

# Safe function to load environment variables from .env file
load_env_file() {
    local env_file="$1"
    if [ ! -f "$env_file" ]; then
        return 1
    fi
    # Use a safer method to parse .env files
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines and comments
            [ -z "$line" ] && continue
            [ "${line#\#}" != "$line" ] && continue
            
            # Extract key and value, handling quoted values
            if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                # Remove leading/trailing whitespace from key
                key="${key%"${key##*[![:space:]]}"}"
                key="${key#"${key%%[![:space:]]*}"}"
                
                # Remove leading/trailing whitespace from value
                value="${value%"${value##*[![:space:]]}"}"
                value="${value#"${value%%[![:space:]]*}"}"
                
                # Remove surrounding quotes if present
                if [[ "$value" =~ ^\".*\"$ ]]; then
                    value="${value#\"}"
                    value="${value%\"}"
                elif [[ "$value" =~ ^\'.*\'$ ]]; then
                    value="${value#\'}"
                    value="${value%\'}"
                fi
                
                # Only export if key is not empty and contains valid characters
                # Note: Bash cannot export variables with hyphens
                # Docker Compose reads these directly from .env file, so we don't need to export them
                # We'll only export standard bash-compatible variable names
                if [ -n "$key" ]; then
                    # Check if variable name contains hyphens (Docker Compose compatible but not bash exportable)
                    if [[ "$key" =~ - ]]; then
                        # Variable contains hyphen - docker-compose will read it from .env directly
                        # We can't export it in bash, but that's fine - docker-compose handles it
                        # Silently skip (don't show warning) since this is expected behavior
                        :
                    # Check if variable name is bash-compatible (no hyphens)
                    elif [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                        # Standard bash variable name - safe to export
                        export "$key"="$value"
                    else
                        echo "⚠️ Skipping invalid environment variable key: '$key'" >&2
                    fi
                fi
            fi
        done < "$env_file"
}

# Define all services from docker-compose.yml
ALL_SERVICES=(
    "engine"
    "ollama"
    "vllm"
    "llamacpp"
    "open-webui"
    "postgres"
    "pgadmin"
    "watchtower"
    "prometheus"
    "grafana"
    "cadvisor"
    "node-exporter"
    "postgres-exporter"
    "nvidia-gpu-exporter"
    "loki"
    "promtail"
)

# Function to validate service name
is_valid_service() {
    local service="$1"
    for valid_service in "${ALL_SERVICES[@]}"; do
        if [ "$service" = "$valid_service" ]; then
            return 0
        fi
    done
    return 1
}

# Function to get container name from service name
get_container_name() {
    local service="$1"
    case "$service" in
        "engine")
            echo "${INFERENCE_ENGINE:-ollama}"
            ;;
        "open-webui")
            echo "open-webui"
            ;;
        "node-exporter")
            echo "node-exporter"
            ;;
        "postgres-exporter")
            echo "postgres-exporter"
            ;;
        "nvidia-gpu-exporter")
            echo "nvidia-gpu-exporter"
            ;;
        *)
            echo "$service"
            ;;
    esac
}

# Detect if NVIDIA GPU is available
has_nvidia() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi >/dev/null 2>&1 && return 0 || return 1
    fi
    if ${DOCKER_BIN:-docker} info 2>/dev/null | grep -qi "nvidia"; then
        return 0
    fi
    return 1
}

# Detect if running on ARM64 architecture
is_arm64() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        arm64|aarch64)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Detect if container engine is running in rootless mode
is_rootless() {
    # Check Docker
    if command -v docker >/dev/null 2>&1; then
        if ${DOCKER_BIN:-docker} info --format '{{.SecurityOptions}}' 2>/dev/null | grep -q "rootless"; then
            return 0
        fi
    fi
    # Check Podman
    if command -v podman >/dev/null 2>&1; then
        if podman info --format '{{.Host.ServiceIsRootless}}' 2>/dev/null | grep -q "true"; then
            return 0
        fi
        # Fallback for older podman versions
        if podman info --format '{{.Host.Rootless}}' 2>/dev/null | grep -q "true"; then
            return 0
        fi
    fi
    # Fallback: check if we are not root but can run docker
    if [ "$(id -u)" != "0" ] && command -v docker >/dev/null 2>&1; then
        # If we can run ${DOCKER_BIN:-docker} ps without sudo, and it's not via a group, it might be rootless
        # but the safest check is the info commands above.
        :
    fi
    return 1
}

# Get the appropriate Docker/Podman socket path
get_docker_sock() {
    if is_rootless; then
        if command -v podman >/dev/null 2>&1; then
            if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]; then
                echo "${XDG_RUNTIME_DIR}/podman/podman.sock"
                return 0
            fi
            # Fallback for some systems
            local user_sock; user_sock="/run/user/$(id -u)/podman/podman.sock"
            if [ -S "$user_sock" ]; then
                echo "$user_sock"
                return 0
            fi
        fi
        if command -v docker >/dev/null 2>&1; then
            if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/docker.sock" ]; then
                echo "${XDG_RUNTIME_DIR}/docker.sock"
                return 0
            fi
            local user_sock; user_sock="/run/user/$(id -u)/docker.sock"
            if [ -S "$user_sock" ]; then
                echo "$user_sock"
                return 0
            fi
        fi
    fi
    
    # Default to standard root socket
    echo "/var/run/docker.sock"
}

# Validate database name to prevent SQL injection
# Returns 0 if valid, 1 if invalid
# Valid names: alphanumeric + underscore, must start with letter or underscore
validate_db_name() {
    local name
    name="$1"
    local context
    context="${2:-database}"
    
    # Check if empty
    if [ -z "$name" ]; then
        echo "Error: Database name for $context cannot be empty" >&2
        return 1
    fi
    
    # Check length (PostgreSQL limit is 63 bytes)
    if [ "${#name}" -gt 63 ]; then
        echo "Error: Database name '$name' exceeds 63 characters" >&2
        return 1
    fi
    
    # Validate against whitelist pattern: alphanumeric + underscore, must start with letter or underscore
    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Error: Database name '$name' contains invalid characters. Use only letters, numbers, and underscores. Must start with a letter or underscore." >&2
        return 1
    fi
    
    # Check for reserved PostgreSQL database names
    local lower_name
    lower_name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    case "$lower_name" in
        postgres|template0|template1)
            echo "Error: Database name '$name' is a reserved PostgreSQL database name" >&2
            return 1
            ;;
    esac
    
    return 0
}
