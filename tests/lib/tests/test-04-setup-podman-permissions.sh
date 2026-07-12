#!/usr/bin/env bash
# Test 04: setup-podman-rootless.sh sets .security to mode 700
# No running stack required. Exercises setup_volume_permissions in isolation.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-04-setup-podman-permissions"

SETUP_SCRIPT="${SCRIPT_DIR}/scripts/utils/setup-podman-rootless.sh"

assert_file_exists "$SETUP_SCRIPT" "setup-podman-rootless.sh exists"

# Work in a temp directory so we never touch the real .security
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# Stub out init-volumes.sh which setup_volume_permissions calls
mkdir -p "${TMPDIR_ROOT}/scripts/utils"
printf '#!/usr/bin/env bash\n: # stub\n' > "${TMPDIR_ROOT}/scripts/utils/init-volumes.sh"
chmod +x "${TMPDIR_ROOT}/scripts/utils/init-volumes.sh"

# Extract the setup_volume_permissions function definition (lines 179-207)
# and eval it in the current shell with stubs for its logging helpers.
log_step() { :; }
log_info() { :; }

func_def="$(sed -n '/^setup_volume_permissions()/,/^}/p' "$SETUP_SCRIPT")"
# eval-waiver: loads a function definition extracted from the repo's own
# setup script so the test can exercise it in isolation
eval "$func_def"

export PROJECT_ROOT="$TMPDIR_ROOT"
setup_volume_permissions

SECURITY_MODE="$(stat -c "%a" "${TMPDIR_ROOT}/.security")"
LOGS_MODE="$(stat -c "%a" "${TMPDIR_ROOT}/logs")"
AUDIT_MODE="$(stat -c "%a" "${TMPDIR_ROOT}/.audit")"

assert_command_success \
  "[[ '$SECURITY_MODE' == '700' ]]" \
  ".security directory has mode 700 (got $SECURITY_MODE)"

assert_command_success \
  "[[ '$LOGS_MODE' != '000' ]]" \
  "logs directory is accessible (got $LOGS_MODE)"

assert_command_success \
  "[[ '$AUDIT_MODE' != '000' ]]" \
  ".audit directory is accessible (got $AUDIT_MODE)"

log_test_pass ".security permissions are correct after setup_volume_permissions"
