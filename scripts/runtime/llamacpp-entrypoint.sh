#!/bin/bash
# llama.cpp entrypoint wrapper - prevents crash-loop when model is missing
# This script provides graceful handling for the llama.cpp server when no model exists

set -e

# Get the model filename from environment or use a placeholder
MODEL_FILE="${LLAMACPP_MODEL:-}"

if [ -z "$MODEL_FILE" ]; then
    echo "⚠️  LLAMACPP_MODEL environment variable not set"
    echo "   AIXCL will set this when you run: ./aixcl models add <model.gguf>"
    echo "   Container will exit gracefully and restart when model is available"
    exit 0
fi

MODEL_PATH="/models/${MODEL_FILE}"

if [ ! -f "$MODEL_PATH" ]; then
    echo "⚠️  Model file not found: ${MODEL_PATH}"
    echo "   Download a model using: ./aixcl models add <path/to/model.gguf>"
    echo "   Example: ./aixcl models add bartowski/Qwen2.5-Coder-0.5B-Instruct-GGUF/Qwen2.5-Coder-0.5B-Instruct-Q4_K_M.gguf"
    echo ""
    echo "   Container will exit gracefully (no crash-loop)"
    echo "   Run models add, then the container will auto-restart with the model"
    exit 0
fi

echo "✅ Model found: ${MODEL_FILE}"
echo "🚀 Starting llama.cpp server..."

# Start the actual llama.cpp server with the model
exec /app/llama-server -m "$MODEL_PATH" "$@"
