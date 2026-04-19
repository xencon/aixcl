#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

# Store secret key in data directory (writable by non-root user)
DATA_DIR="${DATA_DIR:-/app/backend/data}"
KEY_FILE="$DATA_DIR/.webui_secret_key"
PORT="${PORT:-8080}"
HOST="${HOST:-127.0.0.1}"
if test "$WEBUI_SECRET_KEY $WEBUI_JWT_SECRET_KEY" = " "; then
  echo "Loading WEBUI_SECRET_KEY from file, not provided as an environment variable."

  if ! [ -e "$KEY_FILE" ]; then
    echo "Generating WEBUI_SECRET_KEY"
    # Generate a random value to use as a WEBUI_SECRET_KEY in case the user didn't provide one.
    head -c 12 /dev/random | base64 > "$KEY_FILE"
  fi

  echo "Loading WEBUI_SECRET_KEY from $KEY_FILE"
  WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
fi

# Wait for PostgreSQL to be ready (if DATABASE_URL is set)
if [ -n "${DATABASE_URL:-}" ]; then
  echo "Waiting for PostgreSQL to be ready..."
  # Extract host and port from DATABASE_URL
  # Format: postgresql://user:pass@host:port/dbname
  pg_host=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
  pg_port=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
  pg_host="${pg_host:-127.0.0.1}"
  pg_port="${pg_port:-5432}"
  
  # Wait for PostgreSQL with timeout (60 seconds)
  pg_ready=false
  for i in {1..30}; do
    if timeout 2 bash -c "echo > /dev/tcp/$pg_host/$pg_port" 2>/dev/null; then
      pg_ready=true
      echo "PostgreSQL is ready!"
      break
    fi
    echo "Waiting for PostgreSQL... ($i/30)"
    sleep 2
  done
  
  if [ "$pg_ready" = false ]; then
    echo "Warning: PostgreSQL did not become ready, Open WebUI may fall back to SQLite"
  fi
fi

WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*' &
webui_pid=$!
echo "Waiting for webui to start..."
while ! curl -s http://localhost:8080/health > /dev/null; do
  sleep 1
done
echo "Creating admin user..."
# Use jq to safely construct JSON payload to prevent injection
if command -v jq >/dev/null 2>&1; then
  JSON_PAYLOAD=$(jq -n \
    --arg email "${OPENWEBUI_EMAIL}" \
    --arg password "${OPENWEBUI_PASSWORD}" \
    '{email: $email, password: $password, name: "Admin"}')
  curl \
    -X POST "http://localhost:8080/api/v1/auths/signup" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d "${JSON_PAYLOAD}"
else
  # Fallback: use python3 to securely generate JSON payload
  # This prevents injection vulnerabilities from environment variables containing special characters
  if command -v python3 >/dev/null 2>&1; then
    JSON_PAYLOAD=$(python3 -c "import json, os; print(json.dumps({'email': os.environ.get('OPENWEBUI_EMAIL', ''), 'password': os.environ.get('OPENWEBUI_PASSWORD', ''), 'name': 'Admin'}))")
    curl \
      -X POST "http://localhost:8080/api/v1/auths/signup" \
      -H "accept: application/json" \
      -H "Content-Type: application/json" \
      -d "${JSON_PAYLOAD}"
  else
    echo "Error: Neither jq nor python3 found. Cannot securely generate admin user payload." >&2
    exit 1
  fi
fi
echo "Shutting down webui..."
kill $webui_pid



WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" exec uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*'
