#!/usr/bin/env bash
# Open WebUI Non-Root Entrypoint
# This script sets up proper permissions and then runs Open WebUI as non-root user

set -e

# Default user/group IDs
USER_ID="${USER_ID:-1000}"
GROUP_ID="${GROUP_ID:-1000}"

echo "=== Open WebUI Non-Root Entrypoint ==="
echo "Target UID: $USER_ID"
echo "Target GID: $GROUP_ID"

# Check if running as root (required for permission setup)
if [ "$(id -u)" = "0" ]; then
    echo "Running as root - setting up permissions..."
    
    # Create non-root user if it doesn't exist
    if ! id "webui" &>/dev/null; then
        groupadd -g "$GROUP_ID" -o webui 2>/dev/null || true
        useradd -u "$USER_ID" -g "$GROUP_ID" -o -m -s /bin/bash webui 2>/dev/null || true
    fi
    
    # Ensure data directories exist and have correct ownership
    # These are the volumes mounted from docker-compose
    for dir in /app/backend/data /app/data; do
        if [ -d "$dir" ]; then
            echo "Setting ownership of $dir to $USER_ID:$GROUP_ID"
            chown -R "$USER_ID:$GROUP_ID" "$dir" 2>/dev/null || true
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
    
    # Ensure the startup script is executable (ignore errors if read-only mount)
    if [ -f "/app/backend/openwebui.sh" ]; then
        chmod +x /app/backend/openwebui.sh 2>/dev/null || true
        chown "$USER_ID:$GROUP_ID" /app/backend/openwebui.sh 2>/dev/null || true
    fi
    
    # Ensure the entrypoint can write to /tmp (uvicorn needs this)
    chown -R "$USER_ID:$GROUP_ID" /tmp 2>/dev/null || true
    chmod 1777 /tmp
    
    echo "Switching to webui user (UID: $USER_ID)..."
    # Re-run this script as the non-root user using su
    # Use -c to execute command with the user's environment
    export -n USER_ID GROUP_ID  # Don't export these to avoid confusion
    exec su - webui -c 'exec /usr/local/bin/openwebui-entrypoint.sh'
fi

# At this point, we should be running as non-root
CURRENT_UID="$(id -u)"
CURRENT_GID="$(id -g)"
echo "Running as user: $CURRENT_UID:$CURRENT_GID"

# Change to backend directory
cd /app/backend || exit 1

# Execute the original Open WebUI startup script
echo "Starting Open WebUI..."
exec bash /app/backend/openwebui.sh "$@"
