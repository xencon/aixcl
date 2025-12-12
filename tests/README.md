# AIXCL Test Suite

This directory contains comprehensive tests for the AIXCL refactored CLI.

## Test Suites

### 1. Baseline Tests (`test_baseline.sh`)

Tests the basic structure and functionality without requiring services to be running:

- File structure validation
- Command help and validation
- Environment checks
- Error handling
- Library function tests
- Docker Compose file validation

**Run:**
```bash
bash tests/test_baseline.sh
```

### 2. API Endpoint Tests (`test_api_endpoints.sh`)

Tests all API endpoints when services are running:

- Core services (Ollama, Open WebUI, LLM Council)
- Database services (PostgreSQL, pgAdmin)
- Monitoring services (Prometheus, Grafana, exporters)
- Logging services (Loki, Promtail)
- Continue plugin integration

**Run:**
```bash
bash tests/test_api_endpoints.sh
```

**Note:** This test will skip endpoints for services that aren't running, so it's safe to run even when services are stopped.

### 3. Run All Tests (`run_all_tests.sh`)

Runs all test suites in sequence:

```bash
bash tests/run_all_tests.sh
```

## Test Results

Tests output:
- ✅ **PASS** - Test passed
- ❌ **FAIL** - Test failed
- ⚠️ **SKIP** - Test skipped (usually because a service isn't running)

## Establishing a Baseline

To establish a baseline:

1. **Without services running:**
   ```bash
   bash tests/test_baseline.sh
   ```
   This should pass all tests.

2. **Start services:**
   ```bash
   ./aixcl.sh stack start
   ```

3. **With services running:**
   ```bash
   bash tests/test_api_endpoints.sh
   ```
   This will test all API endpoints.

4. **Full test suite:**
   ```bash
   bash tests/run_all_tests.sh
   ```

## Expected Baseline Results

### Without Services Running:
- ✅ All structure/file checks pass
- ✅ All command validation passes
- ✅ Environment check works
- ✅ Error handling works correctly
- ⚠️ API tests skip (services not running)

### With Services Running:
- ✅ All baseline tests pass
- ✅ All API endpoints respond correctly
- ✅ Continue plugin integration works
- ✅ Database persistence works

## Troubleshooting

If tests fail:

1. **Check file permissions:**
   ```bash
   chmod +x aixcl.sh cli/*.sh lib/*.sh tests/*.sh
   ```

2. **Verify Docker is running:**
   ```bash
   docker info
   ```

3. **Check script paths:**
   ```bash
   ls -la aixcl.sh cli/ lib/ services/
   ```

4. **Run individual test sections:**
   The test scripts are modular - you can comment out sections to isolate issues.

## Adding New Tests

When adding new functionality:

1. Add tests to `test_baseline.sh` for command structure
2. Add API tests to `test_api_endpoints.sh` for new endpoints
3. Update this README with new test descriptions
