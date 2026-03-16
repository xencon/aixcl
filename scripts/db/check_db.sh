#!/bin/bash
# Quick check script for Continue conversations in the database
# Usage: ./scripts/db/check_db.sh
# Note: Requires POSTGRES_USER and POSTGRES_CONTINUE_DATABASE environment variables
#       or edit this script with your database credentials

# Load environment variables if .env exists
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    # shellcheck source=/dev/null
    source .env
    set +a
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
CONTINUE_DATABASE=${POSTGRES_CONTINUE_DATABASE:-continue}

docker exec postgres psql -U "$POSTGRES_USER" -d "$CONTINUE_DATABASE" -c "SELECT id, title, source FROM chat ORDER BY created_at DESC LIMIT 3;"

