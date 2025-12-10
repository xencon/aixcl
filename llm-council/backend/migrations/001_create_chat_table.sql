-- Migration: Create chat table for storing conversations
-- This table supports both Open WebUI and Continue plugin conversations
-- The 'source' field distinguishes between 'openwebui' and 'continue' conversations

CREATE TABLE IF NOT EXISTS chat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT,
    chat JSONB NOT NULL DEFAULT '{"messages": []}'::jsonb,
    meta JSONB DEFAULT '{}'::jsonb,
    source TEXT DEFAULT 'openwebui',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    user_id TEXT
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_chat_source ON chat(source);
CREATE INDEX IF NOT EXISTS idx_chat_created_at ON chat(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_meta ON chat USING GIN(meta);
CREATE INDEX IF NOT EXISTS idx_chat_user_id ON chat(user_id) WHERE user_id IS NOT NULL;

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_chat_updated_at ON chat;
CREATE TRIGGER update_chat_updated_at
    BEFORE UPDATE ON chat
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

