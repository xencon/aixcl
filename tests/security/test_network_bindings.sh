#!/usr/bin/env bash
# Security Test: Network Binding Validation
# Verifies that sensitive services are bound to 127.0.0.1 and not exposed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/color.sh"

echo "=========================================="
echo "Security Test: Network Binding Validation"
echo "=========================================="
echo ""

# Ports to check
# Format: "SERVICE_NAME:PORT"
SERVICES=(
    "Inference Engine:11434"
    "PostgreSQL:5432"
    "pgAdmin:5050"
    "Open WebUI:8080"
    "Prometheus:9090"
    "Grafana:3000"
    "cAdvisor:8081"
    "Loki:3100"
    "Node Exporter:9100"
    "Postgres Exporter:9187"
    "NVIDIA GPU Exporter:9400"
)

FAILED=0

check_port_binding() {
    local service=$1
    local port=$2
    
    echo -n "Checking $service (port $port)... "
    
    # Get listening addresses for the port
    # We look for matches like "127.0.0.1:PORT" or "::1:PORT" or "localhost:PORT"
    # And we FAIL if we see "0.0.0.0:PORT" or "*:PORT" or "[::]:PORT"
    
    local bindings
    bindings=$(ss -tulpn | grep -w "$port" | awk '{print $4}')
    
    if [ -z "$bindings" ]; then
        echo -e "${YELLOW}NOT LISTENING (Skipped)${NC}"
        return 0
    fi
    
    local exposed=false
    local exposed_addr=""
    
    for addr in $bindings; do
        if [[ "$addr" == "0.0.0.0:$port" ]] || [[ "$addr" == "*:$port" ]] || [[ "$addr" == "[::]:$port" ]]; then
            exposed=true
            exposed_addr=$addr
            break
        fi
    done
    
    if [ "$exposed" = true ]; then
        echo -e "${RED}EXPOSED ($exposed_addr)${NC}"
        FAILED=1
        return 1
    else
        echo -e "${GREEN}SECURE (Bound to local interface)${NC}"
        return 0
    fi
}

for item in "${SERVICES[@]}"; do
    IFS=":" read -r name port <<< "$item"
    check_port_binding "$name" "$port"
done

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All services are properly secured.${NC}"
    exit 0
else
    echo -e "${RED}❌ Security violation: One or more services are exposed to the public internet!${NC}"
    exit 1
fi
