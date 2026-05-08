# AIXCL Profiles

Profiles define **which operational services are enabled** alongside the **always-present runtime core**.

---

## 1. Runtime Core (Always Enabled)

The runtime core consists of two components:

- **Inference Engine** (e.g., Ollama, vLLM, llama.cpp) - LLM inference engine (Docker-managed service)
- **OpenCode** - AI-powered code assistance (VS Code plugin, not Docker-managed)

OpenCode is a client-side IDE plugin that connects to the Inference Engine via the OpenAI-compatible API. Because it runs inside VS Code rather than as a Docker container, it is not included in the `RUNTIME_CORE_SERVICES` array or `PROFILE_SERVICES` mappings in `lib/cli/profile.sh`.

---

## 2. Profile Overview

| Profile | Purpose | Audience |
|---------|---------|----------|
| ops     | Operations-focused | Servers, operators, monitoring deployments |
| sys     | System-oriented | Complete deployments with all features |

---

## 3. Profile Definitions

### ops
**Purpose**: Observability-focused deployment for servers and operators.

**Includes**:
- Runtime core: Inference Engine, OpenCode (plugin)
- Vault (dynamic secrets management)
- PostgreSQL (database for runtime data)
- Prometheus (metrics collection)
- Grafana (metrics visualization and dashboards)
- Loki (log aggregation)
- cAdvisor (container metrics)
- node-exporter (host metrics)
- postgres-exporter (database metrics)
- nvidia-gpu-exporter (GPU metrics, if GPU available)

**Excludes**:
- Open WebUI (web interface)
- pgAdmin (database admin)

**Use Cases**: Production servers, monitoring-focused deployments, observability analysis

---

### sys
**Purpose**: System-oriented deployment with complete feature set.

**Includes**:
- Runtime core: Inference Engine, OpenCode (plugin)
- Vault (dynamic secrets management)
- All ops services: Prometheus, Grafana, Loki, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter
- Open WebUI (web interface for model interaction)
- pgAdmin (database administration UI)

**Use Cases**: System deployments, demonstrations, full-featured environments

---

## 4. Deprecated Profiles

### usr (DEPRECATED)
**Status**: Not supported as of 2026-05-08.

**Reason**: All services now require Vault for database secrets. PostgreSQL, Open WebUI, and pgAdmin all depend on Vault agents to provide passwords via `/run/secrets/`. Without Vault, these services fail to start.

---

### dev (DEPRECATED)
**Status**: Not supported as of 2026-05-08.

**Reason**: Same as `usr` — Vault is required for database secrets. The `dev` profile (Open WebUI + pgAdmin + PostgreSQL) cannot function without Vault agents.

---

## 5. Profile Selection Guidelines

- **ops**: Use for production deployments requiring observability (no WebUI)
- **sys**: Use for complete deployments with WebUI and all features

---

## 6. Profile Invariants

All profiles **must**:
- Include the complete runtime core (Inference Engine, OpenCode)
- Include Vault for secret management (required by all database-dependent services)
- Never disable or conditionally exclude runtime core components
- Maintain runtime core independence from operational services

Profiles **may**:
- Add operational services as needed
- Configure operational services differently
- Exclude operational services based on use case (e.g., no WebUI in ops)
