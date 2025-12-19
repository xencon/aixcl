#!/bin/bash
# Simple script to create webui and continue databases
# Usage: ./scripts/db/create_databases.sh

set -e

# Load environment variables if .env exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
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

# Create webui database if it doesn't exist
echo "=== Creating WebUI Database ==="
WEBUI_EXISTS=$(docker exec postgres psql -U "$POSTGRES_USER" -lqt 2>/dev/null | cut -d \| -f 1 | grep -w "$WEBUI_DATABASE" | wc -l || echo "0")

if [ "$WEBUI_EXISTS" -eq "1" ]; then
    echo "✅ WebUI database already exists: $WEBUI_DATABASE"
else
    echo "Creating webui database..."
    docker exec postgres psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$WEBUI_DATABASE\";" 2>/dev/null
    echo "✅ WebUI database created: $WEBUI_DATABASE"
fi

# Create continue database if it doesn't exist
echo ""
echo "=== Creating Continue Database ==="
CONTINUE_EXISTS=$(docker exec postgres psql -U "$POSTGRES_USER" -lqt 2>/dev/null | cut -d \| -f 1 | grep -w "$CONTINUE_DATABASE" | wc -l || echo "0")

if [ "$CONTINUE_EXISTS" -eq "1" ]; then
    echo "✅ Continue database already exists: $CONTINUE_DATABASE"
else
    echo "Creating continue database..."
    docker exec postgres psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$CONTINUE_DATABASE\";" 2>/dev/null
    echo "✅ Continue database created: $CONTINUE_DATABASE"
    echo "   Note: The LLM Council service will automatically create the schema when it starts."
fi

# Verify databases
echo ""
echo "=== Verification ==="
if docker exec postgres psql -U "$POSTGRES_USER" -d "$WEBUI_DATABASE" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ WebUI database is accessible"
else
    echo "❌ Failed to access webui database"
    exit 1
fi

if docker exec postgres psql -U "$POSTGRES_USER" -d "$CONTINUE_DATABASE" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Continue database is accessible"
else
    echo "❌ Failed to access continue database"
    exit 1
fi

echo ""
echo "✅ All databases created successfully!"
echo ""
echo "Next steps:"
echo "1. Ensure your .env file has: POSTGRES_DATABASE=webui"
echo "2. Restart services: ./aixcl stack restart"
echo "3. Run tests: bash tests/platform-tests.sh"
