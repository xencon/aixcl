#!/usr/bin/env bash
set -euo pipefail  # Add error handling

# Add logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Add configuration validation
validate_config() {
    if [[ -z "${OPENWEBUI_EMAIL:-}" ]] || [[ -z "${OPENWEBUI_PASSWORD:-}" ]]; then
        log "ERROR: OPENWEBUI_EMAIL and OPENWEBUI_PASSWORD must be set"
        exit 1
    fi
}

# Add cleanup function
cleanup() {
    log "Cleaning up..."
    kill $webui_pid 2>/dev/null || true
}
trap cleanup EXIT

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

validate_config

# Improve secret key generation
KEY_FILE=.webui_secret_key
PORT="${PORT:-3000}"
HOST="${HOST:-0.0.0.0}"
if [[ -z "${WEBUI_SECRET_KEY:-}" ]] && [[ -z "${WEBUI_JWT_SECRET_KEY:-}" ]]; then
    log "Loading WEBUI_SECRET_KEY from file"

    if ! [ -e "$KEY_FILE" ]; then
        log "Generating WEBUI_SECRET_KEY"
        openssl rand -base64 32 > "$KEY_FILE"
    fi

    WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
fi

WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*' &
webui_pid=$!
echo "Waiting for webui to start..."

# Add retry logic for health check
wait_for_webui() {
    local max_attempts=30
    local attempt=1
    
    while ! curl -s http://localhost:8080/health > /dev/null; do
        if ((attempt >= max_attempts)); then
            log "ERROR: WebUI failed to start after $max_attempts attempts"
            exit 1
        fi
        log "Waiting for WebUI to start (attempt $attempt/$max_attempts)..."
        sleep 1
        ((attempt++))
    done
}

wait_for_webui

echo "Creating admin user..."
curl \
  -X POST "http://localhost:8080/api/v1/auths/signup" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{ \"email\": \"${OPENWEBUI_EMAIL}\", \"password\": \"${OPENWEBUI_PASSWORD}\", \"name\": \"Admin\" }"
echo "Shutting down webui..."
kill $webui_pid



WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" exec uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*'