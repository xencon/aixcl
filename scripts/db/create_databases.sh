#!/bin/bash
# Simple script to create webui and opencode databases
# Usage: ./scripts/db/create_databases.sh

set -e

# Load environment variables if .env exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/.env"
    set +a
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}
WEBUI_DATABASE=${POSTGRES_DATABASE:-webui}

echo "=== Creating Required Databases ==="
echo "PostgreSQL User: $POSTGRES_USER"
echo "WebUI Database: $WEBUI_DATABASE"
echo ""

# Check if postgres container is running
if ! docker ps --format "{{.Names}}" | grep -q "^postgres$"; then
    echo "❌ PostgreSQL container is not running"
    echo "Please start PostgreSQL first with: ./aixcl service start postgres"
    exit 1
fi

# Function to execute psql inside the postgres container
run_psql() {
    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" postgres psql -U "$POSTGRES_USER" "$@"
}

# Create webui database if it doesn't exist
echo "=== Creating WebUI Database ==="
if run_psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$WEBUI_DATABASE"; then
    echo "✅ WebUI database already exists: $WEBUI_DATABASE"
else
    echo "Creating webui database..."
    run_psql -d postgres -c "CREATE DATABASE \"$WEBUI_DATABASE\";" >/dev/null 2>&1
    echo "✅ WebUI database created: $WEBUI_DATABASE"
fi

