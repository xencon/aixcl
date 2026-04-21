---
description: Generates a real-time AIXCL platform health report with live service queries, resource utilization, errors, and security posture
description-short: Live platform health report (P1/P2/P3 prioritization)
agent: agent-context
---

# /platform Command

Runs **real-time queries** against the live AIXCL stack and reports on health, resource utilization, errors, security posture, and bottlenecks. Services are grouped by priority (P1 = critical, P2 = operational health, P3 = diagnostics).

## Usage

```
/platform
```

## What It Does

1. Detects active profile from `.env` (`PROFILE=usr|dev|ops|sys`)
2. Queries Docker for container status
3. Queries each service health endpoint over host network
4. Queries Prometheus for target state and alert status
5. Queries Loki for recent errors
6. Queries cAdvisor / node-exporter for resource utilization
7. Checks container security posture (cap_drop, no-new-privileges, read_only)
8. Compiles prioritized report

## Report Structure (Priority Order)

### P1 — Critical / Runtime Core

These services define whether AIXCL functions as a product. Checked first.

| Service | Check | Command |
|---------|-------|---------|
| Inference Engine | API models endpoint | `curl -sf http://127.0.0.1:11434/v1/models` |
| Inference Engine | Engine type / active model | `docker logs ollama --tail 5` or `docker logs vllm --tail 5` |
| Open WebUI (dev/sys) | HTTP health | `curl -sf http://127.0.0.1:8080/health` |
| PostgreSQL | TCP readiness | `pg_isready -U $POSTGRES_USER -h 127.0.0.1` |
| PostgreSQL | Active connections | `psql -U $POSTGRES_USER -h 127.0.0.1 -c "SELECT count(*) FROM pg_stat_activity;"` |
| PostgreSQL | Storage size | `psql -U $POSTGRES_USER -h 127.0.0.1 -c "SELECT pg_database_size('webui');"` |

Pass criteria: all returned data within 5 seconds.

### P1 — Critical / Data Persistence

| Service | Check | Command |
|---------|-------|---------|
| PostgreSQL | Query latency | `time psql -U $POSTGRES_USER -h 127.0.0.1 -c "SELECT version();"` |
| PostgreSQL | Slow query log | `docker logs postgres --tail 20` |
| pgAdmin (dev/sys) | HTTP ping | `curl -sf http://127.0.0.1:5050/misc/ping` |

### P2 — Health / Observability Stack (ops/sys)

| Service | Check | Command |
|---------|-------|---------|
| Prometheus | HTTP health | `curl -sf http://127.0.0.1:9090/-/healthy` |
| Prometheus | Scrape targets | `curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[""] | length'` |
| Prometheus | Targets down | `curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[""] | map(select(.health == "down")) | length'` |
| Prometheus | Active alerts | `curl -s http://127.0.0.1:9090/api/v1/rules | jq '.data.groups | length'` |
| Grafana | HTTP health | `curl -sf http://127.0.0.1:3000/api/health` |
| Loki | HTTP ready | `curl -sf http://127.0.0.1:3100/ready` |
| Alloy | HTTP metrics | `curl -sf http://127.0.0.1:12345` |
| Alertmanager | HTTP health | `curl -sf http://127.0.0.1:9093/-/healthy` |

Pass criteria: health endpoint returns 2xx within 5 seconds; target down count is 0.

### P2 — Health / Container and Host Resources

| Metric | Check | Command |
|--------|-------|---------|
| Running containers | Docker status | `docker ps --format "table {{.Names}}\t{{.Status}}"` |
| Container CPU | cAdvisor | `curl -s http://127.0.0.1:8081/api/v1.3/containers/docker/ | grep cpu_usage` |
| Container memory | cAdvisor | `curl -s http://127.0.0.1:8081/api/v1.3/containers/docker/ | grep memory_usage` |
| Host CPU | node-exporter | `curl -s http://127.0.0.1:9100/metrics | grep node_cpu_seconds_total` |
| Host memory | node-exporter | `curl -s http://127.0.0.1:9100/metrics | grep node_memory_MemAvailable_bytes` |
| Host disk | node-exporter | `curl -s http://127.0.0.1:9100/metrics | grep node_filesystem_avail_bytes` |
| GPU metrics (if present) | nvidia-gpu-exporter | `curl -s http://127.0.0.1:9835/metrics | grep dcgm_gpu_utilization` |

Pass criteria: host CPU usage under 80%, host memory under 90%, disk under 90%.

### P2 — Security / Logs

| Check | Command | Look for |
|-------|---------|----------|
| Container security posture | `docker inspect <container>` | `HostConfig.CapDrop`, `HostConfig.SecurityOpt`, `HostConfig.ReadonlyRootfs` |
| PostgreSQL auth errors | `docker logs postgres --tail 50` | `FATAL: password authentication failed` |
| Open WebUI auth errors | `docker logs open-webui --tail 50` | `401 Unauthorized`, `Invalid credentials` |
| Alloy pipeline failures | `docker logs alloy --tail 20` | `error`, `failed` |
| Loki error stream | `curl -s "http://127.0.0.1:3100/loki/api/v1/query?query={job=\"docker\"} |= \"error\"&limit=20&start=$(date -d '5 minutes ago' +%s)000000000"` | error logs in last 5m |

Pass criteria: no auth failures in last 5 minutes; all containers have `cap_drop: ALL` and `no-new-privileges:true`.

### P3 — Performance / Bottlenecks

| Check | Command |
|-------|---------|
| Prometheus high-latency targets | `curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[""] | map(select(.lastScrapeDuration > 5))'` |
| Inference queue depth | `docker logs ollama --tail 50` or `nvidia-smi` (if GPU) |
| Disk I/O wait | `iostat -x 1 3` (if available) or `top -bn1 | grep "wa"` |
| Swap usage | `free -h` |

Pass criteria: scrape latency under 5s; swap near 0.

### P3 — Exposed Endpoints

| Service | Endpoint | Default Credentials (from .env) |
|---------|----------|--------------------------------|
| Inference API | `http://127.0.0.1:11434` | None (local) |
| Open WebUI | `http://127.0.0.1:8080` | `$OPENWEBUI_EMAIL` / `$OPENWEBUI_PASSWORD` |
| pgAdmin | `http://127.0.0.1:5050` | `$PGADMIN_EMAIL` / `$PGADMIN_PASSWORD` |
| Grafana | `http://127.0.0.1:3000` | `$GRAFANA_ADMIN_USER` / `$GRAFANA_ADMIN_PASSWORD` |
| Prometheus | `http://127.0.0.1:9090` | None |
| Loki | `http://127.0.0.1:3100` | None |
| cAdvisor | `http://127.0.0.1:8081` | None |
| Alertmanager | `http://127.0.0.1:9093` | None |

Services not in the active profile are shown as `N/A`.

## Profile-Aware Filtering

| Profile | P1 Services | P2 Services | P3 Services |
|---------|-------------|-------------|-------------|
| **usr** | Inference Engine, PostgreSQL | None | Endpoints (inference only) |
| **dev** | + Open WebUI, pgAdmin | None | Endpoints (inference, webui, pgadmin) |
| **ops** | Inference Engine, PostgreSQL | Prometheus, Grafana, Loki, Alloy, cAdvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter | All observability endpoints |
| **sys** | All | All | All |

Services not in the active profile must be skipped with status `N/A (profile: <profile>)`.

## Response Style

- Use **markdown tables** for all scanable data
- Show status as: `pass`, `warn`, `FAIL`, or `N/A`
- Include **latency / timing** where relevant (e.g. `curl -w '@curl-format.txt'`)
- Surface **resource percentages** (CPU %, memory %, disk %)
- List **errors found** with count and most recent timestamp
- If a `curl` fails, show the exit code and suggest: `docker logs <container> --tail 20`
- End with a prioritized action list: `Next: <highest-priority failing check>`

## Status Indicators

| Indicator | Meaning |
|-----------|---------|
| `pass` | Service responding normally, within thresholds |
| `warn` | Service responding but metrics above thresholds (e.g. CPU > 80%) |
| `FAIL` | Service not responding, curl timeout, or critical error |
| `N/A` | Service not included in current profile |
| `standby` | Service present but not the active inference engine |

## When to Use

- After `./aixcl stack start` to verify services came up
- During incident response to triage failures in priority order
- Before running inference workloads to confirm capacity
- After profile changes (`usr` -> `dev` -> `ops` -> `sys`)
- If a service fails, re-run `/platform` after fixing to confirm recovery

## Error Recovery

If a check fails:
1. Note the exact service and the curl / command that failed
2. Run `docker logs <container> --tail 50` for that service
3. Check `docker inspect <container>` for security or config issues
4. Fix and re-run `/platform`

## Related

- `./aixcl stack status` — Quick stack status
- `./aixcl stack logs <service>` — View service logs
- `/report` — Issue-First workflow report
