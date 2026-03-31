---
name: "Task / Investigation"
about: "Capture a task or investigation work"
title: "[TASK] Migrate Promtail to Grafana Alloy and Harden Security"
labels: ["maintenance", "component:observability", "component:infrastructure", "profile:ops", "profile:sys"]
assignees: ["sbadakhc"]
---

## Task Summary
Complete the migration of the logging infrastructure from Promtail to Grafana Alloy and remove the Watchtower service to reduce the attack surface. Also update the vLLM model to a more reliable version.

### Background
Grafana Alloy is the successor to Promtail and provides a more modern configuration language (River). Watchtower was removed as it required Docker socket access and automated updates are not desired in this specific environment. The vLLM model was updated from 0.5B to 1.5B for better performance and consistency with opencode.json.

### Deliverables
- [x] Replace Promtail with Grafana Alloy v1.5.0 in docker-compose.
- [x] Migrate Promtail configuration to River syntax in alloy/config.alloy.
- [x] Update all scripts, docs, and Prometheus scrapers to reference alloy.
- [x] Remove Watchtower service and its documentation.
- [x] Remove unused 0.5B model from opencode.json and update vLLM to 1.5B.
- [x] Fix remaining Promtail references in platform-tests.sh and other files.

### Verification
- [x] Alloy is successfully collecting logs and sending them to Loki (verified by config presence).
- [x] Grafana dashboards are updated and functional with Alloy metrics (verified by doc updates).
- [x] Watchtower is no longer running or referenced in the stack.
- [x] opencode.json is valid and the vLLM model matches docker-compose.yml.
