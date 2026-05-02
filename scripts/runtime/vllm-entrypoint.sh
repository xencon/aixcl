#!/usr/bin/env bash
# vLLM entrypoint wrapper - compatible with security hardening
# Runs vLLM server directly without user switching

set -e

echo "=== vLLM Entrypoint (Security-Hardened Compatible) ==="

# Get current user info
CURRENT_USER=$(id -un)
CURRENT_UID=$(id -u)
echo "Running as user: $CURRENT_USER (UID: $CURRENT_UID)"

# Ensure home directory exists
VLLM_HOME="/home/vllm"
mkdir -p "$VLLM_HOME"

# Create cache directory if needed (container may be running as non-root)
mkdir -p "$VLLM_HOME/.cache/huggingface"

# If we have write access, ensure proper ownership of home directory
if [ -w "$VLLM_HOME" ]; then
    echo "Ensuring cache directory permissions..."
    chown -R "$(id -u):$(id -g)" "$VLLM_HOME/.cache" 2>/dev/null || true
fi

# Set home environment variable
export HOME="$VLLM_HOME"
export HF_HOME="$VLLM_HOME/.cache/huggingface"
export TRANSFORMERS_CACHE="$VLLM_HOME/.cache/huggingface"

echo "Home directory: $HOME"
echo "Cache directory: $HF_HOME"

# Verify cache directory is writable
if [ ! -w "$HF_HOME" ]; then
    echo "Warning: Cache directory may not be writable. Model downloads may fail."
fi

echo "Starting vLLM server..."
echo "Model: ${VLLM_MODEL:-Qwen/Qwen2.5-Coder-0.5B-Instruct}"

# Start vLLM server directly
# Do not use 'su' - it requires privileges incompatible with security hardening
exec python3 -m vllm.entrypoints.openai.api_server "$@"
