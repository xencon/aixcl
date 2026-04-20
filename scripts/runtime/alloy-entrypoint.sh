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
    
    # Create alloy group if it doesn't exist
    if ! getent group alloy >/dev/null 2>&1; then
        groupadd -g "$GROUP_ID" alloy 2>/dev/null || groupadd alloy 2>/dev/null || true
    fi
    
    # Create alloy user if it doesn't exist
    if ! id "alloy" >/dev/null 2>&1; then
        useradd -u "$USER_ID" -g "$GROUP_ID" -G "$DOCKER_GID" -s /bin/false -M alloy 2>/dev/null || \
        useradd -u "$USER_ID" -g "$GROUP_ID" -s /bin/false -M alloy 2>/dev/null || true
    fi
    
    # Ensure data directory exists and is writable
    if [ -d "/data-alloy" ]; then
        echo "Setting ownership of /data-alloy to $USER_ID:$GROUP_ID"
        chown -R "$USER_ID:$GROUP_ID" /data-alloy 2>/dev/null || true
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
    
    echo "Switching to alloy user (UID: $USER_ID)..."
    # Re-run this script as the non-root user
    exec su -s /bin/bash alloy -c 'exec /usr/local/bin/alloy-entrypoint.sh'
fi

# At this point, we should be running as non-root
echo "Running as user: $(id -u):$(id -g)"

# Verify we can read the Docker socket
if [ -r "/var/run/docker.sock" ]; then
    echo "✅ Docker socket is readable"
else
    echo "⚠️  Warning: Docker socket not readable (may affect container log collection)"
fi

# Start Alloy with the provided config
echo "🚀 Starting Alloy..."
exec /bin/alloy run /etc/alloy/config.alloy