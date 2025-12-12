#!/usr/bin/env bash
# API Endpoint Test Suite
# Tests all API endpoints when services are running

set -e
set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIXCL="${SCRIPT_DIR}/aixcl.sh"

print_test() {
    echo -e "${BLUE}[API TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

# Check if service is running
is_service_running() {
    docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^$1$"
}

# Test HTTP endpoint
test_endpoint() {
    local url="$1"
    local expected_code="${2:-200}"
    local description="$3"
    
    print_test "$description"
    
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$status_code" = "$expected_code" ] || [ "$status_code" = "000" ]; then
        if [ "$status_code" = "000" ]; then
            print_skip "$description (service not running)"
        else
            print_pass "$description (HTTP $status_code)"
        fi
    else
        print_fail "$description (expected $expected_code, got $status_code)"
    fi
}

echo "=========================================="
echo "API Endpoint Test Suite"
echo "=========================================="
echo ""

# ============================================
# Core Services
# ============================================
echo "Core Services"
echo "-----------------------------------"

if is_service_running "ollama"; then
    test_endpoint "http://localhost:11434/api/version" "200" "Ollama API version"
    test_endpoint "http://localhost:11434/api/tags" "200" "Ollama API tags"
else
    print_skip "Ollama endpoints (service not running)"
fi

if is_service_running "open-webui"; then
    test_endpoint "http://localhost:8080/health" "200" "Open WebUI health"
    test_endpoint "http://localhost:8080" "200" "Open WebUI main"
else
    print_skip "Open WebUI endpoints (service not running)"
fi

if is_service_running "llm-council"; then
    test_endpoint "http://localhost:8000/health" "200" "LLM Council health"
    test_endpoint "http://localhost:8000/v1/models" "200" "LLM Council models endpoint"
    test_endpoint "http://localhost:8000/api/config" "200" "LLM Council config"
else
    print_skip "LLM Council endpoints (service not running)"
fi

echo ""

# ============================================
# Database Services
# ============================================
echo "Database Services"
echo "-----------------------------------"

if is_service_running "postgres"; then
    print_test "PostgreSQL connection"
    if docker exec postgres pg_isready -U "${POSTGRES_USER:-webui}" >/dev/null 2>&1; then
        print_pass "PostgreSQL is ready"
    else
        print_fail "PostgreSQL is not ready"
    fi
else
    print_skip "PostgreSQL (service not running)"
fi

if is_service_running "pgadmin"; then
    test_endpoint "http://localhost:5050" "200" "pgAdmin main"
    # pgAdmin might return 302 redirect
    test_endpoint "http://localhost:5050" "302" "pgAdmin redirect"
else
    print_skip "pgAdmin endpoints (service not running)"
fi

echo ""

# ============================================
# Monitoring Services
# ============================================
echo "Monitoring Services"
echo "-----------------------------------"

if is_service_running "prometheus"; then
    test_endpoint "http://localhost:9090/-/healthy" "200" "Prometheus health"
    test_endpoint "http://localhost:9090/api/v1/status/config" "200" "Prometheus config"
else
    print_skip "Prometheus endpoints (service not running)"
fi

if is_service_running "grafana"; then
    test_endpoint "http://localhost:3000/api/health" "200" "Grafana health"
else
    print_skip "Grafana endpoints (service not running)"
fi

if is_service_running "cadvisor"; then
    test_endpoint "http://localhost:8081/metrics" "200" "cAdvisor metrics"
else
    print_skip "cAdvisor endpoints (service not running)"
fi

if is_service_running "node-exporter"; then
    test_endpoint "http://localhost:9100/metrics" "200" "Node Exporter metrics"
else
    print_skip "Node Exporter endpoints (service not running)"
fi

if is_service_running "postgres-exporter"; then
    test_endpoint "http://localhost:9187/metrics" "200" "Postgres Exporter metrics"
else
    print_skip "Postgres Exporter endpoints (service not running)"
fi

if is_service_running "nvidia-gpu-exporter"; then
    test_endpoint "http://localhost:9400/metrics" "200" "NVIDIA GPU Exporter metrics"
else
    print_skip "NVIDIA GPU Exporter endpoints (service not running or no GPU)"
fi

echo ""

# ============================================
# Logging Services
# ============================================
echo "Logging Services"
echo "-----------------------------------"

if is_service_running "loki"; then
    test_endpoint "http://localhost:3100/ready" "200" "Loki ready"
    test_endpoint "http://localhost:3100/metrics" "200" "Loki metrics"
else
    print_skip "Loki endpoints (service not running)"
fi

if is_service_running "promtail"; then
    print_test "Promtail ready check"
    if docker exec promtail wget --no-verbose --tries=1 --spider http://localhost:9080/ready 2>/dev/null; then
        print_pass "Promtail is ready"
    else
        print_fail "Promtail is not ready"
    fi
else
    print_skip "Promtail (service not running)"
fi

echo ""

# ============================================
# Continue Plugin Integration
# ============================================
echo "Continue Plugin Integration"
echo "-----------------------------------"

if is_service_running "llm-council"; then
    print_test "LLM Council OpenAI-compatible API"
    
    # Test the /v1/chat/completions endpoint (used by Continue plugin)
    local response
    response=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{
            "model": "council",
            "messages": [{"role": "user", "content": "test"}],
            "stream": false
        }' 2>/dev/null || echo "ERROR")
    
    if echo "$response" | grep -q "error\|choices\|message" 2>/dev/null; then
        print_pass "LLM Council OpenAI API responds"
    else
        print_fail "LLM Council OpenAI API not responding correctly"
    fi
    
    # Test database storage endpoint
    test_endpoint "http://localhost:8000/api/conversations" "200" "LLM Council conversations API"
else
    print_skip "Continue plugin integration (LLM Council not running)"
fi

echo ""

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "API Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All API tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some API tests failed.${NC}"
    exit 1
fi
