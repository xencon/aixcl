#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit

KEY_FILE=.webui_secret_key
PORT="${PORT:-8080}"
HOST="${HOST:-0.0.0.0}"
if test "$WEBUI_SECRET_KEY $WEBUI_JWT_SECRET_KEY" = " "; then
  echo "Loading WEBUI_SECRET_KEY from file, not provided as an environment variable."

  if ! [ -e "$KEY_FILE" ]; then
    echo "Generating WEBUI_SECRET_KEY"
    # Generate a random value to use as a WEBUI_SECRET_KEY in case the user didn't provide one.
    echo $(head -c 12 /dev/random | base64) > "$KEY_FILE"
  fi

  echo "Loading WEBUI_SECRET_KEY from $KEY_FILE"
  WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
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
