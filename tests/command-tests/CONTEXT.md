# CONTEXT: tests/command-tests/

Ordered integration tests for `./aixcl` CLI commands. Files are numbered and
MUST run in sequence -- stack state carries forward between tests.

## Execution Order

| File | What it does | Requires |
|------|-------------|---------|
| `test-00-preflight.sh` | Environment check, prerequisites | Nothing (safe to run standalone) |
| `test-01-stack-token-reload.sh` | Vault token reload behaviour | Nothing (safe to run standalone) |
| `test-02-stack-start.sh` | Starts the full platform stack | Passing preflight |
| `test-03-stack-status.sh` | Validates stack health | Running stack |
| `test-04-engine-set-ollama.sh` | Sets engine to Ollama | Running stack |
| `test-05-engine-auto.sh` | Engine auto-detection | Running stack |
| `test-06-models-add-ollama.sh` | Adds a model via Ollama | Ollama engine active |
| `test-07-models-list.sh` | Lists available models | Models added |
| `test-08-service-restart.sh` | Service restart behaviour | Running stack |
| `test-99-stack-stop.sh` | Stops the stack, cleanup | Running stack |

## Running Tests

Always run via the top-level runner, not individual files:

```bash
tests/run-tests.sh
```

Running individual test files standalone will fail unless the stack is already
in the expected state from prior tests.

## Agent Guidance

**You MAY:**
- Add new test files following the numbered naming convention
- Use the test framework from `tests/lib/test-framework.sh`

**You MUST NOT:**
- Run individual test files standalone expecting them to work in isolation
  (except `test-00-preflight.sh`)
- Change test numbering in a way that breaks the dependency order

## Cross-References

- `tests/lib/test-framework.sh` -- assertion helpers, must source at top of every test
- `tests/lib/state-capture.sh` -- before/after state diffing
- `tests/lib/cleanup.sh` -- cleanup utilities
- `tests/run-tests.sh` -- top-level runner (use this)
- `lib/aixcl/commands/` -- the commands being tested
