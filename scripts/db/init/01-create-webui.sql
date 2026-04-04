-- AIXCL PostgreSQL Initialization Script
-- This script runs automatically when PostgreSQL starts for the first time
-- It creates the webui database required by Open WebUI before the container reports as ready
--
-- PostgreSQL runs scripts in /docker-entrypoint-initdb.d/ in alphabetical order
-- Scripts are executed as the postgres superuser

-- Create webui database if it does not exist
-- Using SELECT with conditional execution to make the script idempotent
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'webui') THEN
        CREATE DATABASE webui;
        RAISE NOTICE 'Created webui database';
    ELSE
        RAISE NOTICE 'webui database already exists, skipping creation';
    END IF;
END
$$;
