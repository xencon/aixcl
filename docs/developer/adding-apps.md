# Adding Applications to AIXCL

This guide explains how developers (builders) can integrate their own applications into the AIXCL platform using the generic "bring your own app" infrastructure introduced in v1.1.26.

For calling the inference API and tracing LLM output from your app, see [app-builder-guide.md](app-builder-guide.md).

## Overview

AIXCL provides a generic application framework that allows third-party applications to:
- Run alongside the platform runtime core
- Expose Prometheus metrics via file-based service discovery
- Integrate with the `./aixcl` CLI (start, stop, status, build)
- Maintain their own git history via submodules

Applications are decoupled from the AIXCL core and exist under `apps/<name>/`.

## Quick Start

### 1. Scaffold a New Application

The CLI provides a scaffold command to create the boilerplate:

```bash
./aixcl app scaffold my-app
```

This creates:
```
apps/my-app/
  app.yaml            # Application manifest
  docker-compose.yml  # Service definitions
  provider/           # Git submodule for builder code (created empty)
```

### 2. Configure the Manifest

Edit `apps/my-app/app.yaml`:

```yaml
app:
  name: "my-app"
  version: "0.1.0"
  description: "My custom AIXCL application"
  repository: "https://github.com/owner/my-app"

services:
  - name: "my-app-service"
    image: "my-app:latest"
    built: true
    build_context: "provider"
    build_dockerfile: "Dockerfile"
    ports:
      - "9000:9000"
    environment:
      - "MY_VAR=default"
    depends_on:
      - "ollama"

prometheus:
  targets:
    - "localhost:9000"
  labels:
    app: "my-app"
    job: "my-app-service"
```

### 3. Add Your Builder Code

Initialize the `provider/` directory as a git submodule pointing to your repository:

```bash
cd apps/my-app
git submodule add https://github.com/owner/my-app.git provider
```

Alternatively, if your code is local:

```bash
cd apps/my-app
mkdir provider
cp -r /path/to/my-app-source/* provider/
```

### 4. Build and Start

```bash
# Build the application image
./aixcl app build my-app

# Start the application (includes platform if not already running)
./aixcl app start my-app

# Check status
./aixcl app status my-app
```

## Manifest Reference

### `app` Block

| Field         | Required | Description                              |
|---------------|----------|------------------------------------------|
| name          | Yes      | Application identifier (must match dir)  |
| version       | Yes      | Semantic version                         |
| description   | No       | Human-readable description               |
| repository    | No       | URL to upstream repo                     |

### `services` Block

An array of service definitions used by the app command implementation. Each service can declare:
- `name`: Service name (used for container naming)
- `image`: Docker image reference
- `built`: Set `true` if the platform should build the image
- `build`: Build context and Dockerfile path
- `ports`: Exposed ports
- `environment`: Environment variables
- `depends_on`: Either another service in this manifest (started and
  health-checked before the dependent) or an already-running platform
  container (e.g., `ollama`). A name matching neither fails `app start`
  before any service is started; dependency cycles also fail.
- `healthcheck`: Readiness probe used by `app start` and `app status`:
  - `type: http` with `url` -- healthy on HTTP 200
  - `type: cmd` with `command` -- run inside the container, healthy on exit 0
  - `type: container_running` -- healthy if the container is up
  - `startup_timeout` / `interval` -- wait behavior in seconds

### `provision` Block

Declares platform resources the app needs. The platform provisions them
idempotently on every `./aixcl app start <app>` (and standalone via
`./aixcl app provision <app>`). This is the demarcation line between
platform and app: apps declare, the platform creates. Apps never hold
Vault tokens, never mount the shared platform secrets volume, and never
ship files into platform directories.

```yaml
provision:
  secrets:
    - db-password
    - auth-password
  postgres:
    database: my_app
    owner: my_app
    password_secret: db-password
```

Behavior:

- Each name under `secrets` becomes a field in Vault KV at
  `kv/apps/<app>`. Missing fields are generated (32-char alphanumeric);
  existing values are never overwritten, so re-provisioning is safe.
- Every secret is rendered to the per-app volume
  `aixcl-app-<app>-secrets` as `/run/secrets/<app>-<secret>` (mode 0600).
  Mount that volume read-only in your compose file:

  ```yaml
  volumes:
    my-secrets:
      name: aixcl-app-my-app-secrets
      external: true
  ```

- If `postgres.database` is set, the platform creates the role (LOGIN,
  password synced from `password_secret`, default `db-password`) and the
  database (owned by `owner`, default the database name) in the platform
  PostgreSQL instance. Identifiers must match `[a-z][a-z0-9_]*`.
- To inspect provisioned secret values during local development:
  `./aixcl app secrets <app>`.

A fresh or re-initialised stack heals itself: the next `app start`
regenerates Vault entries, re-renders the secrets volume, and recreates
the database role.

### `prometheus` Block

Defines scrape targets for this application:

```yaml
prometheus:
  metrics_path: "/api/metrics"   # optional, default /metrics
  targets:
    - "localhost:9000"
  labels:
    app: "my-app"
```

These targets are written to `prometheus/file_sd/<app_name>.json` and picked up by Prometheus `file_sd_configs`. `metrics_path` is emitted as a per-target `__metrics_path__` label, so apps with non-standard scrape paths do not require platform configuration changes. Label names must match `[a-zA-Z_][a-zA-Z0-9_]*`.

### `grafana` Block

Optional dashboard provisioning:

```yaml
grafana:
  dashboards:
    - "grafana/dashboards/my-dashboard.json"
```

### `submodules` Block

Declares git submodules to initialize:

```yaml
submodules:
  - path: "provider"
    url: "https://github.com/owner/my-app.git"
    branch: "main"
```

## Docker Compose Requirements

The `docker-compose.yml` in the app directory must obey AIXCL invariants:

- `network_mode: host` for all services (see docs/architecture/governance/00_invariants.md)
- `container_name` set explicitly to avoid collisions
- Labels for Prometheus identification:
  ```yaml
  labels:
    com.aixcl.app: "my-app"
    com.aixcl.service: "my-app-service"
  ```

### Hardened images and cap_drop: ALL

Official images (redis, postgres, etc.) whose entrypoints `chown` their
data directories as root crash-loop under `cap_drop: ALL` after the
first boot.

**Why it fails:** The entrypoint runs `find / chown` to fix ownership
before dropping to the service user. This requires `DAC_OVERRIDE` or
`DAC_READ_SEARCH`. Under `cap_drop: ALL` those capabilities are gone.
The first boot succeeds because the data directory is freshly created
with root ownership; every subsequent boot fails under `set -e` because
`chown` returns EPERM. The container never starts, restart counts climb
(one redis sidecar hit 6342 restarts before the pattern was identified).

**Fix:** Run the container as the service user so the entrypoint skips
the root-only ownership phase entirely:

```yaml
services:
  redis:
    image: redis:7
    user: "999:999"   # redis default UID:GID in the official image
    cap_drop:
      - ALL
```

**How to find the UID:** Check the official image documentation or run:

```bash
docker run --rm --entrypoint id redis:7
```

**When cap_drop: ALL is safe without user:** Images that do not chown
on startup (e.g. the Vault image, which starts as a non-root user by
default) can use `cap_drop: ALL` without the `user:` override.

### Building a new app's entrypoint hardened from day one

The section above is about *retrofitting* `cap_drop: ALL` onto an
existing third-party image whose entrypoint wasn't designed around it --
that risk (crash-loops discovered the hard way, restart counts climbing
into the thousands) comes from not knowing what the image's entrypoint
needs in advance. If you are writing your *own* entrypoint for a new
app, design it around the hardened capability set from the start
instead: there is no existing behavior to accidentally break.

`etc/app-scaffold/docker-compose.yml`'s `example-service` demonstrates
the default pattern: `cap_drop: ALL` plus either a `user:` override (for
images with no root-phase setup) or a minimal `cap_add` (for a custom
entrypoint that does its own chown/user-creation before dropping
privileges) -- see the comments in that file for both paths.

If your entrypoint needs the second path, follow the capped-entrypoint
rules in `docs/developer/adding-services.md` (learned auditing the
platform's own hardened entrypoints in #1909):

1. Create directories while still root, then `chown` -- root without
   `CAP_DAC_OVERRIDE` cannot `mkdir` inside a directory it no longer
   owns, so create everything the root phase needs before chowning it
   away.
2. Fail fast, naming the capability, on REQUIRED operations (e.g. a
   data-volume chown your service cannot start without).
3. WARN visibly, never silently swallow (`2>/dev/null || true`), on
   OPTIONAL operations.
4. Test against the three-scenario matrix before shipping: a truly-empty
   volume, a partially-initialised volume, and a capability-withheld run
   (which should fail loudly for required operations, or WARN-and-continue
   for optional ones).

## External App Repos

Apps do not need to live inside the platform tree. If your app source is in its
own repository, register it with the platform using its local path:

```bash
# Clone your app repo somewhere convenient
git clone git@github.com:you/my-app.git ~/src/my-app

# Register it with the platform (reads app.name from app.yaml)
./aixcl app register ~/src/my-app

# Use it like any built-in app
./aixcl app start my-app
./aixcl app status my-app
./aixcl app stop my-app

# Remove the registration (does not touch files or running containers)
./aixcl app unregister my-app
```

The registry is stored at `~/.config/aixcl/registry` as a plain text file.
It is machine-local and not committed to the platform repo.

`./aixcl app list` shows both built-in apps and registered external apps,
with the external path displayed for registered entries.

Tab completion works for `register` (directory paths) and for all app-name
arguments (`start`, `stop`, `status`, `build`, `unregister`) across both
built-in and registered apps.

## CLI Commands

| Command                          | Description                         |
|----------------------------------|-------------------------------------|
| `./aixcl app list`               | List all apps (built-in and registered) |
| `./aixcl app register <path>`    | Register an external app by local path |
| `./aixcl app unregister <name>`  | Remove a registered external app    |
| `./aixcl app start <app>`        | Start an application                |
| `./aixcl app stop <app>`         | Stop an application                 |
| `./aixcl app restart <app>`      | Restart an application              |
| `./aixcl app status <app>`       | Show application status             |
| `./aixcl app build <app>`        | Build/rebuild application image     |
| `./aixcl app provision <app>`    | Provision declared platform resources |
| `./aixcl app secrets <app>`      | Show provisioned secrets (local dev) |
| `./aixcl app scaffold <name>`    | Create scaffolding for a new built-in app |
| `./aixcl app install <url>`      | Install from a git URL              |

## Prometheus Integration

When an app is started, the app handler writes a JSON file to `prometheus/app-targets/<app_name>.json` containing the targets and labels from the manifest.

Prometheus reloads these files automatically via `file_sd_configs` with a 30-second refresh interval.

To verify targets are detected:
1. Start the app: `./aixcl app start my-app`
2. Open Prometheus: http://localhost:9090
3. Navigate to Status -> Targets
4. Look for the `aixcl-apps` job

## Grafana Integration

Dashboards listed in the `grafana` block of the manifest are copied into `grafana/provisioning/dashboards/apps/<app>/` when the app starts (a dedicated subdirectory avoids UID collisions with platform dashboards). Grafana's provisioner picks up changes on its scan interval; restart Grafana to force a reload.

A starter dashboard template is available at `etc/app-scaffold/grafana/dashboards/app-overview.json`. Copy it into your app directory and reference it in the `grafana` block:

```yaml
grafana:
  dashboards:
    - "grafana/dashboards/app-overview.json"
```

## Prometheus Alert Rules

Place a file at `apps/<name>/prometheus/alert-rules.yml` and the platform will
copy it into `prometheus/app-alerts/<name>.yml` on `./aixcl app start`. Prometheus
loads all files matching `app-alerts/*.yml` automatically (no platform restart needed).
The file is removed on `./aixcl app stop` and `./aixcl app remove`.

A starter template with three common alerts (app down, high error rate, high latency)
is available at `etc/app-scaffold/prometheus/alert-rules.yml`. Copy it to your app:

```bash
mkdir -p apps/my-app/prometheus
cp etc/app-scaffold/prometheus/alert-rules.yml apps/my-app/prometheus/
# Edit the file -- replace "my-app" with your app name and adjust thresholds
```

Alerts route to Alertmanager at `localhost:9093` using the platform's existing
`prometheus/alertmanager.yml` configuration. To add a notification channel
(Slack, PagerDuty, email) edit that file.

## Log Integration

Container logs do **not** flow to Loki automatically. The platform runs Loki as a log store but does not include Promtail or a Docker log driver plugin, so no automatic log shipping is configured.

### Options

**Option 1 -- Docker Loki log driver (recommended for containerized apps)**

Install the Grafana Loki Docker driver plugin once per host:

```bash
docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions
```

Then add a `logging` block to your service in `docker-compose.yml`:

```yaml
services:
  my-app-service:
    image: my-app:latest
    network_mode: host
    logging:
      driver: loki
      options:
        loki-url: "http://localhost:3100/loki/api/v1/push"
        loki-external-labels: "app=my-app,job=my-app-service"
```

Logs are then queryable in Grafana under Explore -> Loki using `{app="my-app"}`.

**Option 2 -- Push logs from application code**

Send structured log lines directly to the Loki push API:

```bash
curl -s -X POST http://localhost:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [{
      "stream": {"app": "my-app", "level": "info"},
      "values": [["'"$(date +%s%N)"'", "your log message here"]]
    }]
  }'
```

Most logging libraries (Python structlog, Winston, etc.) have Loki appenders that handle this automatically.

**Option 3 -- Query stdout via `docker logs`**

For local development without Loki integration, query container logs directly:

```bash
docker logs my-app-service --follow
# Or via the CLI wrapper:
./aixcl stack logs
```

## Lifecycle and Isolation

- Applications run under `network_mode: host` alongside the platform
- The runtime core (Ollama) is always available; operational services are profile-dependent
- Apps may depend on platform services but the platform must never depend on apps
- App containers are managed independently from platform containers

## Example: Full Integration

A complete example application is available in `etc/app-scaffold/`.

To test the scaffold:

```bash
./aixcl app scaffold test-app
# Edit apps/test-app/app.yaml and docker-compose.yml
./aixcl app build test-app
./aixcl app start test-app
```

## Troubleshooting

- **Manifest not found**: Ensure `apps/<name>/app.yaml` exists
- **python3-yaml missing**: Install with `sudo apt-get install python3-yaml`
- **Prometheus not picking up targets**: Check that `prometheus/app-targets/` exists and is writable
- **Build fails**: Verify the build context path and Dockerfile in `docker-compose.yml`

## Compliance

- Apps must not remove, replace, or conditionally disable runtime core components
- Apps must obey the `network_mode: host` invariant
- App logic must not merge into platform monitoring or admin tooling

For the authoritative platform invariants, see `docs/architecture/governance/00_invariants.md`.
