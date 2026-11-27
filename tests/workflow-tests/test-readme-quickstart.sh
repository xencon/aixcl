#!/usr/bin/env bash
# Workflow Test: README Quick Start
# Validates the complete README Quick Start workflow (Steps 1-4)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-readme-quickstart"

# Capture state before test
BACKUP_DIR=$(capture_state "test-readme-quickstart")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
    cleanup_test_containers
}
trap cleanup EXIT

log_info "Testing README Quick Start Steps 1-5"
log_info "This test follows the exact README workflow"
echo ""

# Step 1: Clone and Verify
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Clone and Verify"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
assert_command_success "${SCRIPT_DIR}/aixcl utils check-env" "Step 1: Environment check passes"
echo ""

# Step 2: Start the Stack
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Start the Stack"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
assert_command_success "${SCRIPT_DIR}/aixcl stack start --profile sys" "Step 2: Stack starts with sys profile"
wait_for_container "ollama" 60
wait_for_container "postgres" 60
wait_for_api "http://localhost:11434/v1/models" 60
echo ""

# Step 3: Choose Your Engine
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Choose Your Engine"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
assert_command_success "${SCRIPT_DIR}/aixcl engine set ollama" "Step 3: Engine set to ollama"
assert_env_equals "INFERENCE_ENGINE" "ollama"
echo ""

# Step 4: Add Your First Model
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Add Your First Model"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Adding qwen2.5-coder:0.5b (this may take 2-3 minutes)..."
assert_command_success "${SCRIPT_DIR}/aixcl models add qwen2.5-coder:0.5b" "Step 4: Model added successfully"

# Verify model is available
if "${SCRIPT_DIR}/aixcl" models list 2>/dev/null | grep -q "qwen2.5-coder"; then
    log_success "Step 4: Model verified in list"
else
    log_error "Step 4: Model not found in list"
    exit 1
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "README Quick Start - All Steps Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log_test_pass "README Quick Start workflow validated (Steps 1-4)"
