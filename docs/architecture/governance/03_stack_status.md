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
OK  ollama          Running
OK  council     Running
OK  continue        Active     Connected (VS Code plugin)

Configured Models
-----------------
  Ollama:             Default: llama3.2
  Council:            Chairman: llama3.2; Members: llama3.2, codellama
  Continue (VS Code): Models: llama3.2, codellama
  Continue CLI:       Config: .continue/cli-ollama.yaml; Models: llama3.2

Operational Services (Guided - Profile-Dependent)
--------------------------------------------------
OK   postgres        Running
OK   open-webui      Running
OK   pgadmin         Running
SKIP prometheus      Stopped    (not in 'dev' profile)
SKIP grafana         Stopped    (not in 'dev' profile)
SKIP watchtower      Stopped    (not in 'dev' profile)

Health Summary
--------------
Runtime Core: 3/3 healthy
Operational:  3/3 healthy (of 3 enabled)
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

### usr Profile
```
Runtime Core: 3/3 healthy
Operational:  1/1 healthy (postgres)
```

### dev Profile
```
Runtime Core: 3/3 healthy
Operational:  3/3 healthy (postgres, open-webui, pgadmin)
```

### ops Profile
```
Runtime Core: 3/3 healthy
Operational:  8/8 healthy (postgres, prometheus, grafana, loki, promtail, cadvisor, node-exporter, postgres-exporter)
```

### sys Profile
```
Runtime Core: 3/3 healthy
Operational:  10/10 healthy (all services enabled: postgres, open-webui, pgadmin, prometheus, grafana, loki, promtail, cadvisor, node-exporter, postgres-exporter, watchtower)
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
   - After Runtime Core, show **Configured Models**: Ollama default model, Council (chairman + members), Continue VS Code plugin models, Continue CLI config and models
   - Verbose: Include service details, ports, dependencies
   - JSON: Machine-readable format for automation

5. **Error Handling**
   - If runtime core is unhealthy, show clear error and suggest remediation
   - If operational services are unhealthy, show warning but do not block
   - Always distinguish between "not in profile" vs "failed to start"

