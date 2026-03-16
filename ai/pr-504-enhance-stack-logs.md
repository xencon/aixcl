# Pull Request

## Summary
Fixes #504

### Description of Changes
- Added support for the `engine` alias in the `./aixcl stack logs` command, which automatically resolves to the currently active inference engine (Ollama, vLLM, or llama.cpp).
- Improved the `logs()` function to correctly resolve actual container names (handling potential hash prefixes) when fetching logs for all services.
- Updated all help messages and documentation (manpage) to be engine-agnostic and show support for all LLM engines.
- Modernized help messages in `service stop`, `service restart`, and `stack logs` to use the active engine name dynamically.
- Updated `scripts/docker-reset.sh` to use more inclusive terminology (`inference models` instead of `Ollama models`) when warning about data deletion.

### Change Checklist
- [x] Issue referenced in title and description
- [x] Branch is named correctly (`task/504-enhance-stack-logs`)
- [x] Commit messages follow conventional style
- [x] All tests run and pass (Manual verification performed)

### Testing Notes
- Verified `./aixcl stack logs engine` correctly maps to the active engine.
- Verified `./aixcl stack logs` shows logs for all running services, including different engines.
- Verified help messages show appropriate examples.

### Verification
To verify this change is complete:
- [x] `./aixcl stack logs engine` works as expected.
- [x] Help text shows `engine` alias examples.
- [x] Manpage is updated.

### Related Issues
- Closes #504
