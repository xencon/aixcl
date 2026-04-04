-- PostgreSQL initialization script for AIXCL
-- Creates the webui database on first container startup
-- This runs automatically before PostgreSQL reports as ready

-- Create webui database if it doesn't exist
-- Using IF NOT EXISTS makes this script idempotent
SELECT 'CREATE DATABASE webui'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'webui')\gexec

-- Grant permissions to the postgres user (adjust if using different user)
-- Note: The database owner will be the user running init (usually postgres)
-- The application user will need appropriate permissions

-- The webui database is now ready before Open WebUI container starts
