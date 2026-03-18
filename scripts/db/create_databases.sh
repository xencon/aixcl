#!/bin/bash
# Simple script to create webui and continue databases
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
CONTINUE_DATABASE=${POSTGRES_CONTINUE_DATABASE:-continue}

echo "=== Creating Required Databases ==="
echo "PostgreSQL User: $POSTGRES_USER"
echo "WebUI Database: $WEBUI_DATABASE"
echo "Continue Database: $CONTINUE_DATABASE"
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

# Create continue database if it doesn't exist
echo ""
echo "=== Creating Continue Database ==="
if run_psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$CONTINUE_DATABASE"; then
    echo "✅ Continue database already exists: $CONTINUE_DATABASE"
else
    echo "Creating continue database..."
    run_psql -d postgres -c "CREATE DATABASE \"$CONTINUE_DATABASE\";" >/dev/null 2>&1
    echo "✅ Continue database created: $CONTINUE_DATABASE"
    echo "   Note: The Council service will automatically create the schema when it starts."
fi

# Remove unwanted "admin" database if it exists and is not the intended database
# PostgreSQL may create an "admin" database when POSTGRES_USER=admin but POSTGRES_DATABASE is not set
if [ "$WEBUI_DATABASE" != "admin" ] && [ "$CONTINUE_DATABASE" != "admin" ]; then
    echo ""
    echo "=== Cleaning Up Unwanted Databases ==="
    if run_psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "admin"; then
        echo "Removing unwanted admin database..."
        run_psql -d postgres -c "DROP DATABASE IF EXISTS \"admin\";" >/dev/null 2>&1 || true
        echo "✅ Admin database removed (only webui and continue databases should exist)"
    else
        echo "✅ No unwanted admin database found"
    fi
fi

# Verify databases
echo ""
echo "=== Verification ==="
if run_psql -d "$WEBUI_DATABASE" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ WebUI database is accessible"
else
    echo "❌ Failed to access webui database"
    exit 1
fi

if run_psql -d "$CONTINUE_DATABASE" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Continue database is accessible"
else
    echo "❌ Failed to access continue database"
    exit 1
fi

echo ""
echo "✅ All databases created successfully!"
