#!/bin/bash
# Diagnostic script for Open WebUI database migration issues
# Usage: ./scripts/db/diagnose_migration.sh

set -e

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
POSTGRES_DATABASE=${POSTGRES_DATABASE:-webui}

echo "=== Database Migration Diagnostics ==="
echo "Database: $POSTGRES_DATABASE"
echo "User: $POSTGRES_USER"
echo ""

# Check if postgres container is running
if ! docker ps --format "{{.Names}}" | grep -q "^postgres$"; then
    echo "❌ PostgreSQL container is not running"
    exit 1
fi

echo "=== 1. Checking chat table structure ==="
docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" -c "\d chat" || echo "Chat table does not exist"

echo ""
echo "=== 2. Checking for peewee_migrate_history table ==="
docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" -c "\d peewee_migrate_history" 2>/dev/null || echo "peewee_migrate_history table does not exist"

echo ""
echo "=== 3. Listing completed migrations (if peewee_migrate_history exists) ==="
docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" -c "SELECT * FROM peewee_migrate_history ORDER BY id;" 2>/dev/null || echo "Cannot query migration history"

echo ""
echo "=== 4. Checking chat table columns ==="
docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" -c "
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'chat' 
ORDER BY ordinal_position;
" 2>/dev/null || echo "Cannot query chat table columns"

echo ""
echo "=== 5. Checking for created_at column specifically ==="
docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" -c "
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'chat' AND column_name = 'created_at';
" 2>/dev/null | grep -q "created_at" && echo "✅ created_at column exists" || echo "❌ created_at column does not exist"

echo ""
echo "=== Diagnostics complete ==="

