#!/usr/bin/env bash
# Test 00: Pure shell library sanity checks
# No running stack required

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-00-lib-functions"

# is_valid_profile from lib/cli/profile.sh should be loaded indirectly via aixcl
# but we cannot source the whole aixcl stack here; test a simple helper instead.
assert_command_success "command -v log_info" "log_info function is available"
assert_command_success "command -v log_warn" "log_warn function is available"
assert_command_success "command -v log_error" "log_error function is available"
assert_command_success "command -v log_test_start" "log_test_start function is available"

log_test_pass "Library functions are available"
