#!/usr/bin/env bash
# Ollama entrypoint wrapper - ensures correct permissions for Ollama data directory

set -euo pipefail

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

# Ensure .ollama directory exists with correct ownership. Model store
# ownership is REQUIRED before the privilege drop: ollama cannot write
# models as UID 1000 into a root-owned volume.
mkdir -p "$OLLAMA_DATA"
if ! chown -R "$OLLAMA_USER:$OLLAMA_USER" "$OLLAMA_HOME"; then
    echo "[ERROR] chown of $OLLAMA_HOME failed — container likely lacks CAP_CHOWN"
    exit 1
fi

# Add user to video and render groups for GPU access (optional: the
# groups do not exist on hosts without GPU device nodes)
usermod -aG video,render "$OLLAMA_USER" \
    || echo "[WARN] could not add $OLLAMA_USER to video/render groups; GPU device access may be unavailable (normal on CPU-only hosts)"

echo "Starting Ollama as $OLLAMA_USER user..."

# Switch to the ollama user and exec ollama directly so PID 1 receives
# SIGTERM (su as PID 1 swallows signals, forcing a SIGKILL at the stop
# timeout). setpriv ships with util-linux in the base image;
# --init-groups picks up the video/render groups added above, and unlike
# 'su -' it preserves the container environment (OLLAMA_HOST, tuning vars).
exec setpriv --reuid "$OLLAMA_UID" --regid "$OLLAMA_UID" --init-groups \
    env HOME="$OLLAMA_HOME" USER="$OLLAMA_USER" LOGNAME="$OLLAMA_USER" ollama serve
