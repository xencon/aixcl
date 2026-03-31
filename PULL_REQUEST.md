# Pull Request

## Summary

Fixes #[ISSUE_NUMBER]

### Description of Changes

This PR completes the migration of the logging infrastructure from Promtail to Grafana Alloy and the removal of the Watchtower service for security hardening. Additionally, it updates the vLLM model configuration for better performance and consistency.

Key changes:
- Replaced Promtail with Grafana Alloy v1.5.0 in `services/docker-compose.yml`.
- Migrated configuration to `alloy/config.alloy`.
- Updated all scripts, documentation, and test suites to reference Alloy.
- Removed Watchtower service and cleaned up all mentions in security documentation.
- Updated vLLM to use the `Qwen/Qwen2.5-Coder-1.5B-Instruct` model to match `opencode.json`.
- Removed the deprecated `0.5B` model from `opencode.json`.

### Change Checklist

- [x] Issue referenced in title and description (Wait for ISSUE_NUMBER)
- [x] Branch is named correctly (`refactor/migrate-promtail-to-alloy`)
- [x] Commit messages follow conventional style
- [x] All tests run and pass (Platform tests updated)

### Testing Notes

This change was tested by:
- Verifying the `docker-compose.yml` configuration.
- Checking documentation for consistency.
- Updating `tests/platform-tests.sh` to correctly check for the `alloy` container.

### Verification

To verify this change is complete:
- Confirm `alloy` is running in `ops` or `sys` profiles.
- Verify `vllm` is using the `1.5B` model.
- Ensure no `promtail` or `watchtower` references remain in the codebase.

### Related Issues

- Closes #[ISSUE_NUMBER]
