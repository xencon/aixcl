#!/usr/bin/env bash
set -euo pipefail  # Add error handling

# Add logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Add model validation
validate_models() {
    if [[ -z "${MODELS_BASE:-}" ]]; then
        log "ERROR: MODELS_BASE environment variable is not set"
        exit 1
    fi
}

# Add system requirements check
check_requirements() {
    local min_memory=4  # GB
    local memory=$(free -g | awk '/^Mem:/{print $2}')
    
    if (( memory < min_memory )); then
        log "WARNING: System has less than ${min_memory}GB RAM"
    fi

    if ! command -v nvidia-smi &> /dev/null; then
        log "WARNING: NVIDIA GPU not detected"
    fi
}

# Add model installation with retry logic
install_model() {
    local model=$1
    local max_attempts=3
    local attempt=1

    while ((attempt <= max_attempts)); do
        log "Installing model $model (attempt $attempt/$max_attempts)"
        if ollama pull "$model"; then
            return 0
        fi
        ((attempt++))
        sleep 5
    done
    
    log "ERROR: Failed to install model $model after $max_attempts attempts"
    return 1
}

# Main execution
check_requirements
validate_models

# Install dependencies
if ! command -v jq &> /dev/null; then
    log "Installing jq..."
    apt-get update && apt-get install -y jq
fi

# Start Ollama with proper signal handling
log "Starting Ollama server..."
/bin/ollama serve &
pid=$!
trap "kill $pid" EXIT

# Wait for Ollama to be ready
log "Waiting for Ollama to be ready..."
max_attempts=30
attempt=1
while ! curl -s http://localhost:11434/api/version &>/dev/null; do
    if ((attempt >= max_attempts)); then
        log "ERROR: Ollama failed to start after $max_attempts attempts"
        exit 1
    fi
    sleep 1
    ((attempt++))
done

# Install models
read -ra MODELS_ARRAY <<< "$MODELS_BASE"
log "Installing ${#MODELS_ARRAY[@]} models..."
for model in "${MODELS_ARRAY[@]}"; do
    install_model "$model"
done

log "Model installation complete"
wait $pid
