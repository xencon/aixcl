#!/bin/bash
# Quick check script for Continue conversations in the database
# Usage: ./scripts/db/check_db.sh
# Note: Requires POSTGRES_USER and POSTGRES_DATABASE environment variables
#       or edit this script with your database credentials

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
POSTGRES_DATABASE=${POSTGRES_DATABASE:-webui}

docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" -c "SELECT id, title, source FROM chat WHERE source = 'continue' ORDER BY created_at DESC LIMIT 3;"

