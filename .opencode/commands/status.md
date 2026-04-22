---
description: Quick triage command — 5-second pulse check for the most critical services
description-short: Fast status check for inference, postgres, webui, and containers
agent: agent-context
---

# /status Command

Quick triage command. No logs, no security, no Prometheus — just the four things that must work for AIXCL to function. Runs in under 5 seconds.

## Usage

Run this slash command:
```
/status
```

## What It Does

1. Lists running Docker containers (`docker ps`)
2. Checks inference engine health (`curl http://127.0.0.1:11434/v1/models`)
3. Checks PostgreSQL readiness (`docker exec postgres pg_isready`)
4. Checks Open WebUI health (`curl http://127.0.0.1:8080/health`) if profile includes it
5. Prints single-row status table

## Output

```
| Service | Status | Latency | Note |
|---------|--------|---------|------|
| docker ps | pass | 120ms | 13 containers running |
| inference | pass | 8ms | Qwen/Qwen2.5-Coder-0.5B-Instruct |
| postgres | pass | 45ms | 5432 accepting connections |
| webui    | N/A  | -    | N/A (profile: ops) |
```

## Rules

- If any check fails, print **FAIL** and stop. The user must fix it before anything else.
- If inference API responds but returns no models, print **warn** with `No models loaded`.
- If postgres responds but `docker exec` fails, print **FAIL** with `Container not running`.
- If Open WebUI is not in the active profile, print **N/A**.
- End with one line: `Next: /platform for full report` or `Next: ./aixcl stack logs <service>` if a check failed.

## Profile-Aware Filtering

| Profile | Checks |
|---------|--------|
| usr | docker ps, inference, postgres |
| dev | docker ps, inference, postgres, webui |
| ops | docker ps, inference, postgres |
| sys | docker ps, inference, postgres, webui |

## Commands Used

```bash
# Containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Inference
curl -sf --max-time 5 http://127.0.0.1:11434/v1/models | jq -r '.data[0].id // "empty"'

# PostgreSQL
docker exec postgres pg_isready -U $POSTGRES_USER --timeout=5

# Open WebUI
curl -sf --max-time 5 http://127.0.0.1:8080/health
```

## When to Use

- First thing after `./aixcl stack start`
- Before running inference
- Every 30 minutes during active development
- When something feels slow or broken

## Related

- `/platform` — Full health report with P1/P2/P3 tiers
- `./aixcl stack status` — Docker-native service list
- `/report` — Issue-First workflow report
