#!/usr/bin/env bash
# Test 06: check-env container UID audit verdict logic (#1822)
# No running stack required

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/core/env_check.sh"

log_test_start "test-06-uid-audit"

assert_command_success "command -v _uid_audit_verdict" "_uid_audit_verdict function is available"

assert_string_contains "$(_uid_audit_verdict grafana 472)" "ok" \
    "non-root container by uid is ok"
assert_string_contains "$(_uid_audit_verdict ollama ubuntu)" "ok" \
    "non-root container by user name is ok"
assert_string_contains "$(_uid_audit_verdict cadvisor root)" "intentional-root" \
    "cadvisor root is allowlisted"
assert_string_contains "$(_uid_audit_verdict nvidia-gpu-exporter 0)" "intentional-root" \
    "nvidia-gpu-exporter root is allowlisted"
assert_string_contains "$(_uid_audit_verdict ollama root)" "unexpected-root" \
    "root ollama must be flagged (the #1674 regression case)"
assert_string_contains "$(_uid_audit_verdict open-webui 0)" "unexpected-root" \
    "root open-webui must be flagged"

log_test_pass "UID audit verdicts"
