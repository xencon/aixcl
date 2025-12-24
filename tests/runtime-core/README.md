# Runtime Core Tests

Tests for the runtime core components: Ollama and LLM-Council.

## Test Scripts

### `test_council_members.py`
Verifies all LLM Council members (council models and chairman) are operational.

**Usage:**
```bash
# From project root
python3 tests/runtime-core/test_council_members.py

# Or from llm-council directory with uv
cd llm-council
uv run python ../tests/runtime-core/test_council_members.py
```

**Prerequisites:**
- Services must be running: `./aixcl stack start`
- Council must be configured: `./aixcl council configure`
- `httpx` Python package installed

### `test_council_performance.py`
User-focused performance test for Ollama optimizations. Simulates real user experience by testing the council API from outside the container.

**Usage:**
```bash
# Option 1: Use wrapper script (recommended - auto-setup)
./tests/runtime-core/run_test.sh

# Option 2: Direct execution (requires httpx)
python3 tests/runtime-core/test_council_performance.py

# Option 3: With virtual environment
./tests/runtime-core/setup_test_env.sh
source tests/runtime-core/.venv/bin/activate
python3 tests/runtime-core/test_council_performance.py
```

See `test_council_performance_README.md` for detailed usage instructions.

### `check_models.py`
Checks model availability and operational status in Ollama.

**Usage:**
```bash
python3 tests/runtime-core/check_models.py
```

## Helper Scripts

### `run_test.sh`
Wrapper script that automatically sets up a virtual environment if needed and runs `test_council_performance.py`.

**Usage:**
```bash
./tests/runtime-core/run_test.sh
```

### `setup_test_env.sh`
Sets up a Python virtual environment for running tests.

**Usage:**
```bash
./tests/runtime-core/setup_test_env.sh
source tests/runtime-core/.venv/bin/activate
python3 tests/runtime-core/test_council_performance.py
```

## Running All Runtime Core Tests

```bash
# Via platform test suite
./tests/platform-tests.sh --component runtime-core

# Or individually
python3 tests/runtime-core/test_council_members.py
python3 tests/runtime-core/test_council_performance.py
python3 tests/runtime-core/check_models.py
```

