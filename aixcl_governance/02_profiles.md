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
| usr     | User-oriented runtime | End users, minimal deployments |
| dev     | Developer workstation | Local development |
| ops     | Operations-focused | Servers/operators |
| sys     | System-oriented | Complete deployments, automation |

---

## 3. Profile Definitions

### usr
**Purpose**: User-oriented runtime with minimal footprint, optimized for end-user deployments.

**Includes**:
- Runtime core: Ollama, LLM-Council, Continue (plugin)
- PostgreSQL (database for runtime persistence)

**Excludes**:
- Open WebUI (web interface)
- pgAdmin (database admin)
- Prometheus, Grafana, Loki, Promtail (monitoring/logging)
- cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter (metrics)
- Watchtower (automation)

**Use Cases**: End-user deployments, resource-constrained environments, minimal installations with database persistence

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

### sys
**Purpose**: System-oriented deployment with complete feature set and automation.

**Includes**:
- Runtime core: Ollama, LLM-Council, Continue (plugin)
- All dev services: Open WebUI, PostgreSQL, pgAdmin
- All ops services: Prometheus, Grafana, Loki, Promtail, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter
- Watchtower (automatic container updates)

**Use Cases**: System deployments, demonstrations, full-featured environments with automation

---

## 4. Profile Selection Guidelines

- **usr**: Use for user-oriented deployments with minimal footprint (runtime core + PostgreSQL)
- **dev**: Use for local development and interactive work
- **ops**: Use for production deployments requiring observability
- **sys**: Use for system-oriented deployments with complete feature set and automatic updates

## 5. Profile Invariants

All profiles **must**:
- Include the complete runtime core (Ollama, LLM-Council, Continue)
- Never disable or conditionally exclude runtime core components
- Maintain runtime core independence from operational services

Profiles **may**:
- Add operational services as needed
- Configure operational services differently
- Exclude operational services based on use case
