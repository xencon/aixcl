#!/bin/bash
# Fix script for Open WebUI peewee migration issues
# This script executes the SQL fix file to mark migrations as complete
# Usage: ./scripts/db/fix_peewee_migration.sh

set -e

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
POSTGRES_DATABASE=${POSTGRES_DATABASE:-webui}

echo "=== Open WebUI Peewee Migration Fix ==="
echo "Database: $POSTGRES_DATABASE"
echo "User: $POSTGRES_USER"
echo ""

# Check if postgres container is running
if ! docker ps --format "{{.Names}}" | grep -q "^postgres$"; then
    echo "❌ PostgreSQL container is not running"
    exit 1
fi

# Check if chat table exists
if ! docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" -c "\d chat" >/dev/null 2>&1; then
    echo "❌ Chat table does not exist. Cannot fix migrations."
    exit 1
fi

echo "✅ Chat table exists"
echo ""
echo "=== Executing migration fix SQL ==="

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SQL_FILE="$SCRIPT_DIR/fix_peewee_migrations.sql"

if [ ! -f "$SQL_FILE" ]; then
    echo "❌ SQL file not found: $SQL_FILE"
    exit 1
fi

docker exec -i postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" < "$SQL_FILE"

echo ""
echo "=== Fix complete ==="
echo ""
echo "⚠️  Note: If Open WebUI still fails to start with migration errors,"
echo "   check the logs: ./aixcl logs open-webui"
echo ""
echo "Try starting Open WebUI again: ./aixcl start open-webui"
