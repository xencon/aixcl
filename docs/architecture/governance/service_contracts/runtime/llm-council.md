# Service Contract — LLM-Council

**Category:** Runtime Core  
**Enforcement Level:** Strict

## Purpose
Coordinates inference requests and orchestrates model calls.

## Depends On
- Runtime core (Ollama)
- Runtime persistence (for Continue conversation storage; may be file-based or database; may use the same database instance as operational services, e.g. PostgreSQL)

## Exposes
- Aggregated inference results
- Plugin interface to Continue

## Must Not Depend On
- Operational services (monitoring, logging, UI, automation). Using a shared database for runtime persistence does not violate this; the boundary prohibits dependency on operational *capabilities*, not on the persistence technology.
