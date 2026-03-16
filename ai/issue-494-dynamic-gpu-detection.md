---
name: "Task / Investigation"
about: "Patch platform tests and expand engine coverage"
title: "[TASK] Patch platform tests for multi-engine support and cleanup"
labels: ["maintenance", "tests", "component:runtime-core"]
assignees: ["sbadakhc"]
---

## Task Summary
Refine the platform testing suite to be backend-agnostic and remove deprecated components following the LLM Council extraction.

### Background
Platform tests were failing due to hardcoded dependencies on `ollama` and references to the removed `Council` service. Additionally, the database connection test script was missing.

### Deliverables
- [x] Patch `platform-tests.sh` to support dynamic `INFERENCE_ENGINE` (vLLM, llama.cpp, Ollama)
- [x] Implement dynamic model listing in `get_available_models`
- [x] Remove legacy `test_conversation_storage` and `test_database_connection`
- [x] Ensure 30/30 tests pass on the `sys` profile with `vllm`
- [x] Implement conditional skipping for inactive engines

### Verification
- [x] Verified full system profile passes with 30 successes.
- [x] Verified individual component tests for `runtime-core` show correct skips for inactive engines.
