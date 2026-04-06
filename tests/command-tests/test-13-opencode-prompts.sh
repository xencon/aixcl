#!/usr/bin/env bash
# Test 13: OpenCode Prompt Integration
# Validates OpenCode can connect to active engine and respond to code challenges
# STRICT: Uses ONLY opencode run command - no API workarounds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-13-opencode-prompts"

# Capture state before test
BACKUP_DIR=$(capture_state "test-13-opencode-prompts")
export BACKUP_DIR

# Cleanup function
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
    cleanup_test_containers
}
trap cleanup EXIT

# ============================================================================
# Configuration
# ============================================================================
TIMEOUT_SECONDS=60
PASS_THRESHOLD=6  # Average score must be >= 6/10
OPENCODE_SESSION_DIR="${HOME}/.local/share/opencode"
RESULTS_FILE="/tmp/opencode_test_results.txt"

# ============================================================================
# Code Challenges
# ============================================================================
declare -a CHALLENGES=(
    "Write a Python function to reverse a string without using built-in reverse methods. Include comments explaining your approach."
    "Implement a binary search tree class in Python with insert and search methods. Include a usage example."
    "Create a Python decorator that implements rate limiting using the token bucket algorithm. Explain how it works."
)

# ============================================================================
# Helper Functions
# ============================================================================

verify_opencode() {
    log_info "Verifying OpenCode CLI is available..."
    if ! command -v opencode > /dev/null 2>&1; then
        log_error "OpenCode CLI not found. Please install opencode."
        return 1
    fi
    
    local version
    version=$(opencode --version 2>&1 || echo "unknown")
    log_info "OpenCode version: $version"
    return 0
}

verify_model_loaded() {
    log_info "Verifying model is loaded..."
    if ! "${SCRIPT_DIR}/aixcl" models list 2>/dev/null | grep -qE "^qwen"; then
        log_error "No model appears to be loaded. Run './aixcl models add' first."
        return 1
    fi
    log_success "Model is loaded"
    return 0
}

capture_session_info() {
    local session_file="$1"
    {
        echo "=== OpenCode Session Info ==="
        echo "Timestamp: $(date -Iseconds)"
        echo "OpenCode Version: $(opencode --version 2>&1 || echo 'unknown')"
        echo "Session Directory: ${OPENCODE_SESSION_DIR}"
        if [[ -d "${OPENCODE_SESSION_DIR}" ]]; then
            echo "Session Files:"
            ls -la "${OPENCODE_SESSION_DIR}" 2>&1 || echo "  (empty or inaccessible)"
        else
            echo "Session Directory Status: Not found"
        fi
        echo "==========================="
    } > "$session_file"
}

score_response() {
    local response_file="$1"
    local level="$2"
    local response
    response=$(cat "$response_file" 2>/dev/null || echo "")
    
    local completeness=0
    local quality=0
    local explanation=0
    
    # Completeness scoring based on level
    case "$level" in
        1)
            # Level 1: Should have def, return, loop/recursion
            if [[ "$response" =~ def[[:space:]]+reverse ]]; then
                ((completeness+=2))
            fi
            if [[ "$response" =~ return[[:space:]] ]]; then
                ((completeness+=1))
            fi
            if [[ "$response" =~ for[[:space:]] ]] || [[ "$response" =~ while[[:space:]] ]] || [[ "$response" =~ recursion ]]; then
                ((completeness+=1))
            fi
            if [[ "$response" =~ \[::-1\] ]]; then
                ((completeness=1))  # Penalty for using slice
            fi
            ;;
        2)
            # Level 2: Should have class, insert, search
            if [[ "$response" =~ class[[:space:]]+ ]]; then
                ((completeness+=2))
            fi
            if [[ "$response" =~ insert ]]; then
                ((completeness+=1))
            fi
            if [[ "$response" =~ search ]]; then
                ((completeness+=1))
            fi
            ;;
        3)
            # Level 3: Should have decorator, token, bucket
            if [[ "$response" =~ def[[:space:]]+ ]] && [[ "$response" =~ decorator ]]; then
                ((completeness+=2))
            fi
            if [[ "$response" =~ token ]]; then
                ((completeness+=1))
            fi
            if [[ "$response" =~ bucket ]]; then
                ((completeness+=1))
            fi
            ;;
    esac
    
    # Quality: Code structure
    if [[ "$response" =~ ^[[:space:]]*def[[:space:]] ]]; then
        ((quality+=1))
    fi
    if [[ "$response" =~ ^[[:space:]]*class[[:space:]] ]]; then
        ((quality+=1))
    fi
    if [[ "$response" =~ import[[:space:]] ]]; then
        ((quality+=1))
    fi
    
    # Explanation: Comments and docs
    if [[ "$response" =~ \"\"\" ]]; then
        ((explanation+=2))
    fi
    if [[ "$response" =~ ^[[:space:]]*# ]]; then
        ((explanation+=1))
    fi
    if [[ "$response" =~ Example ]] || [[ "$response" =~ Usage ]]; then
        ((explanation+=1))
    fi
    
    # Cap scores
    completeness=$((completeness > 4 ? 4 : completeness))
    quality=$((quality > 3 ? 3 : quality))
    explanation=$((explanation > 3 ? 3 : explanation))
    
    local total=$((completeness + quality + explanation))
    echo "$total"
}

run_challenge() {
    local level="$1"
    local prompt="$2"
    local response_file="$3"
    local result_file="$4"
    local score_file="$5"
    
    log_info "Running Challenge $level..."
    log_info "Prompt: ${prompt:0:50}..."
    
    local start_time
    start_time=$(date +%s)
    
    # Run opencode with timeout - STRICT: Only opencode run command
    local exit_code=0
    if ! timeout "$TIMEOUT_SECONDS" opencode run "$prompt" > "$response_file" 2>&1; then
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_warn "Challenge $level: TIMEOUT after ${TIMEOUT_SECONDS}s"
            echo "TIMEOUT" >> "$result_file"
        else
            log_warn "Challenge $level: Failed with exit code $exit_code"
            echo "FAILED" >> "$result_file"
        fi
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Score the response
    local score
    score=$(score_response "$response_file" "$level")
    
    # Write score to file
    echo "$score" > "$score_file"
    
    # Log result
    {
        echo ""
        echo "=== Challenge $level ==="
        echo "Duration: ${duration}s"
        echo "Score: $score/10"
        echo "Exit Code: $exit_code"
        echo "Response Preview:"
        head -5 "$response_file" | sed 's/^/  /'
        echo "========================"
    } >> "$result_file"
    
    log_info "Challenge $level: Score=$score/10, Duration=${duration}s"
}

# ============================================================================
# Main Test Execution
# ============================================================================

# Pre-flight checks
verify_opencode || exit 1

# Ensure stack is running BEFORE checking for models
# Force Ollama for OpenCode tests as it's the most reliable
CURRENT_ENGINE="ollama"
"${SCRIPT_DIR}/aixcl" engine set ollama > /dev/null 2>&1 || true

if ! docker ps | grep -qE "ollama"; then
    log_info "Starting stack with Ollama..."
    "${SCRIPT_DIR}/aixcl" stack start --profile usr > /dev/null 2>&1
fi

# Wait for Ollama container (forced above)
CURRENT_ENGINE="ollama"
CONTAINER_NAME=$(get_engine_container "$CURRENT_ENGINE")
if [[ -n "$CONTAINER_NAME" ]]; then
    wait_for_container "$CONTAINER_NAME" 60
fi

# Wait for Ollama API to be ready
log_info "Waiting for Ollama API..."
sleep 5  # Give Ollama time to initialize
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        log_info "Ollama API is ready"
        break
    fi
    sleep 2
done

# Ensure model is loaded
log_info "Ensuring model is loaded..."
if ! "${SCRIPT_DIR}/aixcl" models list 2>/dev/null | grep -qE "^qwen"; then
    log_info "Adding default model for testing..."
    MODEL="qwen2.5-coder:0.5b"
    log_info "Adding model: $MODEL"
    if ! "${SCRIPT_DIR}/aixcl" models add "$MODEL" 2>&1; then
        log_error "Failed to add model: $MODEL"
        log_info "Checking if Ollama is still running..."
        docker ps | grep -E "ollama" || log_warn "Ollama container not running"
        exit 1
    fi
    sleep 5
fi

# Now check if model is loaded
verify_model_loaded || exit 1

# Update opencode.json with the model configuration
OPENCODE_CONFIG="${SCRIPT_DIR}/opencode.json"
if [[ -f "$OPENCODE_CONFIG" ]]; then
    log_info "Configuring opencode.json for model access..."
    # Get the first available model - extract from the table format (NAME column)
    # Format: "qwen2.5-coder:0.5b    4ff64a7f502a    397 MB    8 hours ago"
    # The model name is the first column, which includes the tag (e.g., qwen2.5-coder:0.5b)
    MODEL_NAME=$("${SCRIPT_DIR}/aixcl" models list 2>/dev/null | awk 'NR>2 && $1 ~ /^(qwen|mistral)/ {print $1; exit}')
    # Fallback using grep and awk
    if [[ -z "$MODEL_NAME" ]]; then
        MODEL_NAME=$("${SCRIPT_DIR}/aixcl" models list 2>/dev/null | grep -E "^\s*(qwen|mistral)" | head -1 | awk '{print $1}')
    fi
    # Extract just the filename for GGUF models (llama.cpp uses filenames as keys)
    if [[ "$CURRENT_ENGINE" == "llamacpp" ]] && [[ "$MODEL_NAME" == *"/"* ]]; then
        MODEL_NAME=$(basename "$MODEL_NAME")
    fi
    if [[ -n "$MODEL_NAME" ]] && command -v jq >/dev/null 2>&1; then
        jq --arg model "$MODEL_NAME" '.provider."aixcl-local".models = {($model): {"name": $model}} | .model = "aixcl-local/\($model)"' "$OPENCODE_CONFIG" > /tmp/opencode_updated.json && mv /tmp/opencode_updated.json "$OPENCODE_CONFIG"
        log_info "Updated opencode.json with model: $MODEL_NAME"
    elif [[ -n "$MODEL_NAME" ]]; then
        # Fallback without jq
        sed -i "s|\"model\": \"aixcl-local/.*\"|\"model\": \"aixcl-local/$MODEL_NAME\"|" "$OPENCODE_CONFIG"
        log_info "Updated opencode.json (basic - install jq for full sync)"
    fi
else
    log_warn "opencode.json not found. OpenCode may not work properly."
fi

# Capture session info before test
log_info "Capturing session info..."
capture_session_info "/tmp/opencode_session_before.txt"

# Run challenges
total_score=0
challenge_count=0

for i in "${!CHALLENGES[@]}"; do
    level=$((i + 1))
    prompt="${CHALLENGES[$i]}"
    response_file="/tmp/opencode_response_$level.txt"
    score_file="/tmp/opencode_score_$level.txt"
    
    # Run challenge (writes score to score_file)
    run_challenge "$level" "$prompt" "$response_file" "$RESULTS_FILE" "$score_file"
    
    # Read score from file
    score=0
    if [[ -f "$score_file" ]]; then
        score=$(cat "$score_file" 2>/dev/null || echo "0")
    fi
    # Ensure score is a number (default to 0 if empty or invalid)
    score=${score:-0}
    total_score=$((total_score + score))
    challenge_count=$((challenge_count + 1))
    
    # Continue to next challenge even if this one failed
    continue
done

# Capture session info after test
capture_session_info "/tmp/opencode_session_after.txt"

# Calculate average
if [[ $challenge_count -gt 0 ]]; then
    average_score=$((total_score / challenge_count))
else
    average_score=0
fi

# Report results
log_info ""
log_info "=== OpenCode Prompt Test Results ==="
log_info "Total Score: $total_score/${challenge_count}0"
log_info "Average Score: $average_score/10"
log_info "Pass Threshold: $PASS_THRESHOLD/10"

# Show detailed results
if [[ -f "$RESULTS_FILE" ]]; then
    cat "$RESULTS_FILE"
fi

# Determine pass/fail
if [[ $average_score -ge $PASS_THRESHOLD ]]; then
    log_test_pass "OpenCode prompt test passed (avg score: $average_score/10)"
else
    log_error "OpenCode prompt test failed (avg score: $average_score/10, threshold: $PASS_THRESHOLD/10)"
    exit 1
fi
