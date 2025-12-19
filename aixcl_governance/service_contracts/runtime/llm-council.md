# Service Contract — LLM-Council

**Category:** Runtime Core  
**Enforcement Level:** Strict

## Purpose
Coordinates inference requests and orchestrates model calls.

## Depends On
- Runtime core (Ollama)
- Runtime persistence (for Continue conversation storage; may be file-based or database)

## Exposes
- Aggregated inference results
- Plugin interface to Continue

## Must Not Depend On
- Operational services
