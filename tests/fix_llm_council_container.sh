#!/usr/bin/env bash
# Manual commands to fix the llm-council ContainerConfig error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Fixing LLM-Council ContainerConfig Error"
echo "=========================================="
echo ""

# Step 1: Stop the container if running
echo "Step 1: Stopping llm-council container (if running)..."
docker stop llm-council 2>/dev/null || echo "  (Container not running)"

# Step 2: Remove all containers with llm-council in the name
echo ""
echo "Step 2: Removing all llm-council containers (including hash-prefixed ones)..."
docker ps -a --format "{{.ID}} {{.Names}}" | grep -i "llm-council" | while read -r line; do
    if [ -n "$line" ]; then
        container_id=$(echo "$line" | awk '{print $1}')
        container_name=$(echo "$line" | awk '{print $2}')
        echo "  Removing: $container_name ($container_id)"
        docker rm -f "$container_id" 2>/dev/null || true
    fi
done

# Step 3: Also try docker-compose rm
echo ""
echo "Step 3: Removing via docker-compose..."
cd services
docker-compose -f docker-compose.yml rm -f llm-council 2>/dev/null || true

# Step 4: Start the service
echo ""
echo "Step 4: Starting llm-council service..."
docker-compose -f docker-compose.yml up -d llm-council

echo ""
echo "=========================================="
echo "Done! Check status with:"
echo "  docker ps | grep llm-council"
echo "  docker logs llm-council"
echo "=========================================="
