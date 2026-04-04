#!/usr/bin/env bash
# Unit tests for lib/core/common.sh

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the library under test
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/core/color.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/core/common.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
assert_true() {
    local condition="$1"
    local message="$2"
    
    if eval "$condition"; then
        echo "✓ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: $message"
        ((TESTS_FAILED++))
    fi
}

assert_false() {
    local condition="$1"
    local message="$2"
    
    if ! eval "$condition"; then
        echo "✓ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: $message"
        ((TESTS_FAILED++))
    fi
}

# Test: Inference engine validation
test_valid_engines() {
    assert_true 'INFERENCE_ENGINE=ollama; is_valid_inference_engine "$INFERENCE_ENGINE"' "ollama is valid engine"
    assert_true 'INFERENCE_ENGINE=vllm; is_valid_inference_engine "$INFERENCE_ENGINE"' "vllm is valid engine"
    assert_true 'INFERENCE_ENGINE=llamacpp; is_valid_inference_engine "$INFERENCE_ENGINE"' "llamacpp is valid engine"
}

test_invalid_engines() {
    assert_false 'INFERENCE_ENGINE=invalid; is_valid_inference_engine "$INFERENCE_ENGINE"' "invalid engine is rejected"
    assert_false 'INFERENCE_ENGINE=docker; is_valid_inference_engine "$INFERENCE_ENGINE"' "docker is rejected as engine"
    assert_false 'INFERENCE_ENGINE=""; is_valid_inference_engine "$INFERENCE_ENGINE"' "empty engine is rejected"
}

# Test: Service validation (mock environment)
test_service_functions_exist() {
    assert_true 'type -t is_valid_service | grep -q function' "is_valid_service function exists"
}

# Run tests
echo "=========================================="
echo "Unit Tests: lib/core/common.sh"
echo "=========================================="
echo ""

test_valid_engines
test_invalid_engines
test_service_functions_exist

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "=========================================="

exit $TESTS_FAILED
