# Testing PostgreSQL Integration for Continue Conversations

This guide explains how to test the PostgreSQL integration for Continue plugin conversations.

## Prerequisites

1. Services must be running: `./aixcl start`
2. PostgreSQL must be accessible
3. Environment variables must be set in `.env`:
   - `POSTGRES_USER`
   - `POSTGRES_PASSWORD`
   - `POSTGRES_DATABASE`
   - `ENABLE_DB_STORAGE=true` (default)

## Testing Methods

### Method 1: API Testing (Recommended)

Test the API endpoints directly:

```bash
# 1. Start services
./aixcl start

# 2. Wait for services to be ready (about 30 seconds)
sleep 30

# 3. Run API test script (if available)
# Note: API tests are now in tests/api/
python3 tests/api/test_continue_integration.py
```

### Method 2: Database Connection Test

Test the database connection and operations:

```bash
# 1. Start services
./aixcl start

# 2. Wait for services to be ready
sleep 30

# 3. Run database test
python3 tests/database/test_db_connection.py

# Or via platform test suite
./tests/platform-tests.sh --component database
```

### Method 3: Manual API Testing with curl

Test the chat completions endpoint:

```bash
# Send a test message (simulating Continue plugin)
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "council",
    "messages": [
      {"role": "user", "content": "Hello, test message"}
    ],
    "stream": false
  }'

# Check the database for stored conversation
docker exec postgres psql -U webui -d webui -c "SELECT id, title, source, created_at FROM chat WHERE source = 'continue' LIMIT 5;"
```

### Method 4: Test Deletion

Test the deletion endpoint:

```bash
# First, get a conversation ID from the database
CONV_ID=$(docker exec postgres psql -U webui -d webui -t -c "SELECT id FROM chat WHERE source = 'continue' LIMIT 1;" | tr -d ' ')

# Delete the conversation
curl -X DELETE http://localhost:8000/v1/chat/completions/$CONV_ID

# Verify deletion
docker exec postgres psql -U webui -d webui -c "SELECT COUNT(*) FROM chat WHERE id = '$CONV_ID';"
```

## Verification Steps

1. **Check Database Schema**: Verify the chat table exists with the correct structure
   ```bash
   docker exec postgres psql -U webui -d webui -c "\d chat"
   ```

2. **Check Stored Conversations**: View Continue conversations in the database
   ```bash
   docker exec postgres psql -U webui -d webui -c "SELECT id, title, source, jsonb_array_length(chat->'messages') as message_count, created_at FROM chat WHERE source = 'continue' ORDER BY created_at DESC LIMIT 10;"
   ```

3. **Check Logs**: View LLM-Council logs for database connection messages
   ```bash
   docker logs llm-council | grep -i "database\|postgres\|conversation"
   ```

## Expected Results

- ✅ Database connection pool created successfully
- ✅ Schema verified/created automatically
- ✅ Conversations saved with `source='continue'`
- ✅ Messages stored in JSONB format with stage data
- ✅ Deletion endpoint removes conversations
- ✅ Conversation IDs generated from message hash

## Troubleshooting

### Database Connection Failed
- Check PostgreSQL is running: `docker ps | grep postgres`
- Verify environment variables: `docker exec llm-council env | grep POSTGRES`
- Check database logs: `docker logs postgres`

### Conversations Not Saving
- Verify `ENABLE_DB_STORAGE=true` in environment
- Check LLM-Council logs for errors: `docker logs llm-council`
- Verify database permissions

### Schema Not Created
- Check migration file exists: `ls llm-council/backend/migrations/`
- Manually run migration if needed:
  ```bash
  docker exec -i postgres psql -U webui -d webui < llm-council/backend/migrations/001_create_chat_table.sql
  ```

