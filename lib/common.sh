#!/usr/bin/env bash
# Common utility functions for AIXCL

# Safe function to load environment variables from .env file
load_env_file() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
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
                if [ -n "$key" ] && [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                    export "$key"="$value"
                else
                    echo "⚠️ Skipping invalid environment variable key: '$key'" >&2
                fi
            fi
        done < "$env_file"
    fi
}

# Define all services from docker-compose.yml
ALL_SERVICES=(
    "ollama"
    "open-webui"
    "llm-council"
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
    if docker info 2>/dev/null | grep -qi "nvidia"; then
        return 0
    fi
    return 1
}

# Detect if running on ARM64 architecture
is_arm64() {
    local arch=$(uname -m)
    case "$arch" in
        arm64|aarch64)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
