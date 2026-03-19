#!/usr/bin/env bash
# Test script for AIXCL Model Inference
# This script verifies that the active inference engine can successfully process a prompt.

set -u

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/docker_utils.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/color.sh"

# Load environment variables
if [ -f "${SCRIPT_DIR}/.env" ]; then
    load_env_file "${SCRIPT_DIR}/.env"
fi

INFERENCE_ENGINE=${INFERENCE_ENGINE:-ollama}
TEST_MODEL=${1:-"qwen2.5-coder:1.5b"}

echo "=========================================="
echo "AIXCL Model Inference Test"
echo "=========================================="
echo "Engine: $INFERENCE_ENGINE"
echo "Model: $TEST_MODEL"
echo ""

# Ensure model is present
echo "Ensuring model '$TEST_MODEL' is available..."
cd "$SCRIPT_DIR" && ./aixcl models add "$TEST_MODEL"

echo ""
echo "Sending test prompt: 'Why is the sky blue? Answer in one sentence.'"
echo "-----------------------------------"

case "$INFERENCE_ENGINE" in
    ollama)
        RESPONSE=$(curl -s -X POST http://127.0.0.1:11434/api/generate -d "{\"model\": \"$TEST_MODEL\", \"prompt\": \"Why is the sky blue? Answer in one sentence.\", \"stream\": false}" | jq -r '.response' 2>/dev/null)
        ;;
    *)
        # OpenAI compatible (vLLM, llama.cpp)
        RESPONSE=$(curl -s -X POST http://127.0.0.1:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"$TEST_MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"Why is the sky blue? Answer in one sentence.\"}], \"temperature\": 0}" \
            | jq -r '.choices[0].message.content' 2>/dev/null)
        ;;
esac

if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
    print_success "Received response:"
    echo "$RESPONSE"
    echo ""
    print_success "✅ Model inference test passed!"
    exit 0
else
    print_error "Failed to get response from model."
    echo "Check logs: ./aixcl stack logs engine"
    exit 1
fi
