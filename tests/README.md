# AIXCL Test Suite

This directory contains all tests organized by type.

## Structure

```
tests/
├── README.md                      # This file
├── unit/                          # Unit tests for library functions
│   ├── test_color.sh              # Tests for lib/core/color.sh
│   └── test_common.sh             # Tests for lib/core/common.sh
├── integration/                   # Integration tests for full stack
│   └── platform-tests.sh          # Platform test suite
└── security/                      # Security tests
    ├── test_network_bindings.sh   # Network binding security
    └── test_openwebui_json.sh     # Open WebUI configuration security
```

## Test Categories

### Unit Tests (`unit/`)
Fast, isolated tests for individual library functions.

- **test_color.sh** - Tests color output functions
- **test_common.sh** - Tests common utility functions

Run unit tests:
```bash
./tests/unit/test_color.sh
./tests/unit/test_common.sh
```

### Integration Tests (`integration/`)
Full platform tests that require services to be running.

- **platform-tests.sh** - Comprehensive platform test suite

Run integration tests:
```bash
# Run all platform tests
./tests/integration/platform-tests.sh

# Run by profile
./tests/integration/platform-tests.sh --profile dev
./tests/integration/platform-tests.sh --profile sys
```

### Security Tests (`security/`)
Security-focused tests for configuration and network isolation.

- **test_network_bindings.sh** - Verify container network bindings
- **test_openwebui_json.sh** - Validate Open WebUI security configuration

Run security tests:
```bash
./tests/security/test_network_bindings.sh
./tests/security/test_openwebui_json.sh
```

## Running All Tests

```bash
# Run unit tests only (fast, no services required)
./tests/unit/*.sh

# Run security tests
./tests/security/*.sh

# Run integration tests (requires services to be running)
./tests/integration/platform-tests.sh
```

## Writing New Tests

### Unit Tests
- Test one function at a time
- Mock external dependencies
- Fast execution (< 1 second per test)

### Integration Tests
- Test component interactions
- May require running services
- Use platform-tests.sh framework

### Security Tests
- Focus on security boundaries
- Verify container isolation
- Check configuration files
