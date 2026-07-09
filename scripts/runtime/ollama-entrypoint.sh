#!/usr/bin/env bash
# Ollama entrypoint wrapper - ensures correct permissions for Ollama data directory

set -e

# Configuration
OLLAMA_USER="ubuntu"
OLLAMA_UID="1000"
OLLAMA_HOME="/home/ubuntu"
OLLAMA_DATA="$OLLAMA_HOME/.ollama"

# Create ubuntu user if it doesn't exist
if ! id "$OLLAMA_USER" &>/dev/null; then
    echo "Creating $OLLAMA_USER user (UID: $OLLAMA_UID)..."
    useradd -m -u "$OLLAMA_UID" "$OLLAMA_USER"
fi

# Ensure .ollama directory exists with correct ownership
mkdir -p "$OLLAMA_DATA"
chown -R "$OLLAMA_USER:$OLLAMA_USER" "$OLLAMA_HOME"

# Add user to video and render groups for GPU access (if they exist)
usermod -aG video,render "$OLLAMA_USER" 2>/dev/null || true

echo "Starting Ollama as $OLLAMA_USER user..."

# Switch to the ollama user and exec ollama directly so PID 1 receives
# SIGTERM (su as PID 1 swallows signals, forcing a SIGKILL at the stop
# timeout). setpriv ships with util-linux in the base image;
# --init-groups picks up the video/render groups added above, and unlike
# 'su -' it preserves the container environment (OLLAMA_HOST, tuning vars).
exec setpriv --reuid "$OLLAMA_UID" --regid "$OLLAMA_UID" --init-groups \
    env HOME="$OLLAMA_HOME" USER="$OLLAMA_USER" LOGNAME="$OLLAMA_USER" ollama serve
