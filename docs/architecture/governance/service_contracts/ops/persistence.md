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
- **Resolution**: Runtime core (LLM-Council) may use PostgreSQL if available via `ENABLE_DB_STORAGE` environment variable, but can function without it. When `ENABLE_DB_STORAGE=false` or PostgreSQL is unavailable, LLM-Council operates normally but conversations are not persisted. File-based persistence fallback exists in code (`storage.py`) but is not currently automatically enabled when database is unavailable.
- **Current Implementation**: All profiles (`usr`, `dev`, `ops`, `sys`) include PostgreSQL for persistence. The `usr` profile includes PostgreSQL as the minimal operational service for runtime persistence.
- **pgAdmin**: Purely operational/admin tooling, never required for runtime.
- **Database Separation**: Continue conversations use a separate database (`continue`) from Open WebUI conversations, maintaining logical separation.
