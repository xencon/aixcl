#!/usr/bin/env bash
# Test 02: derive Vault bootstrap agents from compose and intersect with profile
# No running stack required

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/core/common.sh"
source "${SCRIPT_DIR}/lib/cli/profile.sh"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-02-vault-bootstrap-agents"

bld_agents="$(_get_vault_bootstrap_agents bld)"
sys_agents="$(_get_vault_bootstrap_agents sys)"

# bld profile only includes postgres bootstrap agent
assert_string_contains "$bld_agents" "vault-agent-postgres-bootstrap" "bld includes postgres bootstrap agent"
assert_string_not_contains "$bld_agents" "vault-agent-openwebui-bootstrap" "bld excludes openwebui bootstrap agent"
assert_string_not_contains "$bld_agents" "vault-agent-pgadmin-bootstrap" "bld excludes pgadmin bootstrap agent"
assert_string_not_contains "$bld_agents" "vault-agent-grafana-bootstrap" "bld excludes grafana bootstrap agent"

# sys profile includes all four bootstrap agents
assert_string_contains "$sys_agents" "vault-agent-postgres-bootstrap" "sys includes postgres bootstrap agent"
assert_string_contains "$sys_agents" "vault-agent-openwebui-bootstrap" "sys includes openwebui bootstrap agent"
assert_string_contains "$sys_agents" "vault-agent-pgadmin-bootstrap" "sys includes pgadmin bootstrap agent"
assert_string_contains "$sys_agents" "vault-agent-grafana-bootstrap" "sys includes grafana bootstrap agent"

log_test_pass "Vault bootstrap agents derived from compose and profile"
