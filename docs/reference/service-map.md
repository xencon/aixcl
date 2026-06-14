# AIXCL Service Map

Quick reference for all platform services. Read this instead of parsing
`services/docker-compose.yml` when you need an overview.

For full service definitions, compose variants, and volume mounts, read
`services/docker-compose.yml` directly.

## Runtime Core (Always Enabled)

| Service | Container | Port | Profile | Entrypoint | Health Check |
|---------|-----------|------|---------|-----------|-------------|
| Ollama (inference) | `ollama` | 11434 | all | `scripts/runtime/ollama-entrypoint.sh` | `ollama list` |
| OpenCode | (VS Code plugin) | -- | all | n/a -- client-side IDE plugin | n/a |

## Secrets Management

| Service | Container | Port | Profile | Config | Notes |
|---------|-----------|------|---------|--------|-------|
| Vault | `vault` | 8200 | all | `vault/vault.hcl` | Storage: `aixcl-vault-data` volume |
| Vault Agent (postgres) | `vault-agent-postgres` | -- | all | `vault/agent-config/agent.hcl` | Long-lived; writes creds to `/tmp/aixcl-secrets/` |
| Vault Agent (openwebui) | `vault-agent-openwebui` | -- | sys | `vault/agent-config/openwebui.hcl` | Long-lived |
| Vault Bootstrap (postgres) | `vault-agent-postgres-bootstrap` | -- | all | `vault/agent-config/postgres-bootstrap.hcl` | One-shot; `restart: on-failure` |
| Vault Bootstrap (openwebui) | `vault-agent-openwebui-bootstrap` | -- | sys | `vault/agent-config/openwebui-bootstrap.hcl` | One-shot; `restart: on-failure` |
| Vault Bootstrap (pgadmin) | `vault-agent-pgadmin-bootstrap` | -- | sys | `vault/agent-config/pgexporter.hcl` | One-shot; `restart: on-failure` |
| Vault Bootstrap (grafana) | `vault-agent-grafana-bootstrap` | -- | bld,sys | -- | One-shot; `restart: on-failure` |

## Persistence

| Service | Container | Port | Profile | Entrypoint | Health Check |
|---------|-----------|------|---------|-----------|-------------|
| PostgreSQL | `postgres` | 5432 | all | `scripts/runtime/postgres-secret-entrypoint.sh` | `pg_isready -U $POSTGRES_USER` |

## Inference Engines (Alternatives to Ollama)

| Service | Container | Port | Profile | Entrypoint | Notes |
|---------|-----------|------|---------|-----------|-------|
| vLLM | `vllm` | 11434 | all | `scripts/runtime/vllm-entrypoint.sh` | NVIDIA GPU required |
| llama.cpp | `llamacpp` | 11434 | all | `scripts/runtime/llamacpp-entrypoint.sh` | CPU or CUDA |

Note: Only one inference engine is active at a time. Engine selection via `./aixcl engine set`.

## User Interface (sys profile only)

| Service | Container | Port | Profile | Entrypoint | Health Check |
|---------|-----------|------|---------|-----------|-------------|
| Open WebUI | `open-webui` | 8080 | sys | `scripts/runtime/openwebui-entrypoint.sh` | `curl http://127.0.0.1:8080/health` |
| pgAdmin | `pgadmin` | 5050 | sys | `scripts/runtime/pgadmin-entrypoint.sh` | -- |

## Observability (bld and sys profiles)

| Service | Container | Port | Profile | Config | Health Check |
|---------|-----------|------|---------|--------|-------------|
| Prometheus | `prometheus` | 9090 | bld, sys | `prometheus/prometheus.yml` | `wget http://127.0.0.1:9090/-/healthy` |
| Alertmanager | `alertmanager` | 9093 | bld, sys | `prometheus/alertmanager.yml` | `wget http://127.0.0.1:9093/-/healthy` |
| Grafana | `grafana` | 3000 | bld, sys | `grafana/provisioning/` | `wget http://127.0.0.1:3000/api/health` |
| Loki | `loki` | 3100 | bld, sys | `loki/loki-config.yml` | `wget http://127.0.0.1:3100/ready` |
| cAdvisor | `cadvisor` | 8081 | bld, sys | -- | -- |
| node-exporter | `node-exporter` | 9100 | bld, sys | -- | -- |
| postgres-exporter | `postgres-exporter` | 9187 | bld, sys | `vault/agent-config/pgexporter.hcl` | -- |
| nvidia-gpu-exporter | `nvidia-gpu-exporter` | 9835 | bld, sys | -- | GPU only |

## Stack Commands

```bash
./aixcl utils check-env               # Validate all prerequisites
./aixcl stack start --profile sys     # Start sys profile (all services)
./aixcl stack start --profile bld     # Start bld profile (no WebUI)
./aixcl stack status                  # Health status of all running services
./aixcl stack stop                    # Stop all services gracefully
```

## Notes

- All services use `network_mode: host` -- ports are bound directly on the host.
  See `docs/architecture/decisions/001-network-mode-host.md`.
- Bootstrap containers (one-shot) are stopped after successful initialisation.
  This is correct behaviour -- not a failure.
- Profile definitions: `docs/architecture/governance/02_profiles.md`
- Adding a service: `.claude/skills/add-service/SKILL.md`
