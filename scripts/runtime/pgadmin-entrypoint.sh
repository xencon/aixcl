#!/bin/sh
# PGAdmin Entrypoint Wrapper
# Creates servers.json with correct permissions before starting pgAdmin

# Create the servers.json file with proper permissions
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

chmod 644 /pgadmin4/servers.json
chown pgadmin:root /pgadmin4/servers.json

# Execute the original pgAdmin entrypoint
exec /entrypoint.sh