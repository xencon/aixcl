#!/usr/bin/env bash
# Test 02: Stack Status
# Tests stack status command output and correctness.
# Regression tests for: https://github.com/xencon/aixcl/issues/1377

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-02-stack-status"

# Test: Stack status command exits cleanly
assert_command_success "${SCRIPT_DIR}/aixcl stack status" "Stack status command succeeds"

# Capture output for content assertions
STATUS_OUTPUT=$("${SCRIPT_DIR}/aixcl" stack status 2>&1)

# Test: Overall summary line is present
if echo "$STATUS_OUTPUT" | grep -qE "^Services: [0-9]+/[0-9]+ healthy"; then
    log_test_pass "Services summary line present"
else
    log_test_fail "Services summary line missing from stack status output"
    exit 1
fi

# Test: If the stack is running, bootstrap containers must show as healthy
# (regression for issue #1377 -- bootstrap containers showed as red despite exit 0)
if echo "$STATUS_OUTPUT" | grep -q "Status: Running"; then
    log_info "Stack is running -- asserting bootstrap container health"

    for bootstrap in \
        "Vault Agent Bootstrap (PostgreSQL)" \
        "Vault Agent Bootstrap (Open WebUI)" \
        "Vault Agent Bootstrap (pgAdmin)" \
        "Vault Agent Bootstrap (Grafana)"; do

        # Each bootstrap line must start with a success indicator (✅ or [x] fallback)
        if echo "$STATUS_OUTPUT" | grep -F "$bootstrap" | grep -qE "^[[:space:]]*(✅|\[x\])"; then
            log_test_pass "Bootstrap healthy: $bootstrap"
        else
            bootstrap_line=$(echo "$STATUS_OUTPUT" | grep -F "$bootstrap" || echo "(not found)")
            log_test_fail "Bootstrap container not showing healthy: $bootstrap -- got: $bootstrap_line"
            exit 1
        fi
    done

    # The complete annotation must be present for at least one bootstrap container
    if echo "$STATUS_OUTPUT" | grep -q "(complete)"; then
        log_test_pass "Bootstrap containers show (complete) annotation"
    else
        log_test_fail "No bootstrap container shows (complete) -- one-shot status not working"
        exit 1
    fi

    # Total healthy count must equal total service count (no red services on a healthy stack)
    healthy_line=$(echo "$STATUS_OUTPUT" | grep -E "^Services: [0-9]+/[0-9]+ healthy")
    healthy_count=$(echo "$healthy_line" | grep -oE "^Services: [0-9]+" | grep -oE "[0-9]+")
    total_count=$(echo "$healthy_line" | grep -oE "/[0-9]+" | tr -d '/')

    if [ "$healthy_count" = "$total_count" ]; then
        log_test_pass "All services healthy: $healthy_count/$total_count"
    else
        log_test_fail "Healthy count mismatch: $healthy_count/$total_count -- some services unhealthy"
        exit 1
    fi
else
    log_info "Stack is not running -- skipping running-stack assertions"
fi

log_test_pass "Stack status tests passed"
