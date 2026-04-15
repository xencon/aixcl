#!/bin/bash
# pgAdmin entrypoint wrapper - ensures correct permissions and directory setup

set -e

# pgAdmin runs as user 5050 (pgadmin)
PGADMIN_UID="5050"
PGADMIN_HOME="/var/lib/pgadmin"

echo "Setting up pgAdmin directories..."

# Create pgadmin user if it doesn't exist
if ! id "$PGADMIN_UID" &>/dev/null; then
    echo "Creating pgadmin user (UID: $PGADMIN_UID)..."
    useradd -m -u "$PGADMIN_UID" pgadmin
fi

# Create required directories if they don't exist
mkdir -p "$PGADMIN_HOME/sessions"
mkdir -p "$PGADMIN_HOME/storage"
mkdir -p "/var/log/pgadmin"

# Ensure correct ownership (pgadmin user is 5050)
chown -R "$PGADMIN_UID:$PGADMIN_UID" "$PGADMIN_HOME"
chown -R "$PGADMIN_UID:$PGADMIN_UID" "/var/log/pgadmin"

# Set proper permissions
chmod 755 "$PGADMIN_HOME"
chmod 700 "$PGADMIN_HOME/sessions"
chmod 755 "$PGADMIN_HOME/storage"

echo "Starting pgAdmin as user $PGADMIN_UID..."

# Switch to pgadmin user and run the original entrypoint
exec su - pgadmin -c "exec /entrypoint.sh"
