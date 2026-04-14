#!/bin/bash
# vLLM entrypoint wrapper - runs server as non-root user with GPU access

set -e

# Configuration
VLLM_USER="vllm"
VLLM_UID="1000"
VLLM_HOME="/home/vllm"

# Create vllm user if it doesn't exist
if ! id "$VLLM_USER" &>/dev/null; then
    echo "Creating $VLLM_USER user (UID: $VLLM_UID)..."
    useradd -m -u "$VLLM_UID" "$VLLM_USER"
    
    # Add to groups for GPU access (if they exist)
    usermod -aG video,render "$VLLM_USER" 2>/dev/null || true
fi

# Ensure home directory exists with correct ownership
mkdir -p "$VLLM_HOME"
chown -R "$VLLM_USER:$VLLM_USER" "$VLLM_HOME"

# Create cache directory
mkdir -p "$VLLM_HOME/.cache/huggingface"
chown -R "$VLLM_USER:$VLLM_USER" "$VLLM_HOME/.cache"

# Set password for su
echo "$VLLM_USER:$VLLM_USER" | chpasswd

echo "Starting vLLM as $VLLM_USER user..."

# Switch to vllm user and execute the vllm server
# Use su to preserve environment variables
exec su - "$VLLM_USER" -c "exec python3 -m vllm.entrypoints.openai.api_server $*"
