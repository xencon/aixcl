# Service Contract — Ollama

**Category:** Runtime Core  
**Enforcement Level:** Strict

## Purpose
Provides LLM inference for AIXCL.

## Depends On
- Host GPU (optional)
- Local filesystem

## Exposes
- Inference API to AIXCL services and plugins (Open WebUI, OpenCode)
- Model management

## Must Not Depend On
- Monitoring, logging, UI, automation
