# AIXCL Platform Test Suite

Comprehensive test suite for validating AIXCL CLI commands against a real installation.

## Overview

This test suite executes actual `./aixcl` commands and validates system state changes. It's designed for developers to verify that the README Quick Start workflow works correctly before releasing.

## Design Principles

- **Real Commands**: Execute actual `./aixcl` commands (not mocked)
- **State Validation**: Verify `.env`, containers, and configs after commands
- **Sequential Execution**: Tests run one at a time, stop on first failure
- **Complete Cleanup**: Each test restores system state after running
- **Single Report**: `test-results.md` is overwritten each run

## Test Structure

```
tests/
+-- run-tests.sh              # Main test runner (entry point)
+-- test-results.md           # Generated report (OVERWRITTEN)
+-- lib/
|   +-- test-framework.sh     # Assertions and utilities
|   +-- state-capture.sh      # State management
|   `-- cleanup.sh            # Cleanup utilities
+-- command-tests/            # Individual CLI command tests
|   +-- test-00-preflight.sh
|   +-- test-00a-stack-token-reload.sh
|   +-- test-01-stack-start.sh
|   +-- test-02-stack-status.sh
|   +-- test-03-engine-set-ollama.sh
|   +-- test-04-engine-set-vllm.sh
|   +-- test-05-engine-set-llamacpp.sh
|   +-- test-06-engine-auto.sh
|   +-- test-07-models-add-ollama.sh
|   +-- test-08-models-add-vllm.sh
|   +-- test-09-models-add-llamacpp.sh
|   +-- test-10-models-list.sh
|   +-- test-11-service-restart.sh
|   +-- test-13-opencode-prompts.sh
|   +-- test-14-opencode-vllm.sh
|   +-- test-15-opencode-llamacpp.sh
|   +-- test-16-engine-model-integration.sh
|   `-- test-99-stack-stop.sh
`-- workflow-tests/
    `-- test-readme-quickstart.sh
```

## Quick Start

```bash
# Run all tests
./tests/run-tests.sh

# Run specific test category
./tests/run-tests.sh --category command
./tests/run-tests.sh --category workflow

# Run specific test
./tests/run-tests.sh --test test-03-engine-set-ollama.sh

# Dry run (show what would execute)
./tests/run-tests.sh --dry-run

# Skip slow tests (model downloads)
./tests/run-tests.sh --quick

# Show help
./tests/run-tests.sh --help
```

## Test Categories

### Command Tests (`command-tests/`)

Validate individual CLI commands:

| Test | Command | Description |
|------|---------|-------------|
| test-00-preflight | `utils check-env` | Environment validation |
| test-00a-stack-token-reload | `stack start` | Vault token reload after stack restart |
| test-01-stack-start | `stack start --profile sys` | Start full stack |
| test-02-stack-status | `stack status` | Check service status |
| test-03-engine-set-ollama | `engine set ollama` | Set ollama engine |
| test-04-engine-set-vllm | `engine set vllm` | Set vLLM engine (GPU only) |
| test-05-engine-set-llamacpp | `engine set llamacpp` | Set llama.cpp engine |
| test-06-engine-auto | `engine auto` | Auto-detect engine |
| test-07-models-add-ollama | `models add qwen2.5-coder:0.5b` | Add ollama model |
| test-08-models-add-vllm | `models add Qwen/...` | Add vLLM model (GPU only) |
| test-09-models-add-llamacpp | `models add .../q4_k_m.gguf` | Add GGUF model |
| test-10-models-list | `models list` | List installed models |
| test-11-service-restart | `service restart ollama` | Restart a service |
| test-13-opencode-prompts | `opencode` | OpenCode prompt integration |
| test-14-opencode-vllm | `opencode` | OpenCode with vLLM engine |
| test-15-opencode-llamacpp | `opencode` | OpenCode with llama.cpp engine |
| test-16-engine-model-integration | `engine` + `models` | Engine and model integration |
| test-99-stack-stop | `stack stop` | Stop all services |

### Workflow Tests (`workflow-tests/`)

Validate complete user workflows:

| Test | Description |
|------|-------------|
| test-readme-quickstart.sh | README Steps 1-5: Clone -> Start -> Engine -> Model -> OpenCode |

## Test Results

After each run, `tests/test-results.md` is generated with:

- Test summary (passed/failed/skipped counts)
- Detailed results table
- Duration for each test
- Status of each assertion

The file is **overwritten** on each run.

## State Management

Each test:

1. **Captures state** before running (`.env`, `opencode.json`, running containers)
2. **Executes commands** and validates assertions
3. **Restores state** after completion (even on failure)

Backups are stored in `tests/.backup/` (gitignored, cleaned up automatically).

## Writing New Tests

### Template

```bash
#!/usr/bin/env bash
# Test XX: Description

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"

log_test_start "test-xx-name"

# Capture state
BACKUP_DIR=$(capture_state "test-xx-name")
export BACKUP_DIR

# Cleanup on exit
cleanup() {
    source "${SCRIPT_DIR}/tests/lib/cleanup.sh"
    restore_state "$BACKUP_DIR"
}
trap cleanup EXIT

# Your test assertions here
assert_command_success "${SCRIPT_DIR}/aixcl command" "Description"
assert_env_equals "VAR_NAME" "expected_value"
assert_container_running "container-name"

log_test_pass "Test completed successfully"
```

### Available Assertions

- `assert_command_success "cmd" "desc"` - Command exits 0
- `assert_command_fail "cmd" "desc"` - Command exits non-zero
- `assert_file_exists "path"` - File exists
- `assert_file_contains "file" "pattern"` - File contains pattern
- `assert_env_equals "VAR" "value"` - Environment variable equals
- `assert_container_running "name"` - Container is running
- `assert_container_healthy "name"` - Container health check passes
- `assert_api_responds "url" [timeout]` - API responds

### Auto-Skip Tests

Skip tests conditionally:

```bash
if ! has_nvidia_gpu; then
    log_test_skip "No GPU - vLLM requires GPU"
    exit 0
fi
```

## Requirements

- Docker and Docker Compose installed
- AIXCL repository cloned and `./aixcl` available
- `bc` (basic calculator) for timing
- `ss` for port checking
- At least 8GB RAM, 10GB disk space
- For model tests: internet connection for downloads

## Troubleshooting

### Tests Fail Immediately

Run pre-flight check:
```bash
./aixcl utils check-env
```

### Port Conflicts

Ensure ports 11434, 5432, 8080, etc. are not in use:
```bash
sudo ss -tulpn | grep -E '11434|5432|8080'
```

### Cleanup After Failed Test

Manual cleanup:
```bash
./aixcl stack stop
docker system prune -f
rm -rf tests/.backup/*
```

### Test Hangs on Model Download

Model downloads can take several minutes. Use `--quick` to skip:
```bash
./tests/run-tests.sh --quick
```

## Notes

- Tests run **sequentially** to avoid conflicts
- First failure stops the entire suite
- vLLM tests auto-skip if no NVIDIA GPU detected
- Each test is independent (starts/stops its own stack)
- Report is Markdown format for easy viewing in GitHub
