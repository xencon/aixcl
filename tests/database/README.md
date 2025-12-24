# Database Tests

Tests for PostgreSQL database connection, schema, and persistence functionality.

## Test Scripts

### `test_db_connection.py`
Comprehensive Python test script that verifies:
- Database connection pool creation
- Schema verification and creation
- Conversation creation and retrieval
- Message addition to conversations
- Conversation listing
- Conversation deletion

**Usage:**
```bash
# From project root
python3 tests/database/test_db_connection.py

# Or from llm-council directory with uv
cd llm-council
uv run python ../tests/database/test_db_connection.py
```

**Prerequisites:**
- PostgreSQL service must be running
- Environment variables must be set (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DATABASE, etc.)
- Can be run from host or inside container
- `asyncpg` Python package installed (installed automatically if using uv)

## Running Database Tests

```bash
# Via platform test suite
./tests/platform-tests.sh --component database

# Or directly
python3 tests/database/test_db_connection.py
```

## Test Coverage

The database tests verify:
1. **Connection**: Database connection pool creation and health
2. **Schema**: Table creation and structure verification
3. **CRUD Operations**: Create, read, update, delete conversations
4. **Message Persistence**: Adding and retrieving messages
5. **Data Integrity**: Proper foreign key relationships and constraints

