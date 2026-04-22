#!/bin/bash
# Alloy entrypoint wrapper
# Alloy runs as root within the container to access Docker socket and log files
# Security is maintained through container restrictions (dropped caps, tmpfs mounts)

set -e

echo "=== Alloy Entrypoint ==="

# Get the Docker group ID from the socket (if available)
DOCKER_GID="${DOCKER_GID:-$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo '999')}"
echo "Docker GID from host: $DOCKER_GID"

# Verify we can read the Docker socket
if [ -r "/var/run/docker.sock" ]; then
    echo "OK: Docker socket is readable"
else
    echo "WARNING: Docker socket not readable - container logs will not be collected"
fi

# Start Alloy with the provided config
echo "Starting Alloy..."
exec /bin/alloy run /etc/alloy/config.alloy
