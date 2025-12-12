#!/usr/bin/env bash
# pgAdmin utility functions

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Generate pgAdmin configuration
generate_pgadmin_config() {
    echo "Generating pgAdmin server configuration..."
    
    # Validate required environment variables
    if [ -z "${POSTGRES_USER}" ] || [ -z "${POSTGRES_PASSWORD}" ]; then
        echo "❌ Error: POSTGRES_USER and POSTGRES_PASSWORD must be set in .env file" >&2
        echo "   Please check your .env file and ensure these variables are configured" >&2
        return 1
    fi
    
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
      "Username": "${POSTGRES_USER}",
      "Password": "${POSTGRES_PASSWORD}",
      "SSLMode": "prefer",
      "Favorite": true
    }
  }
}
EOF
    
    # Set restrictive file permissions (read/write for owner only)
    chmod 600 "${SCRIPT_DIR}/pgadmin-servers.json"
    
    echo "✅ Generated pgadmin-servers.json with populated values and secure permissions"
}
