---
name: "Task / Investigation"
about: "Cleanup AI directory and update vLLM model configuration"
title: "[TASK] Cleanup AI directory and update vLLM model configuration"
labels: ["house keeping", "component:runtime-core"]
assignees: ["sbadakhc"]
---

## Task Summary
Cleanup the `ai/` directory by removing legacy issue and PR documentation that has already been merged or is no longer relevant. Additionally, update the vLLM configuration to use the latest model and enable tool calling.

### Background
- Legacy files like `issue-494` and `pr-494` remain in the `ai/` root, cluttering the workspace.
- vLLM model needs to be updated to `Qwen/Qwen3-Coder-30B-A3B-Instruct`.
- Tool calling flags are required for proper interaction with Continue CLI.

### Deliverables
- [x] Identify and remove legacy markdown files in `ai/`.
- [x] Update `services/docker-compose.yml` with new vLLM command.

### Verification
- [x] `ls ai/` confirms clean directory.
- [x] vLLM container starts with new parameters.
