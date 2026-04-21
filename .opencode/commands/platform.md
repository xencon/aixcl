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
| Profile   | pass sys | Complete stack |
| Services  | pass 12/12 | All healthy |
| Release   | v1.0.0-rc6 | Latest |
| Engine    | pass Active | Current inference |

Runtime Core Services
| Service | Status | Health Check |
|---------|--------|--------------|
| Ollama  | pass Available | Standby |
| vLLM    | pass Available | Standby |
| llama.cpp | pass Active | Running |

Operational Services
| Service | Status | Endpoint |
|---------|--------|----------|
| Open WebUI | pass Healthy | localhost:8080 |
| PostgreSQL | pass Healthy | localhost:5432 |
| pgAdmin    | pass Healthy | localhost:5050 |
| Prometheus | pass Healthy | localhost:9090 |
| Grafana    | pass Healthy | localhost:3000 |
| Loki       | pass Healthy | localhost:3100 |
| Alloy      | pass Healthy | localhost:12345 |

Prometheus Targets
| Target | Job | Status |
|--------|-----|--------|
| Alloy | alloy | pass up |
| cAdvisor | cadvisor | pass up |
| Node Exporter | node-exporter | pass up |

Grafana Dashboards
| Dashboard | Status |
|-----------|--------|
| PostgreSQL Performance | pass Provisioned |
| System Overview | pass Provisioned |
| Logs Dashboard | pass Provisioned |
| GPU Metrics | pass Provisioned |
| Docker Containers | pass Provisioned |

Alerting Rules
| Category | File | Status |
|----------|------|--------|
| GPU Alerts | gpu-alerts.yml | pass Configured |
| Log Alerts | log-alerts.yml | pass Configured |
| Docker Alerts | docker-alerts.yml | pass Configured |
| System Alerts | system-alerts.yml | pass Configured |
| PostgreSQL Alerts | postgresql-alerts.yml | pass Configured |

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
| Observability Stack | pass Fully Operational |
| Alerting Configured | pass 6 Rule Files |
| Dashboards Available | pass 5 Dashboards |
| Database Persistence | pass PostgreSQL Active |
| Logs Collection | pass Loki + Alloy |

Platform Status: pass FULLY OPERATIONAL
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
- pass Healthy - Service responding normally
- warn Warning - Service running with issues
- FAIL Down - Service not responding
- standby Standby - Available but not active

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

## See Also

- `docs/operations/monitoring.md` - Monitoring setup guide
- `docs/architecture/governance/` - Platform architecture
- `grafana/provisioning/` - Dashboard configurations
- `prometheus/` - Alerting rules