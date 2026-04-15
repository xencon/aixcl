#!/bin/bash
# llama.cpp entrypoint wrapper - prevents crash-loop when model is missing
# This script provides graceful handling for the llama.cpp server when no model exists

set -e

# Get the model filename from environment or use a placeholder
MODEL_FILE="${INFERENCE_MODEL:-}"

if [ -z "$MODEL_FILE" ]; then
    echo "⚠️  INFERENCE_MODEL environment variable not set"
    echo "   AIXCL will set this when you run: ./aixcl models add <model.gguf>"
    echo "   Container will exit gracefully and restart when model is available"
    exit 0
fi

# Extract just the filename from full path (e.g., "Qwen/.../model.gguf" -> "model.gguf")
MODEL_BASENAME="$(basename "$MODEL_FILE")"
MODEL_PATH="/models/${MODEL_BASENAME}"

if [ ! -f "$MODEL_PATH" ]; then
    echo "⚠️  Model file not found: ${MODEL_PATH}"
    echo "   Download a model using: ./aixcl models add <path/to/model.gguf>"
    echo "   Example: ./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
    echo ""
    echo "   Container will exit gracefully (no crash-loop)"
    echo "   Run models add, then the container will auto-restart with the model"
    exit 0
fi

echo "✅ Model found: ${MODEL_BASENAME}"

# Create a symlink with the original full path name if it differs from basename
# This ensures API calls work with either the short name or full path
if [ "$MODEL_FILE" != "$MODEL_BASENAME" ] && [ ! -f "/models/${MODEL_FILE}" ]; then
    # Create directory structure for the full path if needed
    MODEL_DIR="$(dirname "/models/${MODEL_FILE}")"
    if [ "$MODEL_DIR" != "/models" ]; then
        mkdir -p "$MODEL_DIR"
    fi
    # Create symlink from full path to actual file
    ln -sf "$MODEL_PATH" "/models/${MODEL_FILE}"
    echo "   Created symlink: ${MODEL_FILE} -> ${MODEL_BASENAME}"
fi

echo "🚀 Starting llama.cpp server..."

# Start the actual llama.cpp server with the model
exec /app/llama-server -m "$MODEL_PATH" "$@"
