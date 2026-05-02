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
    head -c 12 /dev/random | base64 > "$KEY_FILE"
  fi

  echo "Loading WEBUI_SECRET_KEY from $KEY_FILE"
  WEBUI_SECRET_KEY=$(cat "$KEY_FILE")
fi

echo "Starting Open WebUI..."
WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*' &
webui_pid=$!

echo "Waiting for webui to be ready..."
# shellcheck disable=SC2034
for i in {1..60}; do
  if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "Open WebUI is ready at http://$HOST:$PORT"
    break
  fi
  sleep 1
done

# Optional: Try to create admin user (don't fail if this doesn't work)
if [ -n "${OPENWEBUI_EMAIL:-}" ] && [ -n "${OPENWEBUI_PASSWORD:-}" ]; then
  echo "Attempting to auto-create admin user (optional)..."
  
  # Prepare JSON payload
  if command -v jq >/dev/null 2>&1; then
    JSON_PAYLOAD=$(jq -n \
      --arg email "${OPENWEBUI_EMAIL}" \
      --arg password "${OPENWEBUI_PASSWORD}" \
      '{email: $email, password: $password, name: "Admin"}')
  else
    JSON_PAYLOAD=$(python3 -c "import json, os; print(json.dumps({'email': os.environ.get('OPENWEBUI_EMAIL', ''), 'password': os.environ.get('OPENWEBUI_PASSWORD', ''), 'name': 'Admin'}))")
  fi
  
  # Try once - if it fails, just log and continue
  response=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "http://localhost:8080/api/v1/auths/signup" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d "${JSON_PAYLOAD}" \
    2>/dev/null || echo "000")
  
  if [ "$response" = "200" ] || [ "$response" = "201" ]; then
    echo "Admin user auto-created successfully"
  elif [ "$response" = "409" ]; then
    echo "Admin user already exists"
  else
    echo "Admin auto-creation skipped (HTTP $response) - create manually at http://$HOST:$PORT"
  fi
else
  echo "Create first admin at http://$HOST:$PORT (sign up with any email)"
fi

# Keep the webui process running
echo "Open WebUI is running. Press Ctrl+C to stop."
wait $webui_pid
