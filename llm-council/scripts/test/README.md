# LLM-Council Test Scripts

This directory contains test scripts for verifying the LLM-Council service functionality, particularly the PostgreSQL persistence features.

## Test Scripts

### `test_db_connection.py`
Comprehensive Python test script that verifies:
- Database connection pool creation
- Schema verification and creation
- Conversation creation and retrieval
- Message addition to conversations
- Conversation listing
- Conversation deletion

**Usage (from host):**
```bash
cd llm-council
python3 scripts/test/test_db_connection.py
```

**Prerequisites:**
- PostgreSQL service must be running
- Environment variables must be set (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DATABASE, etc.)
- Can be run from host or inside container

### `test_db_in_container.sh`
Wrapper script to run database tests inside the Docker container.

**Usage:**
```bash
docker exec -it llm-council bash scripts/test/test_db_in_container.sh
```

**Note:** This script checks if it's running inside a container and provides helpful error messages if run from the host.

### `test_api.sh`
Integration test script that tests the LLM-Council API endpoints:
- Health check endpoint
- Chat completion endpoint (simulating Continue plugin)
- Conversation persistence verification
- Conversation continuity (multiple messages)
- Conversation deletion endpoint

**Usage:**
```bash
./llm-council/scripts/test/test_api.sh
```

**Prerequisites:**
- LLM-Council service must be running on `http://localhost:8000`
- PostgreSQL service must be running
- `curl` must be installed

### `test_continue_integration.py`
Comprehensive integration test for the full Continue plugin → LLM Council → Database flow:
- Simulates Continue plugin requests (OpenAI-compatible format)
- Verifies LLM Council API responses
- Verifies conversation storage in PostgreSQL
- Verifies conversation structure includes stage data (stage1, stage2, stage3)
- Tests conversation continuity (follow-up messages)
- Tests conversation listing

**Usage:**
```bash
# Recommended: Using uv (ensures correct environment)
cd llm-council
uv sync  # Install dependencies if not already done
uv run python scripts/test/test_continue_integration.py

# Alternative: Direct Python (requires httpx in current environment)
cd llm-council
python3 scripts/test/test_continue_integration.py
```

**Prerequisites:**
- LLM-Council service must be running on `http://localhost:8000`
- PostgreSQL service must be running
- Python dependencies installed (via `uv sync` or `pip install httpx`)
- Environment variables must be set (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DATABASE, etc.)

**Environment Variables:**
- `LLM_COUNCIL_API_URL`: API base URL (default: `http://localhost:8000`)
- `DELETE_TEST_CONVERSATION`: Set to `true` to auto-delete test conversation after test (default: `false`)

**Example:**
```bash
# Run test with custom API URL
LLM_COUNCIL_API_URL=http://localhost:8000 python3 scripts/test/test_continue_integration.py

# Run test and auto-delete test conversation
DELETE_TEST_CONVERSATION=true python3 scripts/test/test_continue_integration.py
```

## Running All Tests

To run all tests in sequence:

```bash
# 1. Start services
./aixcl start

# 2. Wait for services to be ready
sleep 10

# 3. Test database connection (from host)
cd llm-council
python3 scripts/test/test_db_connection.py

# 4. Test API endpoints
./scripts/test/test_api.sh

# 5. Test Continue integration (full flow)
cd llm-council
python3 scripts/test/test_continue_integration.py

# 6. Test inside container (optional)
docker exec -it llm-council bash scripts/test/test_db_in_container.sh
```

## Troubleshooting

### Database Connection Failures
- Verify PostgreSQL is running: `docker ps | grep postgres`
- Check environment variables: `cat .env | grep POSTGRES`
- Test connection manually: `docker exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} -c "SELECT 1;"`

### API Test Failures
- Verify LLM-Council is running: `curl http://localhost:8000/health`
- Check service logs: `docker logs llm-council`
- Verify database is accessible from container

### Path Issues
If you encounter import errors when running `test_db_connection.py`, ensure you're running it from the `llm-council` directory, not from the scripts/test directory.

