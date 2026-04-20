#!/bin/bash
# pgAdmin entrypoint wrapper - runs pgAdmin as non-root user
# This script sets up permissions and runs pgAdmin with reduced privileges

set -e

echo "=== pgAdmin Non-Root Entrypoint ==="

# Create the servers.json file with proper permissions (required for pgAdmin to connect to PostgreSQL)
cat > /pgadmin4/servers.json << 'EOF'
{
  "Servers": {
    "1": {
      "Group": "Servers",
      "Name": "AIXCL",
      "Host": "localhost",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "admin",
      "Password": "admin",
      "SSLMode": "prefer",
      "Favorite": true
    }
  }
}
EOF

chmod 644 /pgadmin4/servers.json 2>/dev/null || true

# pgAdmin runs as pgadmin user (UID 5050) in official image
USER_ID="${PGADMIN_USER_ID:-5050}"
GROUP_ID="${PGADMIN_GROUP_ID:-5050}"

echo "Target UID: $USER_ID"
echo "Target GID: $GROUP_ID"

# Check if running as root
if [ "$(id -u)" = "0" ]; then
    echo "Running as root - setting up permissions..."
    
    # Ensure session directory exists (required for pgAdmin to start)
    mkdir -p /var/lib/pgadmin/sessions
    mkdir -p /var/lib/pgadmin/storage
    
    # Create pgadmin group if it doesn't exist
    if ! getent group pgadmin >/dev/null 2>&1; then
        groupadd -g "$GROUP_ID" pgadmin 2>/dev/null || groupadd pgadmin 2>/dev/null || true
    fi
    
    # Create pgadmin user if it doesn't exist
    if ! id pgadmin >/dev/null 2>&1; then
        useradd -u "$USER_ID" -g "$GROUP_ID" -s /bin/false -M pgadmin 2>/dev/null || \
        useradd -u "$USER_ID" -g "$GROUP_ID" -s /bin/false -M pgadmin 2>/dev/null || true
    fi
    
    # Fix permissions on pgAdmin directories
    chown -R "$USER_ID:$GROUP_ID" /var/lib/pgadmin 2>/dev/null || true
    chown -R "$USER_ID:$GROUP_ID" /var/log/pgadmin 2>/dev/null || true
    chown "$USER_ID:$GROUP_ID" /pgadmin4/servers.json 2>/dev/null || true
    
    # Ensure the entrypoint script is executable
    chmod +x /entrypoint.sh 2>/dev/null || true
    
    # Stop postfix if it's running (not needed for AIXCL)
    if [ -f /usr/libexec/postfix/master ]; then
        echo "Stopping postfix (not required for AIXCL)..."
        # Kill postfix master process if running
        pkill -f "postfix/master" 2>/dev/null || true
    fi
    
    echo "Switching to pgadmin user (UID: $USER_ID)..."
    
    # Export environment variables for the pgadmin user
    export PGADMIN_DEFAULT_EMAIL
    export PGADMIN_DEFAULT_PASSWORD
    export PGADMIN_LISTEN_PORT
    export PGADMIN_LISTEN_ADDRESS
    export PGADMIN_SERVER_JSON_FILE
    export PGADMIN_REPLACE_SERVERS_ON_STARTUP
    
    # Re-run this script as the non-root user
    exec su -s /bin/bash pgadmin -c 'exec /usr/local/bin/pgadmin-entrypoint.sh'
fi

# At this point, we should be running as non-root
echo "Running as user: $(id -u):$(id -g)"

# Verify we can access the pgAdmin directories
if [ -w "/var/lib/pgadmin" ]; then
    echo "✅ pgAdmin directories are writable"
else
    echo "⚠️  Warning: pgAdmin directories may not be writable"
fi

# Start pgAdmin with the official entrypoint
echo "🚀 Starting pgAdmin..."
exec /entrypoint.sh