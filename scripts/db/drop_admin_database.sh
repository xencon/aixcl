#!/bin/bash
# Script to drop the admin database after migration to webui
# Usage: ./scripts/db/drop_admin_database.sh
# WARNING: This will permanently delete the admin database and all its data!

set -e

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
ADMIN_DATABASE=${ADMIN_DATABASE:-admin}

echo "=== Drop Admin Database ==="
echo "PostgreSQL User: $POSTGRES_USER"
echo "Database to drop: $ADMIN_DATABASE"
echo ""
echo "⚠️  WARNING: This will PERMANENTLY DELETE the admin database and all its data!"
echo ""

# Check if postgres container is running
if ! docker ps --format "{{.Names}}" | grep -q "^postgres$"; then
    echo "❌ PostgreSQL container is not running"
    echo "Please start PostgreSQL first with: ./aixcl service start postgres"
    exit 1
fi

# Check if admin database exists
echo "=== Step 1: Checking if admin database exists ==="
DB_EXISTS=$(docker exec postgres psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -w "$ADMIN_DATABASE" | wc -l || echo "0")

if [ "$DB_EXISTS" -eq "0" ]; then
    echo "ℹ️  Admin database does not exist. Nothing to drop."
    exit 0
fi

echo "✅ Admin database exists"

# Check if webui database exists
echo ""
echo "=== Step 2: Verifying webui database exists ==="
WEBUI_EXISTS=$(docker exec postgres psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -w "webui" | wc -l || echo "0")

if [ "$WEBUI_EXISTS" -eq "0" ]; then
    echo "❌ WebUI database does not exist!"
    echo "   Please create the webui database first with:"
    echo "   ./scripts/db/migrate_admin_to_webui.sh"
    exit 1
fi

echo "✅ WebUI database exists"

# Show database info
echo ""
echo "=== Step 3: Database Information ==="
echo "Admin database tables:"
docker exec postgres psql -U "$POSTGRES_USER" -d "$ADMIN_DATABASE" -c "\dt" 2>/dev/null || echo "  (Unable to list tables)"

echo ""
echo "WebUI database tables:"
docker exec postgres psql -U "$POSTGRES_USER" -d webui -c "\dt" 2>/dev/null || echo "  (Unable to list tables)"

# Final confirmation
echo ""
echo "=== Step 4: Confirmation ==="
echo "⚠️  FINAL WARNING: This action cannot be undone!"
echo ""
read -p "Type 'DROP ADMIN DATABASE' to confirm: " confirm

if [ "$confirm" != "DROP ADMIN DATABASE" ]; then
    echo "Aborted. Database not dropped."
    exit 1
fi

# Disconnect any active connections to admin database
echo ""
echo "=== Step 5: Dropping admin database ==="
echo "Terminating active connections to admin database..."
docker exec postgres psql -U "$POSTGRES_USER" -d postgres -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = '$ADMIN_DATABASE'
  AND pid <> pg_backend_pid();
" 2>/dev/null || true

# Drop the database
echo "Dropping admin database..."
if docker exec postgres psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE \"$ADMIN_DATABASE\";"; then
    echo "✅ Admin database dropped successfully"
else
    echo "❌ Failed to drop admin database"
    exit 1
fi

echo ""
echo "=== Summary ==="
echo "✅ Admin database has been dropped"
echo "✅ WebUI database remains intact"
echo ""
echo "Migration complete!"
