# Service Contract — Continue

**Category:** Runtime Core  
**Enforcement Level:** Strict

## Purpose
Developer-facing AI interaction layer. Continue is a VS Code extension/plugin that connects to LLM-Council via OpenAI-compatible API for AI-powered code assistance.

## Depends On
- LLM-Council (via API)
- Runtime persistence (for conversation history; provided by LLM-Council)

## Exposes
- VS Code extension interface for AI-powered code assistance
- Developer interaction layer (via Continue plugin in IDE)
- Conversation context management (handled by LLM-Council backend)

## Must Not Depend On
- Monitoring, logging, automation
