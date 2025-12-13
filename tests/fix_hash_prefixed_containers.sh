#!/usr/bin/env bash
# Fix hash-prefixed containers that cause docker-compose ContainerConfig errors
# Usage: ./tests/fix_hash_prefixed_containers.sh [service-name]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

if [ -n "$1" ]; then
    # Fix specific service
    SERVICE="$1"
    echo "Fixing hash-prefixed containers for: $SERVICE"
    
    # Find and remove hash-prefixed containers
    docker ps -a --format "{{.ID}} {{.Names}}" | grep -E "_${SERVICE}$|^[0-9a-f]+_${SERVICE}$" | while read -r line; do
        if [ -n "$line" ]; then
            container_id=$(echo "$line" | awk '{print $1}')
            container_name=$(echo "$line" | awk '{print $2}')
            echo "  Removing: $container_name ($container_id)"
            docker rm -f "$container_id" 2>/dev/null || true
        fi
    done
else
    # Fix all services
    echo "Fixing all hash-prefixed containers..."
    
    SERVICES=("ollama" "open-webui" "llm-council" "postgres" "pgadmin" "prometheus" "grafana" "cadvisor" "node-exporter" "postgres-exporter" "nvidia-gpu-exporter" "loki" "promtail" "watchtower")
    
    for service in "${SERVICES[@]}"; do
        docker ps -a --format "{{.ID}} {{.Names}}" | grep -E "_${service}$|^[0-9a-f]+_${service}$" | while read -r line; do
            if [ -n "$line" ]; then
                container_id=$(echo "$line" | awk '{print $1}')
                container_name=$(echo "$line" | awk '{print $2}')
                echo "  Removing: $container_name ($container_id)"
                docker rm -f "$container_id" 2>/dev/null || true
            fi
        done
    done
fi

echo "Done!"
