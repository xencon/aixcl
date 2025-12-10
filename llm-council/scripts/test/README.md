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

# 5. Test inside container (optional)
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

