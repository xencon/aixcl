#!/usr/bin/env bash
# Test 01: profile service list loading from config/profiles/*.env
# No running stack required

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/core/common.sh"
source "${SCRIPT_DIR}/lib/cli/profile.sh"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-01-profile-services"

# get_profile_services_for_profile should return the same values as the env files
bld_services="$(get_profile_services_for_profile bld)"
sys_services="$(get_profile_services_for_profile sys)"

# sys.env is authoritative and must include vault, alertmanager, and bootstrap agents
assert_string_contains "$sys_services" "vault" "sys profile includes vault"
assert_string_contains "$sys_services" "alertmanager" "sys profile includes alertmanager"
assert_string_contains "$sys_services" "vault-agent-postgres-bootstrap" "sys profile includes postgres bootstrap agent"
assert_string_contains "$sys_services" "vault-agent-openwebui-bootstrap" "sys profile includes openwebui bootstrap agent"
assert_string_contains "$sys_services" "vault-agent-pgadmin-bootstrap" "sys profile includes pgadmin bootstrap agent"
assert_string_contains "$sys_services" "vault-agent-grafana-bootstrap" "sys profile includes grafana bootstrap agent"

# bld profile should include vault and its postgres bootstrap agent
assert_string_contains "$bld_services" "vault" "bld profile includes vault"
assert_string_contains "$bld_services" "vault-agent-postgres-bootstrap" "bld profile includes postgres bootstrap agent"
assert_string_not_contains "$bld_services" "open-webui" "bld profile excludes open-webui"
assert_string_not_contains "$bld_services" "pgadmin" "bld profile excludes pgadmin"

# INFERENCE_ENGINE should resolve to ollama by default
assert_string_contains "$bld_services" "ollama" "bld profile defaults to ollama runtime core"
assert_string_contains "$sys_services" "ollama" "sys profile defaults to ollama runtime core"

log_test_pass "Profile service lists loaded from env files"
