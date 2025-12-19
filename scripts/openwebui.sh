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
  # Fallback: use curl's --data-urlencode for safer parameter passing
  # Note: This requires the API to accept form-encoded data, which may not work
  # If jq is not available, consider installing it: apt-get install jq
  echo "Warning: jq not found. Using basic JSON construction (may be unsafe with special characters)." >&2
  curl \
    -X POST "http://localhost:8080/api/v1/auths/signup" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{ \"email\": \"${OPENWEBUI_EMAIL}\", \"password\": \"${OPENWEBUI_PASSWORD}\", \"name\": \"Admin\" }"
fi
echo "Shutting down webui..."
kill $webui_pid



WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" exec uvicorn open_webui.main:app --host "$HOST" --port "$PORT" --forwarded-allow-ips '*'
