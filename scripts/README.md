# AIXCL Scripts

This directory contains scripts used by AIXCL, Docker Compose, and GitHub Actions CI.

## Structure

```
scripts/
+-- checks/           # CI validation scripts
|   +-- check-agents.sh
|   +-- check-generated-files.sh
|   `-- check-paths.sh
+-- db/               # Database management
+-- exporters/        # Metrics exporters
+-- hooks/            # Git hooks
+-- runtime/          # Container entrypoint scripts
|   +-- configure-openwebui-direct-connections.sh
|   +-- grafana-entrypoint.sh
|   +-- llamacpp-entrypoint.sh
|   +-- ollama-entrypoint.sh
|   +-- openwebui-entrypoint.sh
|   +-- openwebui-vault-entrypoint.sh
|   +-- pgadmin-entrypoint.sh
|   +-- postgres-exporter-entrypoint.sh
|   +-- postgres-secret-entrypoint.sh
|   `-- vllm-entrypoint.sh
+-- security/         # Security checks
+-- utils/            # Setup and utility scripts
|   +-- init-volumes.sh
|   +-- setup-gpg.sh
|   +-- setup-hooks.sh
|   +-- setup-podman-rootless.sh
|   `-- validate-volume-consistency.sh
`-- vault/            # Vault agent and bootstrap scripts
```

## Categories

### checks/
Scripts for CI validation and compliance checking. Called by GitHub Actions workflows.

### runtime/
Container entrypoint scripts mounted and executed by Docker Compose services.

### utils/
One-time setup and maintenance utilities run directly by the operator.

- **setup-podman-rootless.sh** - Configure rootless Podman (requires `sudo`)
- **setup-gpg.sh** - Configure GPG signing for commits
- **init-volumes.sh** - Initialise Docker volumes before first stack start

### vault/
Vault agent configuration and secret bootstrap scripts.
