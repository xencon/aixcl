# CONTEXT: etc/app-scaffold/

Scaffold templates for creating new apps on the AIXCL platform. These are
the authoritative templates -- use them as the starting point, not a copy
of an existing app.

## Contents

| File | Purpose |
|------|---------|
| `app.yaml` | Canonical app manifest template. Shows every supported field with comments. This is the schema that `lib/core/app_parser.sh` parses. |
| `docker-compose.yml` | Compose scaffold for app services. Shows the minimum required structure and recommended patterns, including capability hardening (`cap_drop: ALL` + a `user:` override or minimal `cap_add`) baked in as the default -- see #1925. |

## How app.yaml Maps to Shell Variables

`app_parser.sh` converts `app.yaml` fields to `APP_*` shell variables:

```
app.name          --> APP_NAME
app.version       --> APP_VERSION
services[0].name  --> APP_SERVICE_0_NAME
services[0].depends_on --> APP_SERVICE_0_DEPENDS_ON_0 (etc.)
```

The `depends_on` field drives topological sort in `app.sh start`.
See `docs/architecture/decisions/004-topological-sort-depends-on.md`.

## Creating a New App

1. Copy `etc/app-scaffold/app.yaml` to `apps/<your-app-name>/app.yaml`
2. Copy `etc/app-scaffold/docker-compose.yml` to `apps/<your-app-name>/docker-compose.yml`
3. Fill in the required fields
4. Read `docs/developer/adding-apps.md` for the full guide (includes `depends_on`
   semantics and `cap_drop: ALL` guidance -- both retrofitting an existing
   image and hardening a new entrypoint from day one)

## Agent Guidance

**You MAY:**
- Add new optional fields to these templates when `app_parser.sh` is updated to parse them
- Improve comments and examples

**You MUST NOT:**
- Remove fields that existing apps depend on (check `apps/*/app.yaml` first)
- Change the field naming convention (the `APP_*` variable names are used by multiple scripts)

## Cross-References

- `lib/core/app_parser.sh` -- parses app.yaml into APP_* shell variables
- `lib/aixcl/commands/app.sh` -- uses parsed variables for lifecycle management
- `docs/developer/adding-apps.md` -- full app development guide
- `docs/architecture/decisions/004-topological-sort-depends-on.md` -- depends_on semantics
