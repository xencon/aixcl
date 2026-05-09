# AIXCL Stack Status Output Specification

## Principles

- Reflect **runtime vs operational services** separation
- Show active profile
- Default output is human-friendly
- Verbose mode for details
- Machine-readable JSON optional
- Health semantics: runtime core health is critical, operational services health is informational

---

## Example Default Output

```
AIXCL Stack Status
==================

Profile: sys
Status: Running

Runtime Core (Strict - Always Enabled)
---------------------------------------
OK  ollama          Running
OK opencode        Active     Connected (VS Code plugin)

Configured Models
-----------------
  - OpenCode (VS Code) Models: qwen2.5-coder:1.5b, qwen2.5-coder:3b
  - OpenCode CLI       Config: AIXCL CLI (Ollama)   Model: qwen2.5-coder:1.5b

Operational Services (Guided - Profile-Dependent)
--------------------------------------------------
OK   postgres        Running
OK   open-webui      Running
OK   pgadmin         Running
OK   prometheus      Running
OK   grafana         Running

Health Summary
--------------
Runtime Core: 2/2 healthy
Operational:  5/5 healthy (of 5 enabled)
Overall:      OK All critical services healthy
```

## Health Semantics

### Runtime Core Health
- **Critical**: All runtime core services must be healthy for AIXCL to function
- **Status indicators**: OK (running and healthy), DOWN (stopped or unhealthy), WARN (starting or issues)
- **Status meanings**:
  - OK: Service is running and API/interface is responding
  - DOWN: Service is not running or not responding
  - WARN: Service is starting up or experiencing issues

### Operational Services Health
- **Informational**: Operational services support but do not define the product
- **Status indicators**: OK (running and healthy), DOWN (stopped or unhealthy), WARN (starting or issues), SKIP (not in profile)
- **Status meanings**:
  - OK: Service is running and functioning normally
  - DOWN: Service is not running or not responding
  - WARN: Service is starting up or experiencing issues
  - SKIP: Service is not enabled in the active profile

## Profile-Specific Status

### bld Profile
```
Runtime Core: 2/2 healthy
Operational:  7/7 healthy (postgres, prometheus, grafana, loki, cadvisor, node-exporter, postgres-exporter)
```

### sys Profile
```
Runtime Core: 2/2 healthy
Operational:  9/9 healthy (all services enabled: postgres, open-webui, pgadmin, prometheus, grafana, loki, cadvisor, node-exporter, postgres-exporter)
```

## AI Guidance for Status Implementation

When implementing stack status:

1. **Preserve Runtime Core Invariants**
   - Runtime core services must always be checked
   - Never show runtime core as optional or profile-dependent
   - Runtime core health is always critical

2. **Respect Service Boundaries**
   - Operational services may be stopped without affecting runtime core
   - Status output should clearly separate runtime vs operational
   - Do not imply operational services are required for runtime

3. **Health Check Semantics**
   - Runtime core: Use strict health checks (API must respond)
   - Operational services: Use lenient health checks (graceful degradation acceptable)
   - OpenCode: Check plugin connectivity, not container (it's a VS Code extension)

4. **Output Format**
   - Default: Human-readable, grouped by category
    - After Runtime Core, show **Configured Models**: OpenCode VS Code plugin, OpenCode CLI (no Ollama). Use green (✅) when models are configured, red (❌) when not, to match other services. OpenCode CLI in same format as `cn`: Config: <name>   Model: <current model> (prefer `cn -p "/info"` when available; else parse `opencode.json` provider settings)
   - Verbose: Include service details, ports, dependencies
   - JSON: Machine-readable format for automation

5. **Error Handling**
   - If runtime core is unhealthy, show clear error and suggest remediation
   - If operational services are unhealthy, show warning but do not block
   - Always distinguish between "not in profile" vs "failed to start"

