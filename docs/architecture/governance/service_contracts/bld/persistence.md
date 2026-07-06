# Service Contract -- Persistence Stack

**Category:** Operational Services
**Enforcement Level:** Guided

## Purpose
Provides PostgreSQL database storage for runtime data (Open WebUI conversations) and operational data. Includes pgAdmin for database administration.

## Depends On
- Vault (database credentials are rendered by `vault-agent-postgres` into the shared secrets volume)

## Consumed By
- Open WebUI (conversation storage)
- pgAdmin (administration)
- Postgres Exporter (metrics)

## Exposes
- PostgreSQL database server (port 5432)
- pgAdmin web interface (port 5050)

## Must Not Depend On
- UI logic (pgAdmin is admin tool, not runtime UI)
- Monitoring/logging services

## Notes
- **Runtime/Operational Boundary**: PostgreSQL serves both runtime (conversation storage) and operational (admin) purposes. This creates a design tension with the invariant that "runtime core must be runnable without operational services."
- **Resolution**: AIXCL services may use PostgreSQL if available, but must function gracefully if it is unavailable.
- **Current Implementation**: Both active profiles (`bld`, `sys`) include PostgreSQL. Database initialization is `scripts/db/init/01-create-webui.sql` (Open WebUI database only).
- **pgAdmin**: Purely operational/admin tooling, never required for runtime.
