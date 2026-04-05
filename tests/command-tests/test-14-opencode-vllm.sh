#!/usr/bin/env bash
# Test 14: OpenCode Prompt Integration with vLLM
# Validates OpenCode can connect to vLLM engine and respond to code challenges

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-14-opencode-vllm"

# Skip if no GPU
if ! has_nvidia_gpu; then
    log_test_skip "No NVIDIA GPU - vLLM requires GPU"
    exit 0
fi

# Capture state before test
BACKUP_DIR=$(capture_state "test-14-opencode-vllm")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
    cleanup_test_containers
}
trap cleanup EXIT

# Configuration
TIMEOUT_SECONDS=60
PASS_THRESHOLD=6
VLLM_MODEL="Qwen/Qwen2.5-Coder-0.5B-Instruct"

# Code Challenges
declare -a CHALLENGES=(
    "Write a Python function to reverse a string without using built-in reverse methods."
    "Implement a binary search tree class in Python with insert and search methods."
    "Create a Python decorator that implements rate limiting using the token bucket algorithm."
)

# Pre-flight checks
verify_opencode() {
    log_info "Verifying OpenCode CLI is available..."
    if ! command -v opencode > /dev/null 2>&1; then
        log_error "OpenCode CLI not found"
        return 1
    fi
    log_success "OpenCode CLI available"
    return 0
}

verify_opencode || exit 1

# Setup vLLM
log_info "Setting up vLLM engine..."
"${SCRIPT_DIR}/aixcl" engine set vllm > /dev/null 2>&1
"${SCRIPT_DIR}/aixcl" stack start --profile usr > /dev/null 2>&1
wait_for_container "vllm" 60

# Add vLLM model if not present
if ! "${SCRIPT_DIR}/aixcl" models list 2>/dev/null | grep -q "vllm"; then
    log_info "Adding vLLM model..."
    "${SCRIPT_DIR}/aixcl" models add "$VLLM_MODEL" > /dev/null 2>&1 || {
        log_warn "Failed to add vLLM model - may already exist or model not available"
    }
    sleep 10
fi

# Update opencode.json for vLLM
OPENCODE_CONFIG="${SCRIPT_DIR}/opencode.json"
if [[ -f "$OPENCODE_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
    jq --arg model "$VLLM_MODEL" '.provider."aixcl-local".models = {($model): {"name": $model}} | .model = "aixcl-local/\($model)"' "$OPENCODE_CONFIG" > /tmp/opencode_vllm.json && mv /tmp/opencode_vllm.json "$OPENCODE_CONFIG"
    log_info "Updated opencode.json for vLLM"
fi

# Run challenges
total_score=0
challenge_count=0

for i in "${!CHALLENGES[@]}"; do
    level=$((i + 1))
    prompt="${CHALLENGES[$i]}"
    response_file="/tmp/opencode_vllm_response_$level.txt"
    
    log_info "Running Challenge $level with vLLM..."
    
    if timeout "$TIMEOUT_SECONDS" opencode run "$prompt" > "$response_file" 2>&1; then
        # Simple scoring - check for code blocks
        score=0
        if grep -q "def " "$response_file"; then ((score+=3)); fi
        if grep -q "class " "$response_file"; then ((score+=3)); fi
        if grep -q "\"\"\"" "$response_file" || grep -q "#" "$response_file"; then ((score+=2)); fi
        if grep -q "import " "$response_file"; then ((score+=2)); fi
        
        total_score=$((total_score + score))
        log_info "Challenge $level: Score=$score/10"
    else
        log_warn "Challenge $level: Timeout or failure"
    fi
    challenge_count=$((challenge_count + 1))
done

# Calculate average
if [[ $challenge_count -gt 0 ]]; then
    average_score=$((total_score / challenge_count))
else
    average_score=0
fi

log_info "=== vLLM OpenCode Results ==="
log_info "Total Score: $total_score/${challenge_count}0"
log_info "Average Score: $average_score/10"

if [[ $average_score -ge $PASS_THRESHOLD ]]; then
    log_test_pass "vLLM OpenCode test passed (avg score: $average_score/10)"
else
    log_error "vLLM OpenCode test failed (avg score: $average_score/10)"
    exit 1
fi
