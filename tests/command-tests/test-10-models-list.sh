#!/usr/bin/env bash
# Test 10: Models List
# Tests listing models

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-10-models-list"

# Test: Models list command works (may show no models if stack not running)
if "${SCRIPT_DIR}/aixcl" stack status 2>/dev/null | grep -q "running"; then
    assert_command_success "${SCRIPT_DIR}/aixcl models list" "Models list command succeeds"
else
    log_warn "Stack not running, testing command only"
    assert_command_success "${SCRIPT_DIR}/aixcl models list" "Models list command succeeds (stack may be stopped)"
fi

log_test_pass "Models list command works"
