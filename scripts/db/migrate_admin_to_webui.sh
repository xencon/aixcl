#!/bin/bash
# Migration script to rename admin database to webui
# This script creates the webui database and optionally migrates data from admin
# Usage: ./scripts/db/migrate_admin_to_webui.sh

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables if .env exists
if [ -f "${SCRIPT_DIR}/.env" ]; then
    export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
OLD_DATABASE=${OLD_DATABASE:-admin}
NEW_DATABASE=${NEW_DATABASE:-webui}
CONTINUE_DATABASE=${POSTGRES_CONTINUE_DATABASE:-continue}

echo "=== Migrating from admin to webui database ==="
echo "PostgreSQL User: $POSTGRES_USER"
echo "Old Database: $OLD_DATABASE"
echo "New Database: $NEW_DATABASE"
echo "Continue Database: $CONTINUE_DATABASE"
echo ""

# Check if postgres container is running
if ! docker ps --format "{{.Names}}" | grep -q "^postgres$"; then
    echo "❌ PostgreSQL container is not running"
    echo "Please start PostgreSQL first with: ./aixcl service start postgres"
    exit 1
fi

# Check if old database exists
echo "=== Step 1: Checking if admin database exists ==="
DB_EXISTS=$(docker exec postgres psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -w "$OLD_DATABASE" | wc -l || echo "0")

if [ "$DB_EXISTS" -eq "0" ]; then
    echo "⚠️  Admin database does not exist. This might be a fresh installation."
    ADMIN_EXISTS=false
else
    echo "✅ Admin database exists"
    ADMIN_EXISTS=true
    
    # Check if admin database has any tables
    TABLE_COUNT=$(docker exec postgres psql -U "$POSTGRES_USER" -d "$OLD_DATABASE" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")
    echo "   Found $TABLE_COUNT tables in admin database"
fi

# Check if new database already exists
echo ""
echo "=== Step 2: Checking if webui database exists ==="
WEBUI_EXISTS=$(docker exec postgres psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -w "$NEW_DATABASE" | wc -l || echo "0")

if [ "$WEBUI_EXISTS" -eq "1" ]; then
    echo "⚠️  WebUI database already exists!"
    read -p "Do you want to continue? This will skip database creation. (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
    echo "✅ Using existing webui database"
else
    echo "Creating webui database..."
    docker exec postgres psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$NEW_DATABASE\";"
    echo "✅ WebUI database created successfully"
fi

# Check if continue database exists
echo ""
echo "=== Step 3: Checking if continue database exists ==="
CONTINUE_EXISTS=$(docker exec postgres psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -w "$CONTINUE_DATABASE" | wc -l || echo "0")

if [ "$CONTINUE_EXISTS" -eq "1" ]; then
    echo "✅ Continue database already exists"
else
    echo "Creating continue database..."
    docker exec postgres psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$CONTINUE_DATABASE\";"
    echo "✅ Continue database created successfully"
    echo "   Note: The LLM Council service will automatically create the schema when it starts."
fi

# If admin database exists and has data, offer to migrate
if [ "$ADMIN_EXISTS" = true ] && [ "$TABLE_COUNT" -gt "0" ]; then
    echo ""
    echo "=== Step 4: Data Migration ==="
    echo "⚠️  Admin database contains data. Open WebUI will handle its own migrations."
    echo "   The webui database will be initialized when Open WebUI starts."
    echo ""
    echo "If you need to migrate existing data, you can:"
    echo "1. Use pg_dump/pg_restore to copy data from admin to webui"
    echo "2. Or let Open WebUI initialize the webui database fresh"
    echo ""
    read -p "Do you want to attempt data migration now? (yes/no): " migrate_confirm
    if [ "$migrate_confirm" = "yes" ]; then
        echo "⚠️  Manual data migration is complex and may cause issues."
        echo "   It's recommended to let Open WebUI initialize the database fresh."
        echo "   If you proceed, ensure you have backups!"
        read -p "Are you sure you want to proceed with manual migration? (yes/no): " final_confirm
        if [ "$final_confirm" = "yes" ]; then
            echo "Migrating data from admin to webui..."
            # Use pg_dump and pg_restore for data migration
            docker exec postgres pg_dump -U "$POSTGRES_USER" -d "$OLD_DATABASE" | docker exec -i postgres psql -U "$POSTGRES_USER" -d "$NEW_DATABASE" || {
                echo "❌ Data migration failed. You may need to manually migrate data."
                echo "   The webui database has been created and can be initialized by Open WebUI."
            }
            echo "✅ Data migration completed"
        else
            echo "Skipping data migration. WebUI database will be initialized by Open WebUI."
        fi
    else
        echo "Skipping data migration. WebUI database will be initialized by Open WebUI."
    fi
fi

echo ""
echo "=== Step 5: Verification ==="
echo "Verifying databases exist and are accessible..."
if docker exec postgres psql -U "$POSTGRES_USER" -d "$NEW_DATABASE" -c "SELECT 1;" >/dev/null 2>&1; then
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
echo "=== Migration Summary ==="
echo "✅ WebUI database created: $NEW_DATABASE"
echo "✅ Continue database created: $CONTINUE_DATABASE"
if [ "$ADMIN_EXISTS" = true ]; then
    echo "⚠️  Admin database still exists: $OLD_DATABASE"
    echo "   You can drop it after verifying everything works with:"
    echo "   ./scripts/db/drop_admin_database.sh"
else
    echo "ℹ️  Admin database did not exist (fresh installation)"
fi
echo ""
echo "Next steps:"
echo "1. Update your .env file: POSTGRES_DATABASE=webui"
echo "2. Restart services: ./aixcl stack restart"
echo "3. Verify services are working: ./aixcl stack status"
echo "4. Run tests: ./tests/platform-tests.sh --component database"
echo "5. After verification, drop admin database: ./scripts/db/drop_admin_database.sh"
