#!/usr/bin/env bash
# Test: Inference API connectivity
# Validates the OpenAI-compatible API endpoint is reachable and responding.
# Skips gracefully if the stack is not running.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-inference-api"

# Resolve API endpoint from .env or fall back to default
INFERENCE_HOST="${INFERENCE_HOST:-localhost}"
INFERENCE_PORT="${INFERENCE_PORT:-11434}"
API_BASE="http://${INFERENCE_HOST}:${INFERENCE_PORT}"

# Skip if stack is not reachable
if ! curl -sf --max-time 3 "${API_BASE}" > /dev/null 2>&1; then
    log_info "Inference API not reachable at ${API_BASE} -- stack may not be running"
    log_info "Start the stack with: ./aixcl stack start --profile sys"
    log_info "SKIP: test-inference-api (stack not running)"
    exit 0
fi

# Test: models endpoint responds
assert_command_success \
    "curl -sf --max-time 5 '${API_BASE}/api/tags'" \
    "Models endpoint responds at ${API_BASE}/api/tags"

# Test: OpenAI-compatible models endpoint responds
assert_command_success \
    "curl -sf --max-time 5 '${API_BASE}/v1/models'" \
    "OpenAI-compatible models endpoint responds at ${API_BASE}/v1/models"

# Test: at least one model is loaded
MODEL_COUNT=$(curl -sf --max-time 5 "${API_BASE}/v1/models" \
    | grep -o '"id"' | wc -l | tr -d ' ')
if [ "${MODEL_COUNT}" -eq 0 ]; then
    log_info "No models loaded. Pull one with: ./aixcl models add <model-name>"
    log_info "SKIP: chat completion test (no models loaded)"
else
    # Test: chat completion endpoint accepts a request
    FIRST_MODEL=$(curl -sf --max-time 5 "${API_BASE}/v1/models" \
        | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    log_info "Testing chat completion with model: ${FIRST_MODEL}"
    assert_command_success \
        "curl -sf --max-time 30 -X POST '${API_BASE}/v1/chat/completions' \
          -H 'Content-Type: application/json' \
          -d '{\"model\":\"${FIRST_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":5}'" \
        "Chat completion endpoint accepts request for model ${FIRST_MODEL}"
fi

log_test_pass "Inference API connectivity checks passed"
