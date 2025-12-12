#!/usr/bin/env bash
# Continue Plugin Integration Test
# Tests that Continue plugin can communicate with LLM Council

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

print_test() {
    echo -e "${BLUE}[CONTINUE TEST]${NC} $1"
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

echo "=========================================="
echo "Continue Plugin Integration Test"
echo "=========================================="
echo ""

# ============================================
# Service Availability
# ============================================
echo "Service Availability"
echo "-----------------------------------"

if ! is_service_running "llm-council"; then
    print_skip "LLM Council service (not running)"
    echo ""
    echo "To run these tests, start services with:"
    echo "  ./aixcl.sh stack start"
    exit 0
fi

print_pass "LLM Council service is running"

if ! is_service_running "ollama"; then
    print_skip "Ollama service (not running)"
else
    print_pass "Ollama service is running"
fi

if ! is_service_running "postgres"; then
    print_skip "PostgreSQL service (not running)"
else
    print_pass "PostgreSQL service is running"
fi

echo ""

# ============================================
# OpenAI-Compatible API Endpoints
# ============================================
echo "OpenAI-Compatible API Endpoints"
echo "-----------------------------------"

# Test /v1/models endpoint (used by Continue plugin)
print_test "/v1/models endpoint"
response=$(curl -s http://localhost:8000/v1/models 2>/dev/null || echo "ERROR")
if echo "$response" | grep -q "data\|models\|id" 2>/dev/null; then
    print_pass "/v1/models endpoint responds"
else
    print_fail "/v1/models endpoint not responding correctly"
    echo "Response: $response"
fi

# Test /v1/chat/completions endpoint (main Continue plugin endpoint)
print_test "/v1/chat/completions endpoint"
test_payload='{
    "model": "council",
    "messages": [{"role": "user", "content": "Say hello"}],
    "stream": false
}'
response=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "$test_payload" 2>/dev/null || echo "ERROR")

if echo "$response" | grep -q "choices\|message\|content" 2>/dev/null; then
    print_pass "/v1/chat/completions endpoint responds"
else
    if echo "$response" | grep -q "error"; then
        print_fail "/v1/chat/completions endpoint returned error"
        echo "Response: $response"
    else
        print_fail "/v1/chat/completions endpoint not responding correctly"
        echo "Response: $response"
    fi
fi

# Test streaming endpoint
print_test "/v1/chat/completions streaming endpoint"
test_payload_stream='{
    "model": "council",
    "messages": [{"role": "user", "content": "Say hello"}],
    "stream": true
}'
response=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "$test_payload_stream" 2>/dev/null | head -5 || echo "ERROR")

if echo "$response" | grep -q "data:\|delta\|content" 2>/dev/null; then
    print_pass "/v1/chat/completions streaming works"
else
    print_fail "/v1/chat/completions streaming not working"
fi

echo ""

# ============================================
# Database Persistence
# ============================================
echo "Database Persistence"
echo "-----------------------------------"

# Test conversation creation endpoint
print_test "Conversation creation API"
test_payload_conv='{
    "content": "Test message from integration test"
}'
response=$(curl -s -X POST http://localhost:8000/api/conversations \
    -H "Content-Type: application/json" \
    -d "$test_payload_conv" 2>/dev/null || echo "ERROR")

if echo "$response" | grep -q "id\|conversation_id" 2>/dev/null; then
    print_pass "Conversation creation works"
    # Extract conversation ID for next test
    CONV_ID=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
else
    print_fail "Conversation creation failed"
    CONV_ID=""
fi

# Test conversation retrieval
if [[ -n "$CONV_ID" ]]; then
    print_test "Conversation retrieval API"
    response=$(curl -s "http://localhost:8000/api/conversations/${CONV_ID}" 2>/dev/null || echo "ERROR")
    if echo "$response" | grep -q "id\|messages" 2>/dev/null; then
        print_pass "Conversation retrieval works"
    else
        print_fail "Conversation retrieval failed"
    fi
else
    print_skip "Conversation retrieval (no conversation ID)"
fi

# Test database connection
print_test "PostgreSQL database connection"
if docker exec postgres pg_isready -U "${POSTGRES_USER:-webui}" >/dev/null 2>&1; then
    print_pass "PostgreSQL is accessible"
    
    # Test that chat table exists
    table_check=$(docker exec postgres psql -U "${POSTGRES_USER:-webui}" -d "${POSTGRES_DATABASE:-webui}" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'chat');" 2>/dev/null | tr -d ' \n' || echo "false")
    if [[ "$table_check" == "t" ]]; then
        print_pass "Chat table exists in database"
    else
        print_fail "Chat table does not exist"
    fi
else
    print_fail "PostgreSQL is not accessible"
fi

echo ""

# ============================================
# Continue Plugin Configuration
# ============================================
echo "Continue Plugin Configuration"
echo "-----------------------------------"

print_test "API base URL accessibility"
if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    print_pass "API base URL (http://localhost:8000) is accessible"
else
    print_fail "API base URL is not accessible"
fi

print_test "CORS headers (for web-based Continue plugin)"
response=$(curl -s -I -X OPTIONS http://localhost:8000/v1/models 2>/dev/null || echo "")
if echo "$response" | grep -qi "access-control" 2>/dev/null; then
    print_pass "CORS headers present"
else
    print_warning "CORS headers not detected (may still work)"
fi

echo ""

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "Continue Integration Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All Continue integration tests passed!${NC}"
    echo ""
    echo "Continue plugin should work with this configuration:"
    echo '  {'
    echo '    "model": "council",'
    echo '    "title": "LLM-Council (Multi-Model)",'
    echo '    "provider": "openai",'
    echo '    "apiBase": "http://localhost:8000/v1",'
    echo '    "apiKey": "local"'
    echo '  }'
    exit 0
else
    echo -e "${RED}Some Continue integration tests failed.${NC}"
    exit 1
fi
