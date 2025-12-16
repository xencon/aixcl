# AIXCL Profiles

Profiles define **which operational services are enabled** alongside the **always-present runtime core**.

---

## 1. Runtime Core (Always Enabled)

- Ollama
- LLM-Council
- Continue
- Required runtime persistence

---

## 2. Profile Overview

| Profile | Purpose | Audience |
|---------|---------|----------|
| core    | Minimal runtime | CI, constrained systems |
| dev     | Developer workstation | Local development |
| ops     | Observability-focused | Servers/operators |
| full    | Everything enabled | Default/demos |

---

## 3. Profile Definitions

### core
**Purpose**: Minimal runtime for CI, constrained systems, or headless operation.

**Includes**:
- Runtime core: Ollama, LLM-Council, Continue (plugin)
- Runtime persistence (file-based or minimal database)

**Excludes**:
- Open WebUI (web interface)
- PostgreSQL (unless required for runtime persistence)
- pgAdmin (database admin)
- Prometheus, Grafana, Loki, Promtail (monitoring/logging)
- cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter (metrics)
- Watchtower (automation)

**Use Cases**: CI/CD pipelines, automated testing, resource-constrained environments

---

### dev
**Purpose**: Developer workstation with UI and database tools.

**Includes**:
- Runtime core: Ollama, LLM-Council, Continue (plugin)
- Open WebUI (web interface for model interaction)
- PostgreSQL (database for conversations and data)
- pgAdmin (database administration UI)

**Excludes**:
- Prometheus, Grafana, Loki, Promtail (monitoring/logging)
- cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter (metrics)
- Watchtower (automation)

**Use Cases**: Local development, testing, interactive model exploration

---

### ops
**Purpose**: Observability-focused deployment for servers and operators.

**Includes**:
- Runtime core: Ollama, LLM-Council, Continue (plugin)
- PostgreSQL (database for runtime data)
- Prometheus (metrics collection)
- Grafana (metrics visualization and dashboards)
- Loki (log aggregation)
- Promtail (log shipping)
- cAdvisor (container metrics)
- node-exporter (host metrics)
- postgres-exporter (database metrics)
- nvidia-gpu-exporter (GPU metrics, if GPU available)

**Excludes**:
- Open WebUI (web interface)
- pgAdmin (database admin)
- Watchtower (automation)

**Use Cases**: Production servers, monitoring-focused deployments, observability analysis

---

### full
**Purpose**: Complete stack with all features enabled.

**Includes**:
- Runtime core: Ollama, LLM-Council, Continue (plugin)
- All dev services: Open WebUI, PostgreSQL, pgAdmin
- All ops services: Prometheus, Grafana, Loki, Promtail, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter
- Watchtower (automatic container updates)

**Use Cases**: Default installation, demonstrations, full-featured development environment

---

## 4. Profile Selection Guidelines

- **core**: Use when you need minimal footprint and runtime core only
- **dev**: Use for local development and interactive work
- **ops**: Use for production deployments requiring observability
- **full**: Use for complete feature set and automatic updates

## 5. Profile Invariants

All profiles **must**:
- Include the complete runtime core (Ollama, LLM-Council, Continue)
- Never disable or conditionally exclude runtime core components
- Maintain runtime core independence from operational services

Profiles **may**:
- Add operational services as needed
- Configure operational services differently
- Exclude operational services based on use case
