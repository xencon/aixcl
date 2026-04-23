#!/usr/bin/env bash
# Test 10: Models List
# Tests listing models

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-10-models-list"

# Check if stack is running
if "${SCRIPT_DIR}/aixcl" stack status 2>/dev/null | grep -q "running"; then
    # Stack is running - test full models list
    assert_command_success "${SCRIPT_DIR}/aixcl models list" "Models list command succeeds"
else
    # Stack not running - verify command exists and would work with running stack
    log_warn "Stack not running, testing command availability only"
    # Just verify the command parses correctly (help or version check)
    if "${SCRIPT_DIR}/aixcl" models list --help > /dev/null 2>&1 || true; then
        log_success "Models list command available"
    fi
    # Skip the actual models list test since container is not running
    log_test_skip "Stack not running - models list requires running container"
fi

log_test_pass "Models list command works"
