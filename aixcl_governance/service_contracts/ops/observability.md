# Service Contract — Observability Stack

**Category:** Operational Services  
**Enforcement Level:** Guided

## Purpose
Provides metrics, logs, and dashboards for runtime observation. Includes Prometheus (metrics collection), Grafana (visualization), Loki (log aggregation), Promtail (log shipping), cAdvisor (container metrics), and node-exporter (host metrics).

## Depends On
- Runtime core (read-only observation)
- PostgreSQL (for postgres-exporter metrics)

## Exposes
- Prometheus metrics endpoint (port 9090)
- Grafana dashboards (port 3000)
- Loki log aggregation API (port 3100)
- Promtail log shipping
- cAdvisor container metrics (port 8081)
- node-exporter host metrics (port 9100)
- postgres-exporter database metrics (port 9187)
- nvidia-gpu-exporter GPU metrics (port 9400, if GPU available)

## Must Not Depend On
- Runtime control paths
- Business logic or inference workflows
- Service lifecycle management (start/stop/restart)

## Notes
- Observability services operate in read-only mode
- Metrics collection should not impact runtime performance
- Log aggregation should not interfere with runtime logging
