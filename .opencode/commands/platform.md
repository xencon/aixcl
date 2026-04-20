---
description: Generates a comprehensive AIXCL platform status report with service health, observability status, and alerting overview
agent: agent-context
---

# /platform Command

Generates a comprehensive AIXCL platform status report showing service health, observability stack status, and alerting configuration.

## Usage

```
/platform
```

## What It Does

1. Checks AIXCL stack status and service health
2. Verifies observability stack (Prometheus, Grafana, Loki, Alloy)
3. Lists configured dashboards and alerting rules
4. Shows Prometheus scrape targets status
5. Provides access URLs and health summary
6. Displays recent issues and PRs from current release

## Report Format

```
════════════════════════════════════════════════════════════════
  AIXCL Platform Status Report
════════════════════════════════════════════════════════════════

Stack Overview
| Component | Status | Details |
|-----------|--------|---------|
| Profile   | ✅ sys | Complete stack |
| Services  | ✅ 12/12 | All healthy |
| Release   | v1.0.0-rc5 | Latest |
| Engine    | ✅ Active | Current inference |

Runtime Core Services
| Service | Status | Health Check |
|---------|--------|--------------|
| Ollama  | ✅ Available | Standby |
| vLLM    | ✅ Available | Standby |
| llama.cpp | ✅ Active | Running |

Operational Services
| Service | Status | Endpoint |
|---------|--------|----------|
| Open WebUI | ✅ Healthy | localhost:8080 |
| PostgreSQL | ✅ Healthy | localhost:5432 |
| pgAdmin    | ✅ Healthy | localhost:5050 |
| Prometheus | ✅ Healthy | localhost:9090 |
| Grafana    | ✅ Healthy | localhost:3000 |
| Loki       | ✅ Healthy | localhost:3100 |
| Alloy      | ✅ Healthy | localhost:12345 |

Prometheus Targets
| Target | Job | Status |
|--------|-----|--------|
| Alloy | alloy | ✅ up |
| cAdvisor | cadvisor | ✅ up |
| Node Exporter | node-exporter | ✅ up |

Grafana Dashboards
| Dashboard | Status |
|-----------|--------|
| PostgreSQL Performance | ✅ Provisioned |
| System Overview | ✅ Provisioned |
| Logs Dashboard | ✅ Provisioned |
| GPU Metrics | ✅ Provisioned |
| Docker Containers | ✅ Provisioned |

Alerting Rules
| Category | File | Status |
|----------|------|--------|
| GPU Alerts | gpu-alerts.yml | ✅ Configured |
| Log Alerts | log-alerts.yml | ✅ Configured |
| Docker Alerts | docker-alerts.yml | ✅ Configured |
| System Alerts | system-alerts.yml | ✅ Configured |
| PostgreSQL Alerts | postgresql-alerts.yml | ✅ Configured |

Access URLs
| Service | URL | Credentials |
|---------|-----|---------------|
| Open WebUI | http://localhost:8080 | .env config |
| pgAdmin | http://localhost:5050 | .env config |
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9090 | N/A |

Platform Health Summary
| Metric | Status |
|--------|--------|
| Services Healthy | 12/12 (100%) |
| Observability Stack | ✅ Fully Operational |
| Alerting Configured | ✅ 6 Rule Files |
| Dashboards Available | ✅ 5 Dashboards |
| Database Persistence | ✅ PostgreSQL Active |
| Logs Collection | ✅ Loki + Alloy |

Platform Status: ✅ FULLY OPERATIONAL
```

## When to Use

- After starting the AIXCL stack
- Before running inference workloads
- To verify observability is working
- To check service health status
- To get quick access URLs
- To validate alerting configuration

## Checks Performed

1. **Stack Status**: `./aixcl stack status`
2. **Service Health**: Individual service health endpoints
3. **Observability**: Prometheus, Grafana, Loki, Alloy status
4. **Scrape Targets**: Prometheus target health
5. **Dashboards**: Provisioned Grafana dashboards
6. **Alerts**: Configured alert rule files
7. **Access URLs**: Endpoint availability

## Output Details

### Service Status Indicators
- ✅ Healthy - Service responding normally
- ⚠️ Warning - Service running with issues
- ❌ Down - Service not responding
- ⏸️ Standby - Available but not active

### Health Check Endpoints
- Open WebUI: `http://localhost:8080/health`
- Grafana: `http://localhost:3000/api/health`
- Prometheus: `http://localhost:9090/-/healthy`
- Loki: `http://localhost:3100/ready`
- pgAdmin: `http://localhost:5050/misc/ping`

## Related Commands

- `/report` - Issue-First workflow report
- `/verify` - Check CI status
- `/workflow` - Run development workflow
- `/status` - Quick stack status (if implemented)

## See Also

- `docs/operations/monitoring.md` - Monitoring setup guide
- `docs/architecture/governance/` - Platform architecture
- `grafana/provisioning/` - Dashboard configurations
- `prometheus/` - Alerting rules