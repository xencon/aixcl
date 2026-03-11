# Test Suite

This directory contains all tests organized by component. Tests are designed to verify functionality, performance, and integration of AIXCL components.

## Test Organization

Tests are organized by component:

- **`runtime-core/`** - Tests for Ollama runtime components
- **`database/`** - Tests for PostgreSQL database connection and persistence
- **`monitoring/`** - Tests for monitoring components (Prometheus, Grafana)
- **`logging/`** - Tests for logging components (Loki, Promtail)
- **`ui/`** - Tests for UI components (Open WebUI)
- **`automation/`** - Tests for automation components (Watchtower)

## Running Tests

### Platform Test Suite (Recommended)

The platform test suite provides a unified way to run tests:

```bash
# Run all tests
./tests/platform-tests.sh

# Run by component
./tests/platform-tests.sh --component runtime-core
./tests/platform-tests.sh --component database

# Run by profile
./tests/platform-tests.sh --profile usr     # Runtime core + PostgreSQL
./tests/platform-tests.sh --profile dev     # Core + database + UI
./tests/platform-tests.sh --profile ops     # Core + monitoring + logging
./tests/platform-tests.sh --profile sys     # All services

# List available test targets
./tests/platform-tests.sh --list
```

### Component-Specific Tests

Each component directory contains its own README with detailed instructions:

- [`runtime-core/README.md`](runtime-core/README.md) - Runtime core tests
- [`database/README.md`](database/README.md) - Database tests

### Direct Execution

You can also run tests directly:

```bash
# Database tests
python3 tests/database/test_db_connection.py
```

## Test Prerequisites

Most tests require:
- Services to be running: `./aixcl stack start`
- Python dependencies installed (see individual component READMEs)
- Proper environment configuration (`.env` file)

## Test Structure

Each component test directory typically contains:
- Test scripts (`.py` files)
- Helper scripts (`.sh` files)
- README.md with usage instructions
- Sample data files (if needed)

