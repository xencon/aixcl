# Test Suite

This directory contains all tests organized by component. Tests are designed to verify functionality, security, and integration of AIXCL components.

## Test Organization

Tests are organized by component:

- **`security/`** - Security tests (network bindings, configuration)
- **`platform-tests.sh`** - Unified platform test suite

## Running Tests

### Platform Test Suite (Recommended)

The platform test suite provides a unified way to run tests:

```bash
# Run all tests
./tests/platform-tests.sh

# Run by component (e.g., api, engine, ui)
./tests/platform-tests.sh --component api

# Run by profile
./tests/platform-tests.sh --profile usr     # Runtime core + PostgreSQL
./tests/platform-tests.sh --profile dev     # Core + database + UI
./tests/platform-tests.sh --profile ops     # Core + monitoring + logging
./tests/platform-tests.sh --profile sys     # All services

# List available test targets
./tests/platform-tests.sh --list
```

## Test Prerequisites

Most tests require:
- Services to be running: `./aixcl stack start`
- Proper environment configuration (`.env` file)

## Test Structure

Test directories typically contain:
- Helper scripts (`.sh` files)
- README.md with usage instructions (if applicable)
- Sample data files (if needed)

