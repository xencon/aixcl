# CONTEXT: tests/lib/

Shared test framework sourced by every test in the suite, plus the pure
shell unit tests under `tests/lib/tests/`. Run everything through
`./aixcl test <suite>` (fronts `tests/run-tests.sh`).

## Contents

| File | Purpose |
|------|---------|
| `test-framework.sh` | Assertions (`assert_*`), logging (`log_test_*`), result tracking, report generation. Must be sourced at the top of every test. |
| `state-capture.sh` | `capture_state`/`restore_state` -- snapshots `.env`, `opencode.json`, and running containers into `tests/.backup/<name>_<timestamp>/` before a test mutates them. |
| `cleanup.sh` | Container/model cleanup between tests, port-release polling, `cleanup_old_backups`. |
| `tests/test-*.sh` | Unit tests for `lib/` shell functions -- no running stack required. |

## Key Constraints

- Tests write reports to `/tmp/aixcl-test-results.md`, never into the repo.
- `tests/.backup/` is gitignored, but leftover `test-*` directories BLOCK
  the pre-commit hook (check-generated-files). Clean with:
  `rm -rf tests/.backup/test-*` before committing.
- `capture_state` names must match the calling test's filename -- when a
  test is renamed, update both `log_test_start` and `capture_state` labels.
- `test-framework.sh` overwrites `SCRIPT_DIR` when sourced; callers that
  need their own value must save and restore it.
- Sequential execution is assumed: tests share the stack and port 11434.

## Agent Guidance

**You MAY:**
- Add assertions to `test-framework.sh` (export them at the bottom)
- Add unit tests under `tests/lib/tests/` following the numbered convention

**You MUST NOT:**
- Write test output into the repository tree
- Remove the state capture/restore pattern from stack-mutating tests

## Cross-References

- `tests/run-tests.sh` -- discovery and sequential runner (via `./aixcl test`)
- `tests/command-tests/CONTEXT.md` -- ordered integration tests
- `tests/README.md` -- suite overview and writing guide
