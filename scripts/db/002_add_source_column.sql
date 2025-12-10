-- Add source column to existing chat table
ALTER TABLE chat ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'openwebui';
CREATE INDEX IF NOT EXISTS idx_chat_source ON chat(source);

