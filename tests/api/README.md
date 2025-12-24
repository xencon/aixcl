# API Tests

Tests for LLM-Council API endpoints and integration flows.

## Test Scripts

### `test_continue_integration.py`
Comprehensive integration test for the full Continue plugin → LLM Council → Database flow:
- Simulates Continue plugin requests (OpenAI-compatible format)
- Verifies LLM Council API responses
- Verifies conversation storage in PostgreSQL
- Verifies conversation structure includes stage data (stage1, stage2, stage3)
- Tests conversation continuity (follow-up messages)

**Usage:**
```bash
# From project root
python3 tests/api/test_continue_integration.py

# Or from llm-council directory with uv (recommended)
cd llm-council
uv sync
uv run python ../tests/api/test_continue_integration.py
```

**Prerequisites:**
- LLM-Council service must be running on `http://localhost:8000`
- PostgreSQL service must be running
- Council must be configured: `./aixcl council configure`
- `httpx` Python package installed (installed automatically if using uv)

**Environment Variables:**
- `LLM_COUNCIL_API_URL`: Override API URL (default: `http://localhost:8000`)
- `DELETE_TEST_CONVERSATION`: Set to `true` to delete test conversation after test (default: `false`)

### `test_update_config.py`
Test script for updating LLM-Council configuration via the API.

**Usage:**
```bash
python3 tests/api/test_update_config.py
```

**Prerequisites:**
- LLM-Council service must be running
- `requests` Python package installed

### `test_request.json`
Sample request JSON file for testing API endpoints.

## Running API Tests

```bash
# Via platform test suite
./tests/platform-tests.sh --component api

# Or individually
python3 tests/api/test_continue_integration.py
python3 tests/api/test_update_config.py
```

## Test Coverage

The API tests verify:
1. **OpenAI Compatibility**: API accepts OpenAI-compatible requests
2. **Response Format**: Responses match expected structure
3. **Database Integration**: Conversations are persisted correctly
4. **Stage Data**: Council workflow stages are captured
5. **Conversation Continuity**: Follow-up messages maintain context

