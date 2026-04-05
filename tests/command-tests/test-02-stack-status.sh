#!/usr/bin/env bash
# Test 02: Stack Status
# Tests stack status command

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-02-stack-status"

# Test: Stack status command works
assert_command_success "${SCRIPT_DIR}/aixcl stack status" "Stack status command succeeds"

# Test: Status shows running services (if stack is running)
# This may show stopped services if previous test cleaned up
log_info "Note: Status may show stopped services if stack was cleaned up"

log_test_pass "Stack status command works"
