# ADR 004 -- Topological Sort for App depends_on

| Field | Value |
|-------|-------|
| Status | Accepted |
| Decided | 2026-06 (issue #1332) |
| Authority | lib/aixcl/commands/app.sh (_app_resolve_start_order) |

## Context

App manifests (`apps/<name>/app.yaml`) declare service dependencies via
`depends_on`. When starting an app, services must start in dependency order --
a service must not start before its dependencies are ready.

The original implementation iterated services in manifest order (0, 1, 2, ...),
ignoring `depends_on` entirely. This caused start failures when a dependent
service was listed before its dependency in the manifest.

## Decision

`app.sh` implements Kahn's topological sort algorithm in `_app_resolve_start_order()`
to compute the correct start order from `depends_on` declarations.

## Algorithm Summary

1. Build an adjacency list from `depends_on` declarations across all services.
2. Compute in-degree for each service (number of services that must start before it).
3. Start from services with in-degree 0 (no dependencies).
4. Process each service, decrement in-degree of its dependents.
5. Continue until all services are ordered, or detect a cycle (error).

## What depends_on Means in AIXCL

The `depends_on` field in `app.yaml` controls **start order only**. It does NOT:
- Wait for the dependency's health check to pass (use `service_utils.sh` for that)
- Restart a service if a dependency fails after startup
- Mirror Docker Compose's `depends_on` semantics (which support conditions like `service_healthy`)

The field names in `depends_on` must match `name` fields of OTHER services in
the SAME `app.yaml`. Referencing platform services (ollama, postgres, etc.) by
name is also supported -- the CLI verifies they are running before starting.

## What This Means for Agents

- Do NOT bypass `_app_resolve_start_order()` by iterating services as `seq 0 N`.
- Do NOT assume manifest order is dependency order -- it is not.
- If `app.sh start` reports a dependency cycle, the manifest is the source of truth
  to fix -- not the code.
- `depends_on` values are validated against: (a) sibling service names in the manifest,
  and (b) running platform service container names.

## Affected Files

- `lib/aixcl/commands/app.sh` -- implementation
- `lib/core/app_parser.sh` -- parses `APP_SERVICE_N_DEPENDS_ON_M` variables
- `etc/app-scaffold/app.yaml` -- shows `depends_on` usage in the template
- `docs/developer/adding-apps.md` -- developer-facing guide
