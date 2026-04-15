#!/bin/bash
# pgAdmin entrypoint wrapper - ensures correct permissions and directory setup

set -e

# pgAdmin runs as user 5050 (pgadmin)
PGADMIN_USER="5050"
PGADMIN_HOME="/var/lib/pgadmin"

echo "Setting up pgAdmin directories..."

# Create required directories if they don't exist
mkdir -p "$PGADMIN_HOME/sessions"
mkdir -p "$PGADMIN_HOME/storage"
mkdir -p "/var/log/pgadmin"

# Ensure correct ownership (pgadmin user is 5050)
chown -R "$PGADMIN_USER:$PGADMIN_USER" "$PGADMIN_HOME"
chown -R "$PGADMIN_USER:$PGADMIN_USER" "/var/log/pgadmin"

# Set proper permissions
chmod 755 "$PGADMIN_HOME"
chmod 700 "$PGADMIN_HOME/sessions"
chmod 755 "$PGADMIN_HOME/storage"

echo "Starting pgAdmin as user $PGADMIN_USER..."

# Switch to pgadmin user and run the original entrypoint
exec su - "$PGADMIN_USER" -c "exec /entrypoint.sh"
