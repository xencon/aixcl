-- Migration: Create chat table for storing conversations
-- This table supports both Open WebUI and Continue plugin conversations
-- The 'source' field distinguishes between 'openwebui' and 'continue' conversations

-- Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS chat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT,
    chat JSONB NOT NULL DEFAULT '{"messages": []}'::jsonb,
    meta JSONB DEFAULT '{}'::jsonb,
    source TEXT DEFAULT 'openwebui',
    created_at BIGINT DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT * 1000),
    updated_at BIGINT DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT * 1000),
    user_id TEXT
);

-- Migrate existing TIMESTAMP columns to BIGINT if they exist
DO $$
BEGIN
    -- Check if created_at is TIMESTAMP and convert to BIGINT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        -- Convert TIMESTAMP to BIGINT (milliseconds since epoch)
        ALTER TABLE chat 
        ALTER COLUMN created_at TYPE BIGINT 
        USING (EXTRACT(EPOCH FROM created_at)::BIGINT * 1000);
        
        -- Set default
        ALTER TABLE chat 
        ALTER COLUMN created_at SET DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT * 1000);
    END IF;
    
    -- Check if updated_at is TIMESTAMP and convert to BIGINT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat' 
        AND column_name = 'updated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        -- Convert TIMESTAMP to BIGINT (milliseconds since epoch)
        ALTER TABLE chat 
        ALTER COLUMN updated_at TYPE BIGINT 
        USING (EXTRACT(EPOCH FROM updated_at)::BIGINT * 1000);
        
        -- Set default
        ALTER TABLE chat 
        ALTER COLUMN updated_at SET DEFAULT (EXTRACT(EPOCH FROM NOW())::BIGINT * 1000);
    END IF;
END $$;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_chat_source ON chat(source);
CREATE INDEX IF NOT EXISTS idx_chat_created_at ON chat(created_at DESC);

-- Convert JSON to JSONB and create GIN index on meta
DO $$
BEGIN
    -- Check if meta column exists and is JSON (not JSONB)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat' 
        AND column_name = 'meta' 
        AND udt_name = 'json'
    ) THEN
        -- Convert JSON to JSONB
        ALTER TABLE chat ALTER COLUMN meta TYPE JSONB USING meta::jsonb;
    END IF;
    
    -- Create GIN index on meta if it's JSONB (after potential conversion)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'chat' 
        AND column_name = 'meta' 
        AND udt_name = 'jsonb'
    ) THEN
        CREATE INDEX IF NOT EXISTS idx_chat_meta ON chat USING GIN(meta);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_chat_user_id ON chat(user_id) WHERE user_id IS NOT NULL;

-- Create function to automatically update updated_at timestamp (as BIGINT)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_chat_updated_at ON chat;
CREATE TRIGGER update_chat_updated_at
    BEFORE UPDATE ON chat
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

