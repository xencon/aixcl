-- Mark all Open WebUI migrations up to 006 as complete
-- This is a more aggressive fix when migrations are failing due to schema mismatches
-- Usage: docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < scripts/db/mark_all_migrations.sql

-- Ensure migration tracking table exists
CREATE TABLE IF NOT EXISTS peewee_migrate_history (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    migrated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Mark all migrations from 001 to 006 as complete
-- These correspond to the initial schema setup
INSERT INTO peewee_migrate_history (name, migrated_at) VALUES
('001_initial_schema', CURRENT_TIMESTAMP),
('002_add_local_sharing', CURRENT_TIMESTAMP),
('003_add_auth_api_key', CURRENT_TIMESTAMP),
('004_add_archived', CURRENT_TIMESTAMP),
('005_add_updated_at', CURRENT_TIMESTAMP),
('006_migrate_timestamps_and_charfields', CURRENT_TIMESTAMP)
ON CONFLICT (name) DO UPDATE SET migrated_at = CURRENT_TIMESTAMP;

-- Show what was marked
SELECT id, name, migrated_at 
FROM peewee_migrate_history 
ORDER BY id;

