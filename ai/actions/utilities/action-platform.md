---
name: Platform Health Report
description: Runs real-time queries against the live AIXCL stack and reports on health, resource utilization, errors, security posture, and bottlenecks
category: utilities
tool: bash
requires:
  - docker
  - curl
  - jq
  - ss or netstat
---

# Action: Platform Health Report

Runs real-time queries against the live AIXCL stack and reports on health, resource utilization, errors, security posture, and bottlenecks. Services are grouped by priority (P1 = critical, P2 = operational health, P3 = diagnostics).

## Usage

Run this slash command:
```
/platform
```

Or manually from CLI:
```bash
./aixcl stack status
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

### P1 -- Critical / Runtime Core

These services define whether AIXCL functions as a product. Checked first.

| Service | Check | Command |
|---------|-------|---------|
| Inference Engine | API models endpoint | `curl -sf http://127.0.0.1:11434/v1/models` |
| Inference Engine | Models loaded | `curl -s http://127.0.0.1:11434/v1/models \| jq ".data[].id"` |
| Inference Engine | Engine type / active model | `docker logs ollama --tail 5` or `docker logs vllm --tail 5` |
| Open WebUI (dev/sys) | HTTP health | `curl -sf http://127.0.0.1:8080/health` |
| PostgreSQL | TCP readiness | `docker exec postgres pg_isready -U $POSTGRES_USER --timeout=5` |
| PostgreSQL | Active connections | `docker exec postgres psql -U $POSTGRES_USER -c "SELECT count(*) FROM pg_stat_activity;"` |
| PostgreSQL | Storage size | `docker exec postgres psql -U $POSTGRES_USER -c "SELECT pg_database_size('webui');"` |

Pass criteria: all returned data within 5 seconds.

### P1 -- Critical / Data Persistence

| Service | Check | Command |
|---------|-------|---------|
| PostgreSQL | Query latency | `docker exec postgres time psql -U $POSTGRES_USER -c "SELECT version();"` |
| PostgreSQL | Slow query log | `docker logs postgres --tail 20` |
| pgAdmin (dev/sys) | HTTP ping | `curl -sf http://127.0.0.1:5050/misc/ping` |

### P2 -- Health / Observability Stack (ops/sys)

| Service | Check | Command |
|---------|-------|---------|
| Prometheus | HTTP health | `curl -sf http://127.0.0.1:9090/-/healthy` |
| Prometheus | Scrape targets | `curl -s http://127.0.0.1:9090/api/v1/targets \| jq '.data.activeTargets \| length'` |
| Prometheus | Targets down | `curl -s http://127.0.0.1:9090/api/v1/targets \| jq '.data.activeTargets \| map(select(.health == "down")) \| length'` |
| Prometheus | Firing alerts | `curl -s http://127.0.0.1:9090/api/v1/alerts \| jq ".data.alerts \| length"` |
| Prometheus | Rules configured | `curl -s http://127.0.0.1:9090/api/v1/rules \| jq '.data.groups \| length'` |
| Grafana | HTTP health | `curl -sf http://127.0.0.1:3000/api/health` |
| Loki | HTTP ready | `curl -sf http://127.0.0.1:3100/ready` |
| Alloy | HTTP metrics | `curl -sf http://127.0.0.1:12345` |
| Alertmanager | HTTP health | `curl -sf http://127.0.0.1:9093/-/healthy` |

Pass criteria: health endpoint returns 2xx within 5 seconds; target down count is 0.

### P2 -- Health / Container and Host Resources

| Metric | Check | Command |
|--------|-------|---------|
| Running containers | Docker status | `docker ps --format "table {{.Names}}\t{{.Status}}"` |
| Container CPU | cAdvisor | `curl -s http://127.0.0.1:8081/api/v1.3/containers/docker/ \| grep cpu_usage` |
| Container memory | cAdvisor | `curl -s http://127.0.0.1:8081/api/v1.3/containers/docker/ \| grep memory_usage` |
| Host CPU | node-exporter | `curl -s http://127.0.0.1:9100/metrics \| grep node_cpu_seconds_total` |
| Host memory | node-exporter | `curl -s http://127.0.0.1:9100/metrics \| grep node_memory_MemAvailable_bytes` |
| Host disk | node-exporter | `curl -s http://127.0.0.1:9100/metrics \| grep node_filesystem_avail_bytes` |
| GPU metrics (if present) | nvidia-gpu-exporter | `curl -s http://127.0.0.1:9835/metrics \| grep dcgm_gpu_utilization` |
| Port bindings | `ss` / `netstat` | `ss -tlnp \| grep -E "11434\|8080\|5432\|9090\|3000\|3100\|5050\|8081"` |
| Volume disk usage | Docker / `df` | `docker system df -v` or `df -h \| grep -E "overlay\|/var/lib/docker"` |

Pass criteria: host CPU usage under 80%, host memory under 90%, disk under 90%. Expected ports are bound; volume usage under 90%.

### P2 -- Security / Logs

| Check | Command | Look for |
|-------|---------|----------|
| Container security posture | `docker inspect <container>` | `HostConfig.CapDrop`, `HostConfig.SecurityOpt`, `HostConfig.ReadonlyRootfs` |
| PostgreSQL auth errors | `docker logs postgres --tail 50` | `FATAL: password authentication failed` |
| Open WebUI auth errors | `docker logs open-webui --tail 50` | `401 Unauthorized`, `Invalid credentials` |
| Alloy pipeline failures | `docker logs alloy --tail 20` | `error`, `failed` |
| Loki error stream | `curl -s "http://127.0.0.1:3100/loki/api/v1/query?query={job=\"docker\"} \|= \"error\"&limit=20&start=$(date -d '5 minutes ago' +%s)000000000"` | error logs in last 5m |

Pass criteria: no auth failures in last 5 minutes; all containers have `cap_drop: ALL` and `no-new-privileges:true`.

### P3 -- Performance / Bottlenecks

| Check | Command |
|-------|---------|
| Prometheus high-latency targets | `curl -s http://127.0.0.1:9090/api/v1/targets \| jq '.data.activeTargets \| map(select(.lastScrapeDuration > 5))'` |
| Inference queue depth | `docker logs ollama --tail 50` or `nvidia-smi` (if GPU) |
| Disk I/O wait | `iostat -x 1 3` (if available) or `top -bn1 \| grep "wa"` |
| Swap usage | `free -h` |
| Container restart count | `docker inspect -f "{{.Name}}: restarts={{.RestartCount}} error={{.State.Error}}" $(docker ps -q)` |

Pass criteria: scrape latency under 5s; swap near 0; restart count stable (no recent restarts).

### P3 -- Exposed Endpoints

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

Services not in the active profile are shown as `N/A (profile: <profile>)`.

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

## Report Output Template

When presenting results to the user, the agent must produce a **single consolidated report** with all checks grouped by priority. Use this exact structure. Replace every `<placeholder>` with live data from the commands above.

```
AIXCL Platform Health Report
Profile: <profile>  |  Engine: <engine>  |  Total checks: <count>

P1 -- Critical / Runtime Core
| Service           | Status   | Latency | Detail                          |
|-------------------|----------|---------|---------------------------------|
| Inference Engine  | <status> | <ms>    | <model_name>                    |
| Open WebUI        | <status> | <ms>    | <status_bool>                   |
| PostgreSQL        | <status> | <ms>    | <connections> / <storage_size>  |

P1 -- Critical / Data Persistence
| Service      | Status   | Latency | Detail                |
|--------------|----------|---------|-----------------------|
| PostgreSQL   | <status> | <ms>    | version: <version>    |
| pgAdmin      | <status> | <ms>    | ping: <status>        |

P2 -- Health / Observability Stack
| Service       | Status   | Latency | Detail                              |
|---------------|----------|---------|-------------------------------------|
| Prometheus    | <status> | <ms>    | targets: <up>/<total>, alerts: <n>  |
| Grafana       | <status> | <ms>    | database: <status>                  |
| Loki          | <status> | <ms>    | ready: <status>                     |
| Alloy         | <status> | <ms>    | <http_status>                       |
| Alertmanager  | <status> | <ms>    | <http_status>                       |

P2 -- Health / Container and Host Resources
| Metric            | Status   | Value                    |
|-------------------|----------|--------------------------|
| Containers running| <status> | <count>                  |
| Container CPU     | <status> | <percentage>             |
| Container memory  | <status> | <percentage>             |
| Host CPU          | <status> | <percentage>             |
| Host memory       | <status> | <percentage>             |
| Host disk         | <status> | <percentage>             |
| GPU metrics       | <status> | <percentage>             |
| Port bindings     | <status> | <ports_bound>/<expected> |
| Volume disk usage | <status> | <percentage>             |

P2 -- Security / Logs
| Check                    | Status   | Detail                      |
|--------------------------|----------|-----------------------------|
| Container security       | <status> | violations: <count>           |
| PostgreSQL auth errors   | <status> | errors_last_5m: <count>     |
| Open WebUI auth errors | <status> | errors_last_5m: <count>     |
| Alloy pipeline failures  | <status> | errors_last_5m: <count>     |
| Loki errors              | <status> | logs_last_5m: <count>       |

P3 -- Performance / Bottlenecks
| Metric              | Status   | Detail                    |
|---------------------|----------|---------------------------|
| High-latency targets| <status> | count: <n>                |
| Inference queue     | <status> | <queue_depth>             |
| Disk I/O wait       | <status> | <percentage>              |
| Swap usage          | <status> | <size>                    |
| Container restarts  | <status> | restarts: <count>         |

P3 -- Exposed Endpoints
| Service      | Endpoint                        | Status   |
|--------------|---------------------------------|----------|
| Inference API| http://127.0.0.1:11434          | <status> |
| Open WebUI   | http://127.0.0.1:8080            | <status> |
| pgAdmin      | http://127.0.0.1:5050            | <status> |
| Grafana      | http://127.0.0.1:3000            | <status> |
| Prometheus   | http://127.0.0.1:9090            | <status> |
| Loki         | http://127.0.0.1:3100            | <status> |
| cAdvisor     | http://127.0.0.1:8081            | <status> |
| Alertmanager | http://127.0.0.1:9093            | <status> |

Summary
- Highest priority issue: <summary>
- Next: <highest-priority_failing_check>
```

Show **P1 first, then P2, then P3**. Skip any section where every row is `N/A`. If all P1 is green, show P2. If P2 is green, show P3. If any check in a tier fails, stop after that tier and print the summary -- unless the user explicitly asks for full output.

## Implementation Commands

```bash
#!/bin/bash
# AIXCL Platform Health Check Script
# Usage: ./scripts/platform-check.sh [profile]

PROFILE="${1:-$(grep '^PROFILE=' .env 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')}"
PROFILE="${PROFILE:-usr}"

# Detect engine
ENGINE="$(docker ps --format '{{.Names}}' | grep -E 'ollama|vllm|llamacpp' | head -1)"
ENGINE="${ENGINE:-unknown}"

echo "AIXCL Platform Health Report"
echo "Profile: $PROFILE  |  Engine: $ENGINE"
echo ""

# P1 -- Critical / Runtime Core
echo "P1 -- Critical / Runtime Core"
echo "| Service           | Status   | Latency | Detail                          |"
echo "|-------------------|----------|---------|---------------------------------|"

# Inference Engine
IE_STATUS="N/A"
IE_LATENCY="N/A"
IE_DETAIL="N/A"
if [ "$PROFILE" != "ops" ] || [ "$PROFILE" = "sys" ]; then
  START=$(date +%s%N)
  if curl -sf http://127.0.0.1:11434/v1/models >/dev/null 2>&1; then
    END=$(date +%s%N)
    IE_LATENCY=$(( (END - START) / 1000000 ))ms
    IE_STATUS="pass"
    IE_DETAIL="$(curl -s http://127.0.0.1:11434/v1/models 2>/dev/null | jq -r '.data[0].id' 2>/dev/null || echo 'unknown')"
  else
    IE_STATUS="FAIL"
    IE_LATENCY="timeout"
    IE_DETAIL="curl exit: $?"
  fi
fi
printf "| Inference Engine  | %-8s | %-7s | %-31s |\n" "$IE_STATUS" "$IE_LATENCY" "$IE_DETAIL"

# Open WebUI
WEBUI_STATUS="N/A"
WEBUI_LATENCY="N/A"
WEBUI_DETAIL="N/A"
if [ "$PROFILE" = "dev" ] || [ "$PROFILE" = "sys" ]; then
  START=$(date +%s%N)
  if curl -sf http://127.0.0.1:8080/health >/dev/null 2>&1; then
    END=$(date +%s%N)
    WEBUI_LATENCY=$(( (END - START) / 1000000 ))ms
    WEBUI_STATUS="pass"
    WEBUI_DETAIL="healthy"
  else
    WEBUI_STATUS="FAIL"
    WEBUI_LATENCY="timeout"
    WEBUI_DETAIL="curl exit: $?"
  fi
fi
printf "| Open WebUI        | %-8s | %-7s | %-31s |\n" "$WEBUI_STATUS" "$WEBUI_LATENCY" "$WEBUI_DETAIL"

# PostgreSQL
PG_STATUS="N/A"
PG_LATENCY="N/A"
PG_DETAIL="N/A"
if [ "$PROFILE" = "usr" ] || [ "$PROFILE" = "dev" ] || [ "$PROFILE" = "sys" ] || [ "$PROFILE" = "ops" ]; then
  START=$(date +%s%N)
  if docker exec postgres pg_isready -U "${POSTGRES_USER:-postgres}" --timeout=5 >/dev/null 2>&1; then
    END=$(date +%s%N)
    PG_LATENCY=$(( (END - START) / 1000000 ))ms
    PG_STATUS="pass"
    CONNS=$(docker exec postgres psql -U "${POSTGRES_USER:-postgres}" -tc "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d '[:space:]')
    STORAGE=$(docker exec postgres psql -U "${POSTGRES_USER:-postgres}" -tc "SELECT pg_database_size('webui');" 2>/dev/null | tr -d '[:space:]')
    PG_DETAIL="${CONNS:-?} conn / ${STORAGE:-?} bytes"
  else
    PG_STATUS="FAIL"
    PG_LATENCY="timeout"
    PG_DETAIL="pg_isready failed"
  fi
fi
printf "| PostgreSQL        | %-8s | %-7s | %-31s |\n" "$PG_STATUS" "$PG_LATENCY" "$PG_DETAIL"

echo ""

# Continue with remaining sections as needed...
# (Additional P1, P2, P3 checks follow same pattern)
```

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

- `/status` -- Quick triage command (inference, postgres, webui, docker ps)
- `./aixcl stack status` -- Quick stack status from CLI
- `./aixcl stack logs <service>` -- View service logs
- `/report` -- Issue-First workflow report
