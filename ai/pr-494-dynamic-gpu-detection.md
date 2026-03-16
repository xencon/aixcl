# Pull Request: [TASK] Patch platform tests for multi-engine support and cleanup

## Summary
Fixes #494

This PR refactors the platform testing suite to be engine-aware and removes deprecated legacy tests associated with the LLM Council extraction. It ensures the platform can be reliably verified across all supported inference backends.

## Changes
- `tests/platform-tests.sh`:
    - Refactored engine detection to support `vLLM`, `Ollama`, and `llama.cpp` dynamically.
    - Implemented `get_available_models` with multi-engine support.
    - Removed legacy `test_conversation_storage` and `test_database_connection`.
    - Added conditional skipping for inactive engines in both `test_llm_state` and `test_component_runtime_core`.
- `services/docker-compose.yml`:
    - Updated default vLLM model to `Qwen2.5-1.5B-Instruct` for better performance/compatibility.

### Change Checklist
- [x] Issue referenced in title and description
- [x] Branch is named correctly (`issue-494/dynamic-gpu-detection`)
- [x] Commit messages follow conventional style
- [x] All tests run and pass (30/30 on `sys` profile)

## Testing Notes
Tested using the `sys` profile on a system running `vLLM`.
- Command: `./tests/platform-tests.sh --profile sys`
- Environment: Ubuntu 24.04 (WSL2), Docker, vLLM backend.

## Verification
To verify this change is complete:
- [x] Run `./tests/platform-tests.sh` with any supported engine.
- [x] Confirm that inactive engines are reported as "skipped".
- [x] Confirm that the active engine is fully validated including model listing.

### Related Issues
- Closes #494 (partially/related sub-task)
