# AIXCL Application Guide

AIXCL supports a generic "bring your own app" (BYO) framework. Install, scaffold, build, and manage applications alongside the platform runtime.

## Overview

Applications live under `apps/<name>/` and are decoupled from the AIXCL core. They can:
- Run alongside platform services
- Expose Prometheus metrics
- Integrate with `./aixcl` CLI commands
- Maintain their own git history via submodules

## Quick Start

### Install an App from Git

```bash
./aixcl app install https://github.com/example/my-app.git
```

This clones the repository into `apps/my-app/` and registers it.

### Scaffold a New App

```bash
./aixcl app scaffold my-app
```

Creates:
```
apps/my-app/
  app.yaml            # Application manifest
  docker-compose.yml  # Service definitions
  provider/           # Builder code directory
```

### Build and Run

```bash
./aixcl app build my-app
./aixcl app start my-app
./aixcl app status my-app
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `./aixcl app list` | List installed applications |
| `./aixcl app start <app>` | Start an application |
| `./aixcl app stop <app>` | Stop an application |
| `./aixcl app restart <app>` | Restart an application |
| `./aixcl app status <app>` | Show application status |
| `./aixcl app build <app>` | Build/rebuild application image |
| `./aixcl app remove <app>` | Stop, remove, and clean an application |
| `./aixcl app scaffold <name>` | Create scaffolding for a new app |
| `./aixcl app install <url>` | Install from a git URL |

## Architecture

- Apps run under `network_mode: host` alongside the platform
- The runtime core (Ollama) is always available
- Apps may depend on platform services but the platform must never depend on apps
- App containers are managed independently from platform containers

## Integration

When an app is started:
- Prometheus targets are written to `prometheus/file_sd/<app>.json`
- Grafana dashboards are copied to `grafana/provisioning/dashboards/apps/<app>/`

See [docs/developer/adding-apps.md](../developer/adding-apps.md) for the full developer guide including manifest reference and compliance rules.

## Try It

Scaffold a new app and start it:

```bash
./aixcl app scaffold my-app
# Edit apps/my-app/app.yaml and docker-compose.yml for your use case
./aixcl app build my-app
./aixcl app start my-app
./aixcl app status my-app
```

The scaffold creates a working template with all supported manifest fields.
See `etc/app-scaffold/` for the canonical templates and
[docs/developer/adding-apps.md](../developer/adding-apps.md) for the full guide.
