-- Fix script for Open WebUI peewee migration issues
-- This creates the migration tracking table and marks completed migrations
-- Usage: docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < scripts/db/fix_peewee_migrations.sql

-- Create migration tracking table if it doesn't exist
CREATE TABLE IF NOT EXISTS peewee_migrate_history (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    migrated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Mark migrations as complete based on existing schema
-- Migration 001: initial_schema (if chat table exists)
INSERT INTO peewee_migrate_history (name, migrated_at)
SELECT '001_initial_schema', CURRENT_TIMESTAMP
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'chat')
ON CONFLICT (name) DO NOTHING;

-- Migration 002: add_local_sharing (if share_id column exists)
INSERT INTO peewee_migrate_history (name, migrated_at)
SELECT '002_add_local_sharing', CURRENT_TIMESTAMP
WHERE EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat' AND column_name = 'share_id'
)
ON CONFLICT (name) DO NOTHING;

-- Migration 004: add_archived (if archived column exists)
INSERT INTO peewee_migrate_history (name, migrated_at)
SELECT '004_add_archived', CURRENT_TIMESTAMP
WHERE EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat' AND column_name = 'archived'
)
ON CONFLICT (name) DO NOTHING;

-- Migration 005: add_updated_at (if created_at and updated_at columns exist)
INSERT INTO peewee_migrate_history (name, migrated_at)
SELECT '005_add_updated_at', CURRENT_TIMESTAMP
WHERE EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat' AND column_name = 'created_at'
) AND EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'chat' AND column_name = 'updated_at'
)
ON CONFLICT (name) DO NOTHING;

-- Show current migration state
SELECT id, name, migrated_at 
FROM peewee_migrate_history 
ORDER BY id;

