# AIXCL Profiles

Profiles define **which operational services are enabled** alongside the **always-present runtime core**.

---

## 1. Runtime Core (Always Enabled)

The runtime core consists of one component:

- **Inference Engine** (Ollama) - LLM inference engine (Docker-managed service)

The Inference Engine exposes an OpenAI-compatible API. AI coding clients (OpenCode, Claude Code, Cursor, or any compatible tool) connect to this API. Clients are not part of the runtime core and are not Docker-managed; they are configured separately in their respective tool directories (`.opencode/`, `.claude/`).

---

## 2. Profile Overview

| Profile | Purpose | Audience |
|---------|---------|----------|
| bld     | Operations-focused | Servers, operators, monitoring deployments |
| sys     | System-oriented | Complete deployments with all features |

---

## 3. Profile Definitions

### bld
**Purpose**: Observability-focused deployment for servers and operators.

**Includes**:
- Runtime core: Inference Engine
- Vault (dynamic secrets management)
- PostgreSQL (database for runtime data)
- Prometheus (metrics collection)
- Grafana (metrics visualization and dashboards)
- Loki (log aggregation)
- cAdvisor (container metrics)
- node-exporter (host metrics)
- postgres-exporter (database metrics)
- nvidia-gpu-exporter (GPU metrics, if GPU available)
- blackbox-exporter (HTTP health probes for Ollama and Open WebUI)
- json-exporter (Ollama model telemetry from its JSON API)
- Alertmanager (alert routing)

**Excludes**:
- Open WebUI (web interface)
- pgAdmin (database admin)

**Use Cases**: Production servers, monitoring-focused deployments, observability analysis

---

### sys
**Purpose**: System-oriented deployment with complete feature set.

**Includes**:
- Runtime core: Inference Engine
- Vault (dynamic secrets management)
- All bld services: PostgreSQL, Prometheus, Grafana, Loki, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter, blackbox-exporter, json-exporter, Alertmanager
- Open WebUI (web interface for model interaction)
- pgAdmin (database administration UI)

**Use Cases**: System deployments, demonstrations, full-featured environments

---

## 4. Profile Selection Guidelines

- **bld**: Use for production deployments requiring observability (no WebUI)
- **sys**: Use for complete deployments with WebUI and all features

---

## 5. Profile Invariants

All profiles **must**:
- Include the complete runtime core (Inference Engine)
- Include Vault for secret management (required by all database-dependent services)
- Never disable or conditionally exclude runtime core components
- Maintain runtime core independence from operational services

Profiles **may**:
- Add operational services as needed
- Configure operational services differently
- Exclude operational services based on use case (e.g., no WebUI in bld)
