# Service Contract — Continue

**Category:** Runtime Core  
**Enforcement Level:** Strict

## Purpose
Developer-facing AI interaction layer. Continue is a VS Code extension/plugin that connects to the Inference Engine via OpenAI-compatible API for AI-powered code assistance.

## Depends On
- Inference Engine (via API)

## Exposes
- VS Code extension interface for AI-powered code assistance
- Developer interaction layer (via Continue plugin in IDE)

## Must Not Depend On
- Monitoring, logging, automation
