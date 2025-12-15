#!/bin/bash
# Reset Open WebUI database to clean state - removes all tables and migration history
# This allows migrations to run from scratch

# Load environment variables if .env exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Default values if not set
POSTGRES_USER=${POSTGRES_USER:-admin}
POSTGRES_DATABASE=${POSTGRES_DATABASE:-webui}

echo "=== Resetting Open WebUI Database ==="
echo "Database: $POSTGRES_DATABASE"
echo "User: $POSTGRES_USER"
echo ""

# Confirm this will delete all data
read -p "This will DELETE ALL DATA. Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Stopping Open WebUI container..."
docker stop open-webui 2>/dev/null || true

echo ""
echo "Dropping all tables and migration history..."

# Drop all tables in the public schema
docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" << 'SQL'
-- Drop all tables in public schema
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') 
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END $$;

-- Drop all sequences
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public') 
    LOOP
        EXECUTE 'DROP SEQUENCE IF EXISTS public.' || quote_ident(r.sequence_name) || ' CASCADE';
    END LOOP;
END $$;

-- Drop migration history tables if they exist
DROP TABLE IF EXISTS alembic_version CASCADE;
DROP TABLE IF EXISTS peewee_migrate_history CASCADE;
SQL

echo ""
echo "✅ Database reset complete!"
echo ""
echo "You can now restart Open WebUI with: docker start open-webui"
echo "Or restart all services with: ./aixcl restart"

