#!/usr/bin/env bash
# Test 00: Pre-flight Check
# Validates environment before running other tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-00-preflight"

# Test: Environment check passes
assert_command_success "${SCRIPT_DIR}/aixcl utils check-env" "Environment check passes"

# Test: Docker is available
assert_command_success "docker --version" "Docker is available"

# Test: Docker Compose is available  
assert_command_success "docker compose version" "Docker Compose is available"

log_test_pass "All pre-flight checks passed"
