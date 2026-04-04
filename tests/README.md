# AIXCL Test Suite

This directory contains all tests organized by type.

## Structure

```
tests/
├── README.md                      # This file
├── integration/                   # Integration tests for full stack
│   └── platform-tests.sh          # Platform test suite
└── security/                      # Security tests
    ├── test_network_bindings.sh   # Network binding security
    └── test_openwebui_json.sh     # Open WebUI configuration security
```

## Test Categories

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
# Run security tests
./tests/security/*.sh

# Run integration tests (requires services to be running)
./tests/integration/platform-tests.sh
```

## Writing New Tests

### Integration Tests
- Test component interactions
- May require running services
- Use platform-tests.sh framework

### Security Tests
- Focus on security boundaries
- Verify container isolation
- Check configuration files
