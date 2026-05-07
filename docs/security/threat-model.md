# Threat Model

## Overview

This document details the adversarial threat model for AIXCL. It is intended as **agent-readable reference material with human oversight** -- specific enough for automated systems to apply mitigations, structured for human security review and critique.

**Classification**: Internal Use Only  
**Last Updated**: 2026-05-07  
**Owner**: Security Team  
**Review Cycle**: Quarterly  
**Scope**: AIXCL runtime core (Ollama, OpenCode) and operational services

---

## Threat Actors

| Actor | Motivation | Capability | Likelihood | Priority |
|-------|-----------|------------|------------|----------|
| Nation-State | IP theft, disruption | High (advanced persistent threat) | Medium | P2 |
| Organized Crime | Ransomware, data sale | Medium-High (commodity tools + some custom) | High | P1 |
| Insider Threat | Financial gain, revenge | High (legitimate access) | Medium | P1 |
| Script Kiddies | Opportunistic | Low (public exploits only) | High | P3 |
| Competitors | Economic espionage | Medium (targeted reconnaissance) | Low | P3 |

### Actor Profiles

**Nation-State**
- Targets: Model weights, training data, internal architecture
- TTPs: Supply chain poisoning, long-term persistence, zero-day research
- Likely entry: Compromised upstream dependency or developer workstation

**Organized Crime**
- Targets: Ransomware payout, sale of credentials/data on dark web
- TTPs: Mass scanning, automated exploitation, credential stuffing
- Likely entry: Exposed service port, weak credential, known vulnerability

**Insider Threat**
- Targets: IP exfiltration, sabotage, unauthorized access
- TTPs: Legitimate access abuse, privilege escalation, data staging
- Likely entry: Already has access; bypasses perimeter controls

**Script Kiddies**
- Targets: Opportunistic defacement, botnet recruitment
- TTPs: Mass scanning for default credentials, known CVEs
- Likely entry: Accidentally exposed service, default password

**Competitors**
- Targets: Proprietary model configurations, performance data
- TTPs: Social engineering, job board reconnaissance, model extraction
- Likely entry: API abuse, insider recruitment

---

## Attack Vectors

### Vector 1 -- Prompt Injection to Data Exfiltration

**Description**

Attacker crafts malicious prompt that tricks LLM into revealing sensitive data or executing unintended actions.

**Path**
```
Attacker --> Malicious prompt --> LLM Firewall --> (bypass?) --> LLM --> Sensitive data in response --> Attacker
```

**Preconditions**
- Attacker has API access (legitimate or stolen credentials)
- LLM has been trained on or has access to sensitive data
- Prompt injection bypass technique is effective against current filters

**Mitigations**

| Control | Implementation | Effectiveness | Verification |
|---------|---------------|-------------|------------|
| Input filtering | llm-firewall prompt injection detection | High | Test with known injection payloads |
| Output scanning | PII/PCI regex + NER on LLM output | High | Test with fake SSN/credit card |
| Rate limiting | 100 requests/hour per source | Medium | Exceed limit, expect 429 |
| Audit logging | All prompts logged with hash chain | Detective only | Query `llm_interactions` |

**Residual Risk**: Medium  
Sophisticated jailbreaks (e.g., multi-turn, encoding, roleplay) may bypass current filters. Continuous model retraining on new bypass techniques required.

**MITRE ATT&CK Mapping**
- T1567 (Exfiltration via Web Service)
- T1059.004 (Command and Scripting Interpreter -- via prompt)

---

### Vector 2 -- Container Escape to Host Compromise

**Description**

Attacker exploits privileged container or container runtime vulnerability to gain root access on the host.

**Path**
```
Attacker --> Compromise container --> Exploit privileged mode / runtime bug --> Root on host --> Full system access
```

**Preconditions**
- Container runs in privileged mode OR
- Container runtime vulnerability exists OR
- Attacker has existing container access (insider or compromised service)

**AIXCL-Specific Context**

AIXCL has architectural constraints that increase this risk:
- `network_mode: host` -- containers share host network namespace
- cAdvisor requires privileged mode for host metrics
- Some initialization scripts require root for volume permissions

**Mitigations**

| Control | Implementation | Effectiveness | Verification |
|---------|---------------|-------------|------------|
| Disable privileged containers | Remove cAdvisor in production, use node-exporter | High | `podman ps --format "{{.Names}} {{.HostConfig.Privileged}}"` |
| seccomp profiles | Restrict available syscalls | Medium | Check `seccompProfile` in container inspect |
| read-only root fs | Mount root filesystem read-only | Medium | `podman inspect <container> --format "{{.HostConfig.ReadonlyRootfs}}"` |
| no-new-privileges | Prevent privilege escalation | Medium | `podman inspect <container> --format "{{.HostConfig.NoNewPrivileges}}"` |
| Host firewall | iptables blocks external container access | Medium | `iptables -L -n` shows DROP |

**Residual Risk**: High  
If privileged containers are required (cAdvisor, some init containers), escape is possible. VM-level isolation is the only complete mitigation for customer-facing deployments.

**MITRE ATT&CK Mapping**
- T1610 (Deploy Container -- if attacker deploys malicious container)
- T1059.004 (Unix Shell -- post-escape)
- T1071 (Application Layer Protocol -- C2 communication)

---

### Vector 3 -- Credential Theft to Lateral Movement

**Description**

Attacker steals credentials (from `.env`, Vault, or memory) and uses them to access other services.

**Path**
```
Attacker --> Steal credentials (env file, memory dump, side-channel) --> Access PostgreSQL/Ollama/Vault --> Lateral movement
```

**Preconditions**
- Credentials stored in accessible location
- Attacker has file system access or memory read capability
- No network segmentation prevents lateral movement

**AIXCL-Specific Context**

- Phase 1.6 completed: Static `.env` passwords migrated to Vault KV
- Dynamic secrets with TTL reduce blast radius
- Host networking means services are accessible via localhost -- credential theft enables immediate access

**Mitigations**

| Control | Implementation | Effectiveness | Verification |
|---------|---------------|-------------|------------|
| Vault dynamic secrets | PostgreSQL credentials with 1-hour TTL | High | `./aixcl vault credentials` shows recent timestamps |
| Host firewall | localhost-only service exposure | Medium | External connections to service ports are DROP |
| Credential rotation | Automated 90-day rotation (Phase 2) | Medium | Check rotation log |
| Bootstrap password isolation | Vault KV with auto-generated passwords | High | `./aixcl vault passwords` shows managed secrets |
| Non-root service execution | Services run as dedicated users | Low | `podman ps --format "{{.Names}} {{.User}}"` |

**Residual Risk**: Low  
With Vault dynamic secrets implemented, credential theft window is limited to TTL (1 hour for app, 15 minutes for admin). Host networking still allows immediate lateral movement if credentials are valid.

**MITRE ATT&CK Mapping**
- T1552 (Unsecured Credentials)
- T1078 (Valid Accounts)
- T1021 (Remote Services -- PostgreSQL, Ollama API)

---

### Vector 4 -- Model Extraction to IP Theft

**Description**

Attacker uses high-volume, carefully crafted API queries to reconstruct model weights or extract proprietary training data.

**Path**
```
Attacker --> High-volume API queries --> Model responds with encoded weights/data --> Reconstruct model offline
```

**Preconditions**
- Attacker has API access (legitimate or stolen)
- Model is vulnerable to extraction (smaller models more susceptible)
- Rate limiting insufficient to prevent reconstruction

**AIXCL-Specific Context**

AIXCL uses smaller models (Qwen 0.5B -- 3B parameters) for local development. Smaller models are more easily extractable via API queries than large foundation models.

**Mitigations**

| Control | Implementation | Effectiveness | Verification |
|---------|---------------|-------------|------------|
| Rate limiting | 100 requests/hour per source | Medium | Exceed limit, expect 429 |
| Anomaly detection | Threat detector flags high-volume patterns | High | Prometheus alert `AnomalousQueryVolume` |
| Query pattern analysis | Detect systematic extraction patterns | Medium | Review Loki logs for repeated similar queries |
| Local LLM preference | Reduces attack surface vs public APIs | Low | Stack configured for localhost only |

**Residual Risk**: Medium  
Determined attacker with resources can distribute queries across sources or operate within rate limits. Query pattern analysis can catch naive extraction but not sophisticated distributed attacks.

**MITRE ATT&CK Mapping**
- T1496 (Resource Hijacking -- model inference as resource)
- T1567 (Exfiltration Over Web Service)

---

### Vector 5 -- Supply Chain Poisoning

**Description**

Attacker compromises upstream dependency (model, container image, package) to introduce backdoor or malicious behavior.

**Path**
```
Attacker --> Compromise upstream (model repo, Docker Hub, package registry) --> Malicious artifact pulled by AIXCL --> Backdoor active
```

**Preconditions**
- AIXCL pulls from compromised upstream source
- No artifact verification (checksum, signature, provenance)
- Attacker has upstream access (compromised maintainer account, registry)

**AIXCL-Specific Context**

- Models pulled via Ollama (Ollama registry) or HuggingFace (`hf` CLI)
- Container images from Docker Hub / Quay.io
- No current artifact signing or provenance verification

**Mitigations**

| Control | Implementation | Effectiveness | Verification |
|---------|---------------|-------------|------------|
| Local LLM preference | Reduces exposure to public registries | Low | Stack uses localhost inference |
| Model provenance verification | **Planned** -- checksum verification on pull | N/A | Not yet implemented |
| Sandboxed execution | **Planned** -- model execution in restricted environment | N/A | Not yet implemented |
| Image pinning | Use specific image digests, not `latest` | Medium | Check `docker-compose.yml` for `sha256:` references |
| Minimal base images | Use distroless or minimal base where possible | Low | Review `FROM` lines in Dockerfiles |

**Residual Risk**: Low  
With local LLM usage, attack surface is reduced. However, no provenance verification means compromise is possible if upstream is breached. Future work in Phase 3/4.

**MITRE ATT&CK Mapping**
- T1195 (Supply Chain Compromise)
- T1195.001 (Software Supply Chain)
- T1195.002 (Hardware Supply Chain -- if GPU driver compromised)

---

## MITRE ATT&CK Mapping

### Techniques in Scope

| Technique | Tactic | Description | AIXCL Mitigation | Status |
|-----------|--------|-------------|-----------------|--------|
| T1059.004 | Execution | Unix Shell via prompt injection | seccomp, no-new-privileges, llm-firewall | Active |
| T1071 | C2 | App layer protocol for exfiltration | Host firewall blocks external egress | Active |
| T1083 | Discovery | File and directory discovery | Read-only containers, host firewall | Active |
| T1087 | Discovery | Account discovery | /etc/passwd not mounted | Active |
| T1098 | Persistence | Account manipulation | Human approval for user changes | Active |
| T1136 | Persistence | Create account | Human approval for account creation | Active |
| T1496 | Impact | Resource hijacking (model extraction) | Rate limiting, anomaly detection | Active |
| T1567 | Exfiltration | Exfiltration over web service | LLM output filtering, PII detection | Active |
| T1552 | Credential Access | Unsecured credentials | Vault dynamic secrets, host firewall | Active |
| T1078 | Defense Evasion | Valid accounts | Credential rotation, audit logging | Active |
| T1021 | Lateral Movement | Remote services | Host firewall localhost-only | Active |
| T1610 | Lateral Movement | Deploy container | Disable privileged, seccomp | Active |
| T1195 | Resource Development | Supply chain compromise | Local LLM, image pinning | Partial |

### Coverage Gaps

| Technique | Why Not Covered | Planned Mitigation | Timeline |
|-----------|-----------------|-------------------|----------|
| T1055 (Process Injection) | Not applicable to containerized LLM | seccomp already limits | N/A |
| T1056 (Input Capture) | Requires host compromise first | Host firewall + no-new-privileges | Active |
| T1074 (Data Staged) | Post-exploitation only | Audit logging + threat detection | Active |
| T1090 (Proxy) | Requires network access | Host firewall blocks egress | Active |
| T1105 (Tool Transfer) | Requires host compromise | Read-only containers | Active |
| T1213 (Exfiltration over C2) | Requires C2 channel | Host firewall + anomaly detection | Active |
| T1560 (Archive Collected Data) | Post-exploitation | Audit logging | Active |
| T1568 (Dynamic Resolution) | Requires external DNS access | Host firewall (limited effect) | Partial |

---

## Residual Risk Summary

| Attack Vector | Likelihood | Impact | Risk | Priority |
|---------------|-----------|--------|------|----------|
| Prompt Injection --> Data Exfiltration | High | Medium | **Medium** | P1 |
| Container Escape --> Host Compromise | Medium | High | **High** | P1 |
| Credential Theft --> Lateral Movement | Medium | Medium | **Medium** | P2 |
| Model Extraction --> IP Theft | Medium | High | **Medium** | P1 |
| Supply Chain Poisoning | Low | High | **Low** | P3 |

**Overall Risk Posture**: Medium-High

The highest residual risk is **Container Escape** due to architectural constraints (host networking, privileged containers for cAdvisor). This is accepted for internal testing but requires VM-level isolation for production customer-facing deployments.

---

## Control Mapping

Each attack vector maps to specific compensating controls:

| Attack Vector | Primary Control | Secondary Control | Tertiary Control |
|---------------|-----------------|-------------------|------------------|
| Prompt Injection | LLM Firewall | Output PII scanning | Rate limiting |
| Container Escape | Disable privileged containers | seccomp + no-new-privileges | Host firewall |
| Credential Theft | Vault dynamic secrets | Host firewall (localhost) | Credential rotation |
| Model Extraction | Rate limiting | Anomaly detection | Query pattern analysis |
| Supply Chain | Local LLM preference | Image pinning | Provenance verification (future) |

---

## Agent Decision Guidance

When an agent detects potential threat activity, use this decision tree:

```
Is activity in threat detector rules?
|-- YES --> CRITICAL or HIGH?
|   |-- CRITICAL --> Auto-contain + page on-call
|   \-- HIGH --> Throttle + alert security team
\-- NO --> Is it in anomaly detection?
    |-- YES --> Log + monitor (MEDIUM)
    \-- NO --> Log only (LOW)
        \-- But if pattern persists >1 hour --> Escalate to MEDIUM
```

**Never auto-remediate without human approval if:**
- Action affects runtime core services (Ollama, PostgreSQL)
- Action modifies firewall rules
- Action deletes containers or volumes
- Action accesses git repositories

---

## Verification

### Quarterly Threat Model Review Checklist

- [ ] Review all attack vectors for new preconditions (new services, new dependencies)
- [ ] Verify all mitigations are still implemented and effective
- [ ] Check MITRE ATT&CK for newly published techniques relevant to AIXCL
- [ ] Review residual risk ratings against actual incident data
- [ ] Update control mapping if compensating controls changed
- [ ] Check that planned mitigations (provenance verification, sandboxing) have timelines
- [ ] Validate that agent decision guidance still matches current stack configuration

### On-Demand Review Triggers

- New service added to stack
- New upstream dependency introduced
- Security incident reveals new attack vector
- Major version update of runtime core (Ollama, OpenCode)
- Profile changes (new services enabled)

---

## Cross-References

- [Compensating Controls](/docs/security/compensating-controls.md) -- Detailed control specifications and verification
- [Incident Response Playbook](/docs/operations/incident-response.md) -- Response procedures when threats materialize
- [Security Runbook](/docs/operations/security-runbook.md) -- Day-to-day operational checks
- [AIXCL Platform Invariants](/docs/architecture/governance/00_invariants.md) -- Architectural constraints affecting threat model
- [Agentic Guidance](/docs/architecture/governance/01_ai_guidance.md) -- Agent behavior rules

---

**Document History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-07 | Security Team | Initial document -- adversarial threat model |

**Next Review**: 2026-08-07
