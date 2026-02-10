# Council Test Scripts

**Note:** Test scripts have been reorganized by component. See the new structure:

- **Runtime Core Tests**: `tests/runtime-core/` - Tests for Ollama and Council
- **Database Tests**: `tests/database/` - Tests for PostgreSQL connection and persistence
- **API Tests**: `tests/api/` - Tests for Council API endpoints and integration

## New Test Structure

All tests are now organized under `tests/` by component:

### Runtime Core (`tests/runtime-core/`)
- `test_council_members.py` - Verify council models are operational
- `test_performance_user.py` - Performance testing for Ollama optimizations
- `check_models.py` - Check model availability in Ollama
- `run_test.sh` - Wrapper script for performance tests
- `setup_test_env.sh` - Setup virtual environment for tests

See `tests/runtime-core/README.md` for details.

### Database (`tests/database/`)
- `test_db_connection.py` - Database connection and schema tests

See `tests/database/README.md` for details.

### API (`tests/api/`)
- `test_continue_integration.py` - Full Continue plugin → Council → Database flow
- `test_update_config.py` - Configuration update tests
- `test_request.json` - Sample request JSON

See `tests/api/README.md` for details.

## Running Tests

### Via Platform Test Suite (Recommended)
```bash
# Run all tests
./tests/platform-tests.sh

# Run by component
./tests/platform-tests.sh --component runtime-core
./tests/platform-tests.sh --component database
./tests/platform-tests.sh --component api

# Run by profile
./tests/platform-tests.sh --profile dev
```

### Direct Execution
```bash
# Runtime core tests
python3 tests/runtime-core/test_council_members.py
python3 tests/runtime-core/test_performance_user.py

# Database tests
python3 tests/database/test_db_connection.py

# API tests
python3 tests/api/test_continue_integration.py
python3 tests/api/test_update_config.py
```

## Migration Notes

If you have scripts or documentation referencing the old paths:
- `llm-council/scripts/test/test_db_connection.py` → `tests/database/test_db_connection.py`
- `llm-council/scripts/test/test_continue_integration.py` → `tests/api/test_continue_integration.py`
- `llm-council/scripts/test_council_members.py` → `tests/runtime-core/test_council_members.py`
- `llm-council/scripts/test_performance_user.py` → `tests/runtime-core/test_performance_user.py`

All paths in scripts and documentation have been updated accordingly.

