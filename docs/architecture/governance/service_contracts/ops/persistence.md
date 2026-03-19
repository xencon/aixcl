# Service Contract — Persistence Stack

**Category:** Operational Services  
**Enforcement Level:** Guided

## Purpose
Provides PostgreSQL database storage for runtime data (Open WebUI conversations, OpenCode sessions) and operational data. Includes pgAdmin for database administration.

## Depends On
- Open WebUI (uses PostgreSQL for conversation storage)
- OpenCode (local-first IDE)

## Exposes
- PostgreSQL database server (port 5432)
- pgAdmin web interface (port 5050)
- Database endpoints for:
  - Open WebUI conversations
  - OpenCode sessions

## Must Not Depend On
- UI logic (pgAdmin is admin tool, not runtime UI)
- Automation logic (Watchtower)
- Monitoring/logging services

## Notes
- **Runtime/Operational Boundary**: PostgreSQL serves both runtime (conversation storage) and operational (admin) purposes. This creates a design tension with the invariant that "runtime core must be runnable without operational services."
- **Resolution**: AIXCL services may use PostgreSQL if available, but must function gracefully if it is unavailable.
- **Current Implementation**: All profiles (`usr`, `dev`, `ops`, `sys`) include PostgreSQL for persistence. The `usr` profile includes PostgreSQL as the minimal operational service for runtime persistence.
- **pgAdmin**: Purely operational/admin tooling, never required for runtime.
