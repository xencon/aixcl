---
name: "Task / Investigation"
about: "Enhance stack logs to support all LLM engines and 'engine' alias"
title: "[TASK] Enhance stack logs to support all LLM engines and 'engine' alias"
labels: ["maintenance"]
assignees: ["sbadakhc"]
---

## Task Summary
Currently, the `./aixcl stack logs` command help message specifically mentions `ollama`, and there is no generic `engine` alias to view logs for the active inference engine. This task aims to unify the logging experience across all supported engines (Ollama, vLLM, llama.cpp).

### Background
The `aixcl` stack supports multiple inference engines via the `INFERENCE_ENGINE` environment variable. While `stack logs <service>` works for any service in `ALL_SERVICES`, the documentation and help messages are biased towards `ollama`. Furthermore, a generic `engine` keyword would make it easier for users to view logs regardless of which engine is currently active. Additionally, utilities like `scripts/docker-reset.sh` should be updated to use engine-agnostic terminology.

### Deliverables
- [x] Add `engine` keyword support to the `logs()` function in `aixcl`.
- [x] Update `stack_cmd` help messages to include examples for other engines or use the active engine dynamically.
- [x] Ensure `logs()` correctly resolves actual container names (handling potential hash prefixes) when showing logs for all services.
- [x] Update `docs/reference/manpage.txt` to reflect the improved logging capabilities.
- [x] Update `scripts/docker-reset.sh` to use engine-agnostic terminology for model volume deletion warnings.

### Verification
- [ ] Run `./aixcl stack logs engine` with different `INFERENCE_ENGINE` settings and verify it shows the correct logs.
- [ ] Run `./aixcl stack help` and verify the updated examples.
- [ ] Run `./aixcl stack logs` and ensure all running services (including non-ollama engines) are shown.
