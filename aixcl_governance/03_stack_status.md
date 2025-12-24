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

Profile: dev
Status: Running

Runtime Core (Strict - Always Enabled)
---------------------------------------
✅ ollama          Running
✅ llm-council     Running
✅ continue        Active     Connected (VS Code plugin)

Operational Services (Guided - Profile-Dependent)
--------------------------------------------------
✅ postgres        Running
✅ open-webui      Running
✅ pgadmin         Running
⏸  prometheus      Stopped    (not in 'dev' profile)
⏸  grafana         Stopped    (not in 'dev' profile)
⏸  watchtower      Stopped    (not in 'dev' profile)

Health Summary
--------------
Runtime Core: 3/3 healthy
Operational:  3/3 healthy (of 3 enabled)
Overall:      ✅ All critical services healthy
```

## Health Semantics

### Runtime Core Health
- **Critical**: All runtime core services must be healthy for AIXCL to function
- **Status indicators**: ✅ (running and healthy), ❌ (stopped or unhealthy)
- **Status meanings**:
  - ✅: Service is running and API/interface is responding
  - ❌: Service is not running or not responding
  - ⚠️: Service is starting up or experiencing issues

### Operational Services Health
- **Informational**: Operational services support but do not define the product
- **Status indicators**: ✅ (running and healthy), ❌ (stopped or unhealthy)
- **Status meanings**:
  - ✅: Service is running and functioning normally
  - ❌: Service is not running or not responding
  - ⚠️: Service is starting up or experiencing issues

## Profile-Specific Status

### core Profile
```
Runtime Core: 3/3 healthy
Operational:  0/0 (no operational services enabled)
```

### dev Profile
```
Runtime Core: 3/3 healthy
Operational:  3/3 healthy (postgres, open-webui, pgadmin)
```

### ops Profile
```
Runtime Core: 3/3 healthy
Operational:  6/6 healthy (observability stack: prometheus, grafana, loki, promtail, cadvisor, node-exporter)
```

### full Profile
```
Runtime Core: 3/3 healthy
Operational:  9/9 healthy (all services enabled)
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
   - Continue: Check plugin connectivity, not container (it's a VS Code extension)

4. **Output Format**
   - Default: Human-readable, grouped by category
   - Verbose: Include service details, ports, dependencies
   - JSON: Machine-readable format for automation

5. **Error Handling**
   - If runtime core is unhealthy, show clear error and suggest remediation
   - If operational services are unhealthy, show warning but do not block
   - Always distinguish between "not in profile" vs "failed to start"

