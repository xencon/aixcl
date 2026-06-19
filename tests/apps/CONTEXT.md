# CONTEXT: tests/apps/

Test suite for applications built on top of the AIXCL inference platform.
These tests verify the API surface that app code depends on, not the platform
internals (those live in `tests/command-tests/`).

## Purpose

- Validate that the inference API is reachable and responds correctly
- Provide a baseline connectivity test every app can build on
- Establish patterns for app-specific test files

## Test Files

| File | What it tests | Requires |
|------|---------------|----------|
| `test-inference-api.sh` | OpenAI-compatible API connectivity and basic chat completion | Running stack |

## Running

```bash
# All platform + app tests
tests/run-tests.sh

# App tests only
tests/run-tests.sh --category apps
```

Individual test files can be run standalone when the stack is already up:

```bash
bash tests/apps/test-inference-api.sh
```

## Adding Tests for Your App

1. Create `tests/apps/test-<your-app>.sh`
2. Source the test framework at the top
3. Use `assert_command_success` / `assert_output_contains` for assertions
4. Skip gracefully if the stack is not running (see `test-inference-api.sh` for pattern)

## Agent Guidance

**You MAY:**
- Add test files for new app prototypes following the pattern here
- Add helper functions to `tests/lib/` if multiple app tests need them

**You MUST NOT:**
- Assume the stack is running -- skip gracefully if it is not
- Add tests that require network access outside the local platform

## Cross-References

- `tests/lib/test-framework.sh` -- assertion helpers
- `tests/run-tests.sh` -- top-level runner
- `docs/developer/app-builder-guide.md` -- API reference for app builders
