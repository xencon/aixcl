#!/usr/bin/env bash
# pgAdmin utility functions

# Get script directory (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Generate pgAdmin configuration
generate_pgadmin_config() {
    echo "Generating pgAdmin server configuration..."
    
    # Note: With Vault integration, credentials are dynamic
    # pgAdmin will need to use static bootstrap credentials or Vault-generated credentials
    local pg_user="${POSTGRES_USER:-admin}"
    local pg_pass="${POSTGRES_PASSWORD:-}"
    
    # Remove old file if it exists (may have wrong permissions from container)
    # NOTE: If Podman previously created this as a directory mount point,
    # rmdir the empty directory first, then rm the file.
    if [ -d "${SCRIPT_DIR}/pgadmin-servers.json" ]; then
        rmdir "${SCRIPT_DIR}/pgadmin-servers.json" 2>/dev/null || true
    fi
    rm -f "${SCRIPT_DIR}/pgadmin-servers.json" 2>/dev/null || true
    
    # Create pgadmin-servers.json with populated environment values
    cat > "${SCRIPT_DIR}/pgadmin-servers.json" << EOF
{
  "Servers": {
    "1": {
      "Group": "Servers",
      "Name": "AIXCL",
      "Host": "localhost",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "${pg_user}",
      "Password": "${pg_pass}",
      "SSLMode": "prefer",
      "Favorite": true
    }
  }
}
EOF
    
    # Set file permissions (read/write for owner, read for others - needed for container)
    chmod 644 "${SCRIPT_DIR}/pgadmin-servers.json"
    
    echo "✅ Generated pgadmin-servers.json with populated values and secure permissions"
    echo "   Note: With Vault enabled, use dynamic credentials from './aixcl vault credentials'"
}
