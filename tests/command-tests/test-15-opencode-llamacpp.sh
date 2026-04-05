#!/usr/bin/env bash
# Test 15: OpenCode Prompt Integration with llama.cpp
# Validates OpenCode can connect to llama.cpp engine and respond to code challenges

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-15-opencode-llamacpp"

# Capture state before test
BACKUP_DIR=$(capture_state "test-15-opencode-llamacpp")
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

# Code Challenges (same as other engines for comparison)
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

# Setup llama.cpp
log_info "Setting up llama.cpp engine..."
"${SCRIPT_DIR}/aixcl" engine set llamacpp > /dev/null 2>&1
"${SCRIPT_DIR}/aixcl" stack start --profile usr > /dev/null 2>&1
wait_for_container "llamacpp" 60

# Check for GGUF model
MODEL_NAME=$("${SCRIPT_DIR}/aixcl" models list 2>/dev/null | grep -E "\.gguf" | head -1 | awk '{print $1}')
if [[ -z "$MODEL_NAME" ]]; then
    log_warn "No GGUF model found for llama.cpp"
    log_test_skip "No llama.cpp model available"
    exit 0
fi

log_info "Using llama.cpp model: $MODEL_NAME"

# Update opencode.json for llama.cpp
OPENCODE_CONFIG="${SCRIPT_DIR}/opencode.json"
if [[ -f "$OPENCODE_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
    jq --arg model "$MODEL_NAME" '.provider."aixcl-local".models = {($model): {"name": $model}} | .model = "aixcl-local/\($model)"' "$OPENCODE_CONFIG" > /tmp/opencode_llamacpp.json && mv /tmp/opencode_llamacpp.json "$OPENCODE_CONFIG"
    log_info "Updated opencode.json for llama.cpp"
fi

# Run challenges
total_score=0
challenge_count=0

for i in "${!CHALLENGES[@]}"; do
    level=$((i + 1))
    prompt="${CHALLENGES[$i]}"
    response_file="/tmp/opencode_llamacpp_response_$level.txt"
    
    log_info "Running Challenge $level with llama.cpp..."
    
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

log_info "=== llama.cpp OpenCode Results ==="
log_info "Total Score: $total_score/${challenge_count}0"
log_info "Average Score: $average_score/10"

if [[ $average_score -ge $PASS_THRESHOLD ]]; then
    log_test_pass "llama.cpp OpenCode test passed (avg score: $average_score/10)"
else
    log_error "llama.cpp OpenCode test failed (avg score: $average_score/10)"
    exit 1
fi
