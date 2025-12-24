# Service Contract — Persistence Stack

**Category:** Operational Services  
**Enforcement Level:** Guided

## Purpose
Provides PostgreSQL database storage for runtime data (Open WebUI conversations, Continue plugin conversations) and operational data. Includes pgAdmin for database administration.

## Depends On
- Runtime core (LLM-Council uses PostgreSQL for conversation storage)
- Open WebUI (uses PostgreSQL for conversation storage)

## Exposes
- PostgreSQL database server (port 5432)
- pgAdmin web interface (port 5050)
- Database endpoints for:
  - Open WebUI conversations
  - Continue plugin conversations
  - LLM-Council data

## Must Not Depend On
- UI logic (pgAdmin is admin tool, not runtime UI)
- Automation logic (Watchtower)
- Monitoring/logging services

## Notes
- **Runtime/Operational Boundary**: PostgreSQL serves both runtime (conversation storage) and operational (admin) purposes. This creates a design tension with the invariant that "runtime core must be runnable without operational services."
- **Resolution**: Runtime core (LLM-Council) may use PostgreSQL if available, but should be able to function with file-based persistence as fallback. The `core` profile should support file-based persistence for true independence.
- **pgAdmin**: Purely operational/admin tooling, never required for runtime.
- **Database Separation**: Continue conversations use a separate database (`continue`) from Open WebUI conversations, maintaining logical separation.
