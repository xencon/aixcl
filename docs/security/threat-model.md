# AIXCL Threat Model

**Classification:** Internal Use Only  
**Last Updated:** 2026-06-10  
**Owner:** Security Team  
**Review Cycle:** Quarterly

---

## 1. Threat Actors

| Actor | Motivation | Capability | Likelihood |
|-------|-----------|------------|------------|
| Nation-State | IP theft, disruption | High | Medium |
| Organized Crime | Ransomware, data sale | Medium-High | High |
| Insider Threat | Financial gain, revenge | High (legitimate access) | Medium |
| Script Kiddies | Opportunistic | Low | High |
| Competitors | Economic espionage | Medium | Low |

## 2. Attack Vectors

### 2.1 Prompt Injection -- Data Exfiltration

**Path:** Malicious prompt -- LLM -- Sensitive data in response

**Mitigations:**
- LLM firewall injection detection (planned)
- Output PII scanning
- Rate limiting on encoding requests

**Residual Risk:** Medium (sophisticated jailbreaks possible)

### 2.2 Container Escape -- Host Compromise

**Path:** Exploit privileged container -- Root on host

**Mitigations:**
- Remove/disable cAdvisor in production
- seccomp profiles
- read-only root filesystems

**Residual Risk:** High (if privileged containers required)

### 2.3 Credential Theft -- Lateral Movement

**Path:** Steal secrets -- Access PostgreSQL/Ollama

**Mitigations:**
- HashiCorp Vault dynamic secrets (implemented)
- Host firewall (localhost only)
- Credential rotation

**Residual Risk:** Low (with Vault implementation)

### 2.4 Model Extraction -- IP Theft

**Path:** High-volume API queries -- Reconstruct training data

**Mitigations:**
- Rate limiting (100 req/hour planned)
- Anomaly detection
- Query pattern analysis

**Residual Risk:** Medium (determined attacker with resources)

### 2.5 Supply Chain Poisoning

**Path:** Malicious model -- Backdoor in inference

**Mitigations:**
- Local LLM preference (reduces attack surface)
- Sandboxed execution

**Residual Risk:** Low (with local LLM usage)

## 3. MITRE ATT&CK Mapping

| Technique | Tactic | Mitigation |
|-----------|--------|------------|
| T1059.004 (Unix Shell) | Execution | seccomp, no-new-privileges |
| T1071 (App Layer Protocol) | C2 | Host firewall blocks external egress |
| T1083 (File & Dir Discovery) | Discovery | Read-only containers, host firewall |
| T1087 (Account Discovery) | Discovery | /etc/passwd not mounted |
| T1098 (Account Manipulation) | Persistence | Human approval for user changes |
| T1136 (Create Account) | Persistence | Human approval for account creation |
| T1496 (Resource Hijacking) | Impact | Rate limiting, anomaly detection |
| T1567 (Exfiltration) | Exfiltration | LLM output filtering, PII detection |

## 4. Compensating Controls Cross-Reference

| Control | Status | Document |
|---------|--------|----------|
| Host Firewall (iptables) | Implemented | [compensating-controls.md](compensating-controls.md) |
| LLM Firewall | Planned | [compensating-controls.md](compensating-controls.md) |
| Threat Detection | Planned | [compensating-controls.md](compensating-controls.md) |
| Audit Trail | Partial | [compensating-controls.md](compensating-controls.md) |
| Human-in-the-Loop | Planned | [compensating-controls.md](compensating-controls.md) |

## 5. References

- [SECURITY.md](/SECURITY.md) -- Full security architecture and posture
- [Compensating Controls](compensating-controls.md) -- Control specifications and verification
- [Incident Response](../operations/incident-response.md) -- 4-hour RTO playbook
- [Security Runbook](../operations/security-runbook.md) -- Operational security checks
- [Platform Invariants](../architecture/governance/00_invariants.md) -- Architectural constraints

---

**Remember:** This threat model is a living document. Review quarterly or after any security incident.
