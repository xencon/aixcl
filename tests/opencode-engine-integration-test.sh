#!/usr/bin/env bash
# OpenCode Engine Integration Test
# Tests all 3 engines with standardized coding challenges

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_FILE="${REPO_ROOT}/tests/opencode-test-results.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test Configuration
ENGINES=("ollama" "vllm" "llamacpp")
MODELS=(
    "qwen2.5-coder:0.5b"
    "Qwen/Qwen2.5-Coder-0.5B-Instruct"
    "Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
)

# Standard Coding Challenges (increasing difficulty)
PROMPTS=(
    "Write a simple Python function that reverses a string without using built-in reverse methods."
    "Implement a binary search algorithm in Python that finds the first and last occurrence of a target in a sorted array with duplicates."
    "Create a Python decorator that implements a rate limiter using a token bucket algorithm with configurable rate and burst capacity. Include thread safety and memory efficiency considerations."
)

DIFFICULTY=("Easy" "Medium" "Hard")

echo "=========================================="
echo "OpenCode Engine Integration Test"
echo "=========================================="
echo ""

# Initialize results file
cat > "$RESULTS_FILE" << 'EOF'
# OpenCode Engine Integration Test Results

**Test Date**: $(date +%Y-%m-%d)
**Test Environment**: Local GPU (NVIDIA RTX 4060 Laptop)

## Test Methodology

Each engine is tested with 3 standardized coding challenges of increasing difficulty:
1. **Easy**: String manipulation
2. **Medium**: Algorithm implementation
3. **Hard**: System design with concurrency

### Scoring Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Response Time | 30% | Time to complete response |
| Code Quality | 40% | Correctness, style, best practices |
| Completeness | 30% | Full solution vs partial |

### Scoring Scale
- **90-100**: Excellent - Production-ready code
- **70-89**: Good - Minor issues, mostly correct
- **50-69**: Acceptable - Functional but has issues
- **Below 50**: Poor - Significant problems

---

## Test Results Summary

| Engine | Overall Score | Avg Response Time | Status |
|--------|---------------|-------------------|--------|
EOF

# Function to test an engine
test_engine() {
    local engine=$1
    local model=$2
    local engine_scores=()
    local engine_times=()
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing Engine: $engine${NC}"
    echo -e "${BLUE}Model: $model${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Switch engine
    echo -e "${YELLOW}Switching to $engine engine...${NC}"
    cd "$REPO_ROOT" && ./aixcl engine set "$engine"
    echo ""
    
    # Start stack
    echo -e "${YELLOW}Starting stack...${NC}"
    cd "$REPO_ROOT" && ./aixcl stack start --profile sys
    echo ""
    
    # Add model
    echo -e "${YELLOW}Adding model: $model${NC}"
    cd "$REPO_ROOT" && ./aixcl models add "$model" || true
    echo ""
    
    # Restart if needed
    echo -e "${YELLOW}Restarting to apply changes...${NC}"
    cd "$REPO_ROOT" && ./aixcl stack restart
    echo ""
    
    # Wait for API to be ready
    echo -e "${YELLOW}Waiting for API to be ready...${NC}"
    local retries=0
    while ! curl -s http://localhost:11434/v1/models > /dev/null 2>&1; do
        sleep 2
        retries=$((retries + 1))
        if [ $retries -gt 30 ]; then
            echo -e "${RED}ERROR: API not responding${NC}"
            return 1
        fi
    done
    echo -e "${GREEN}API is ready!${NC}"
    echo ""
    
    # Test with each prompt
    local prompt_num=1
    for prompt in "${PROMPTS[@]}"; do
        echo -e "${YELLOW}Prompt $prompt_num/${#PROMPTS[@]} (${DIFFICULTY[$((prompt_num-1))]})${NC}"
        echo "Prompt: $prompt"
        echo ""
        
        # Record start time
        local start_time
        start_time=$(date +%s.%N)
        
        # Send request to OpenAI-compatible API
        local response
        response=$(curl -s http://localhost:11434/v1/completions \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"$model\",
                \"prompt\": \"$prompt\",
                \"max_tokens\": 1024,
                \"temperature\": 0.7
            }" 2>/dev/null)
        
        # Record end time
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc)
        
        # Extract completion
        local completion
        completion=$(echo "$response" | grep -oP '"text":\s*"\K[^"]*' | head -1 | sed 's/\\n/\n/g')
        
        echo -e "${GREEN}Response received in ${duration}s${NC}"
        echo "Response preview:"
        echo "$completion" | head -10
        echo "..."
        echo ""
        
        # Store results
        engine_times+=("$duration")
        engine_scores+=("TBD")  # Manual scoring required
        
        # Save detailed result
        cat >> "$RESULTS_FILE" << EOF

### $engine - Prompt $prompt_num (${DIFFICULTY[$((prompt_num-1))]})

**Prompt**: $prompt

**Response Time**: ${duration}s

**Response**:
\`\`\`python
$completion
\`\`\`

**Score**: TBD (Manual review required)

---

EOF
        
        prompt_num=$((prompt_num + 1))
        sleep 2  # Brief pause between prompts
    done
    
    # Stop stack
    echo -e "${YELLOW}Stopping stack...${NC}"
    cd "$REPO_ROOT" && ./aixcl stack stop
    echo ""
    
    return 0
}

# Main test loop
engine_num=0
for engine in "${ENGINES[@]}"; do
    model="${MODELS[$engine_num]}"
    
    if test_engine "$engine" "$model"; then
        echo -e "${GREEN}✓ $engine tests completed${NC}"
    else
        echo -e "${RED}✗ $engine tests failed${NC}"
    fi
    
    engine_num=$((engine_num + 1))
    echo ""
    echo "=========================================="
    echo ""
done

# Finalize results file
cat >> "$RESULTS_FILE" << 'EOF'

## Analysis

### Response Time Comparison

| Engine | Easy | Medium | Hard | Average |
|--------|------|--------|------|---------|

### Code Quality Comparison

| Engine | Easy Score | Medium Score | Hard Score | Average |
|--------|------------|--------------|------------|---------|

### Recommendations

Based on the test results:

1. **Best for Quick Tasks**: TBD
2. **Best for Complex Coding**: TBD
3. **Most Reliable**: TBD

## Conclusion

All three engines have been tested with standardized coding challenges.
Manual review of responses is required for final scoring.

---

*Test completed at $(date)*
EOF

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All engine tests completed!${NC}"
echo -e "${GREEN}Results saved to: $RESULTS_FILE${NC}"
echo -e "${GREEN}========================================${NC}"
