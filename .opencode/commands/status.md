---
description: Quick AIXCL stack status check showing service health and active engine
agent: agent-context
---

# /status Command

Quickly checks the AIXCL stack status and displays a summary of service health and the currently active inference engine.

## Usage

```
/status
```

## What It Does

1. Runs `./aixcl stack status` to get current stack state
2. Extracts key information (profile, services, engine)
3. Displays a quick summary table
4. Shows health of critical services
5. Reports active inference engine

## Report Format

```
════════════════════════════════════════════════════════════════
  AIXCL Stack Status
════════════════════════════════════════════════════════════════

| Component | Value |
|-----------|-------|
| Profile   | sys   |
| Services  | 12/12 healthy |
| Engine    | llama.cpp |
| Status    | ✅ Running |

Runtime Core
| Engine | Status |
|--------|--------|
| Ollama | ⏸️ Standby |
| vLLM   | ⏸️ Standby |
| llama.cpp | ✅ Active |

Key Services
| Service | Status |
|---------|--------|
| Open WebUI | ✅ |
| PostgreSQL | ✅ |
| Prometheus | ✅ |
| Grafana | ✅ |
```

## When to Use

- Quick health check before starting work
- Verify stack is running
- Check which engine is active
- Before switching engines
- After stack operations (start/stop/restart)

## Output Details

### Status Indicators
- ✅ Healthy - Service running normally
- ⏸️ Standby - Available but not active
- ❌ Down - Service not responding
- ⚠️ Warning - Service running with issues

### Profile Information
Shows which profile is active (usr, dev, ops, sys)

### Engine Status
Shows which inference engine is currently active and which are on standby

## Related Commands

- `/platform` - Full platform status report
- `./aixcl stack status` - Native CLI status command
- `./aixcl stack start` - Start the stack
- `./aixcl stack stop` - Stop the stack
- `./aixcl stack logs` - View service logs

## See Also

- `docs/user/usage.md` - User guide
- `docs/operations/monitoring.md` - Monitoring setup