#!/bin/bash
# Alloy entrypoint wrapper - runs Alloy as non-root user
# This script sets up permissions and runs Alloy with reduced privileges

set -e

echo "=== Alloy Non-Root Entrypoint ==="

# Default user/group IDs for alloy user
USER_ID="${USER_ID:-12345}"
GROUP_ID="${GROUP_ID:-12345}"

# Get the Docker group ID from the socket (if available)
DOCKER_GID="${DOCKER_GID:-$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo '999')}"

echo "Target UID: $USER_ID"
echo "Target GID: $GROUP_ID"
echo "Docker GID: $DOCKER_GID"

# Check if running as root
if [ "$(id -u)" = "0" ]; then
    echo "Running as root - setting up permissions..."
    
    # Remove existing alloy user if it has wrong UID (image has alloy:473)
    if id "alloy" >/dev/null 2>&1; then
        CURRENT_UID=$(id -u alloy 2>/dev/null)
        if [ "$CURRENT_UID" != "$USER_ID" ]; then
            echo "Removing existing alloy user UID: $CURRENT_UID to recreate with UID: $USER_ID"
            userdel alloy 2>/dev/null || true
            # Remove the group too if it exists
            groupdel alloy 2>/dev/null || true
        fi
    fi
    
    # Create alloy group
    if ! getent group alloy >/dev/null 2>&1; then
        groupadd -g "$GROUP_ID" alloy 2>/dev/null || true
    fi
    
    # Create alloy user with our target UID
    if ! id "alloy" >/dev/null 2>&1; then
        useradd -u "$USER_ID" -g "$GROUP_ID" -G "$DOCKER_GID" -s /bin/bash -M alloy 2>/dev/null || true
    fi
    
    # Get the actual UID/GID of the alloy user (may differ from requested if user already existed)
    ACTUAL_UID=$(id -u alloy 2>/dev/null || echo "$USER_ID")
    ACTUAL_GID=$(id -g alloy 2>/dev/null || echo "$GROUP_ID")
    
    echo "Actual alloy user UID: $ACTUAL_UID, GID: $ACTUAL_GID"
    
    # Ensure data directory exists and is writable
    if [ -d "/data-alloy" ]; then
        echo "Setting ownership of /data-alloy to $ACTUAL_UID:$ACTUAL_GID"
        chown -R "$ACTUAL_UID:$ACTUAL_GID" /data-alloy 2>/dev/null || true
        chmod 755 /data-alloy 2>/dev/null || true
    fi
    
    # Also ensure the parent directory is accessible
    if [ -d "/data" ]; then
        chmod 755 /data 2>/dev/null || true
    fi
    
    # Ensure tmp directory is writable
    chmod 1777 /tmp 2>/dev/null || true
    
    # Ensure alloy binary is executable by the user
    if [ -f "/bin/alloy" ]; then
        chmod +x /bin/alloy 2>/dev/null || true
    fi
    
    echo "Switching to alloy user UID: $ACTUAL_UID..."
    # Re-run this script as the non-root user using setpriv (works with no-new-privileges)
    exec setpriv --reuid="$ACTUAL_UID" --regid="$ACTUAL_GID" --clear-groups --groups="$DOCKER_GID" /usr/local/bin/alloy-entrypoint.sh
fi

# At this point, we should be running as non-root
echo "Running as user: $(id -u):$(id -g)"

# Verify we can read the Docker socket
if [ -r "/var/run/docker.sock" ]; then
    echo "OK: Docker socket is readable"
else
    echo "WARNING: Docker socket not readable"
fi

# Start Alloy with the provided config
echo "Starting Alloy..."
exec /bin/alloy run /etc/alloy/config.alloy
