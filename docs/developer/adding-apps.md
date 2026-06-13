# Adding Applications to AIXCL

This guide explains how developers (builders) can integrate their own applications into the AIXCL platform using the generic "bring your own app" infrastructure introduced in v1.2.0.

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

## CLI Commands

| Command                          | Description                         |
|----------------------------------|-------------------------------------|
| `./aixcl app list`               | List installed applications         |
| `./aixcl app start <app>`        | Start an application                |
| `./aixcl app stop <app>`         | Stop an application                 |
| `./aixcl app restart <app>`      | Restart an application              |
| `./aixcl app status <app>`       | Show application status             |
| `./aixcl app build <app>`        | Build/rebuild application image     |
| `./aixcl app provision <app>`    | Provision declared platform resources |
| `./aixcl app secrets <app>`      | Show provisioned secrets (local dev) |
| `./aixcl app scaffold <name>`    | Create scaffolding for a new app    |
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
