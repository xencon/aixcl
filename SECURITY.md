# AIXCL Security Architecture

## Overview

This document outlines the security architecture for AIXCL in adversarial environments, including known security debt, compensating controls, and threat model.

**Classification**: Internal Use Only  
**Last Updated**: 2026-05-11  
**Owner**: Security Team  
**Review Cycle**: Quarterly

---

## Security Posture Summary

| Control Category | Status | Evidence |
|-----------------|--------|----------|
| Network Security | Partial | Host firewall compensates for container host networking |
| Container Security | Partial | Some hardening, privileged containers remain |
| Data Protection | Partial | PII detection in place, encryption in progress |
| Access Control | Implemented | RBAC, human-in-the-loop approvals |
| Monitoring | Implemented | Prometheus/Grafana/Loki stack |
| Incident Response | Implemented | 4-hour RTO, automated containment |

**Overall Assessment**: Suitable for internal adversarial testing with documented compensating controls. **Not production-ready for customer-facing PCI DSS workloads without VM-level isolation.**

---

## Known Security Debt

### Critical (Cannot Fix Without Forking AIXCL)

| Debt | Reason | Impact | Compensating Control |
|------|--------|--------|---------------------|
| **Host Networking** | Architectural invariant in AIXCL | No container network isolation | Host-level iptables rules |
| **Privileged cAdvisor** | Requires host access for metrics | Full root access to host | Disable in production, use node-exporter only |
| **Docker Socket Exposure** | Alloy requires container log access | Container escape vector | Read-only socket mount, non-root user |
| **Root User Requirements** | Ollama/pgAdmin initialization | Privileged container execution | VM-level isolation for production |

### High (Addressable with Effort)

| Debt | Current State | Target | Timeline |
|------|--------------|--------|----------|
| Plaintext Credentials | [x] [x] DONE | Docker secrets | Phase 1.6 Complete |
| PostgreSQL SSL | [x] [x] DONE | sslmode=require | Phase 1.6 Complete |
| Secret Rotation | Manual via script | Automated 90-day rotation | Phase 2 |
| Code Signing | [x] [x] DONE | GPG-signed commits | Phase 2 Complete |

---

## Compensating Controls

**Legend:** Implemented | In Progress | Future Work

### 1. Host Firewall (iptables) [x]

Since containers use `network_mode: host`, we enforce network policies at the host level:

```bash
# Applied via scripts/security/host-firewall.sh

# Default: DROP all INPUT/FORWARD/OUTPUT
# Allow: Loopback only for service communication
# Allow: Established connections
# Block: All external access to service ports
```

**Effectiveness**: Medium  
**Limitations**: Bypassable if attacker gains host root access  
**Verification**: `iptables -L -n -v | grep DROP`

### 2. LLM Firewall (llm-firewall agent) Future

> **Status:** Not yet implemented. Documented as architectural target.

Planned capabilities:
- Prompt injection detection
- PII/PCI data redaction  
- Rate limiting (100 requests/hour)
- Output filtering
- Audit logging

**Planned Deployment**: localhost:11435 (proxy to Ollama on :11434)

**Projected Effectiveness**: High  
**Projected Limitations**: Adds latency (~50ms per request)  
**Projected Verification**: Check `llm_interactions` table in PostgreSQL

### 3. Threat Detection (threat-detector agent) Future

> **Status:** Not yet implemented. Documented as architectural target.

Planned capabilities:
- Model extraction attempts (high query volume)
- Data exfiltration (encoding requests)
- Privilege escalation (docker socket access)
- Anomalous behavior (after-hours access)

**Planned Alerting**: Slack #security channel

**Projected Effectiveness**: High  
**Projected False Positive Rate**: ~5% (tuned via ML)  
**Projected Verification**: Prometheus alerts, Loki logs

### 4. Audit Trail Future

> **Status:** Partially implemented. File-based audit logging active. PostgreSQL hash-chain target is future work.

Current implementation:
- Vault audit logs to file (`/vault/logs/audit.log`)
- Credential access timestamps recorded

Planned enhancements:
- Immutable logging to PostgreSQL with cryptographic chain
- LLM prompts/responses (sanitized)
- Human approval workflow
- Security events

**Projected Retention**: 30 days live, optional S3 archive

**Projected Effectiveness**: High  
**Projected Tamper Resistance**: Hash chain + append-only  
**Projected Verification**: `scripts/audit/verify-chain.sh`

### 5. Human-in-the-Loop Future

> **Status:** Not yet implemented. Documented as architectural target.

Planned capabilities:
- Critical actions require human approval:
  - git push to main/dev
  - rm -rf operations
  - Docker container deletion
  - Schema changes
  - External network requests

**Projected Approval SLA**: 4 hours (24 hour timeout)

**Projected Effectiveness**: Very High  
**Projected Limitation**: Requires 24/7 security team coverage  
**Projected Verification**: `human_approvals` table

---

## Adversarial Threat Model

### Threat Actors

| Actor | Motivation | Capability | Likelihood |
|-------|-----------|------------|------------|
| **Nation-State** | IP theft, disruption | High | Medium |
| **Organized Crime** | Ransomware, data sale | Medium-High | High |
| **Insider Threat** | Financial gain, revenge | High (legitimate access) | Medium |
| **Script Kiddies** | Opportunistic | Low | High |
| **Competitors** | Economic espionage | Medium | Low |

### Attack Vectors

#### 1. Prompt Injection → Data Exfiltration

**Path**: Malicious prompt → LLM → Sensitive data in response

**Mitigations**:
- llm-firewall injection detection
- Output PII scanning
- Rate limiting on encoding requests

**Residual Risk**: Medium (sophisticated jailbreaks possible)

#### 2. Container Escape → Host Compromise

**Path**: Exploit privileged container → Root on host

**Mitigations**:
- Remove/disable cAdvisor in production
- seccomp profiles
- read-only root filesystems

**Residual Risk**: High (if privileged containers required)

#### 3. Credential Theft → Lateral Movement

**Path**: Steal .env credentials → Access PostgreSQL/Ollama

**Mitigations**:
- Docker secrets (in progress)
- Host firewall (localhost only)
- Credential rotation

**Residual Risk**: Low (with secrets implementation)

#### 4. Model Extraction → IP Theft

**Path**: High-volume API queries → Reconstruct training data

**Mitigations**:
- Rate limiting (100 req/hour)
- Anomaly detection
- Query pattern analysis

**Residual Risk**: Medium (determined attacker with resources)

#### 5. Supply Chain Poisoning

**Path**: Malicious Ollama model → Backdoor in inference

**Mitigations**:
- Local LLM preference (reduces attack surface)
- Model provenance verification (future)
- Sandboxed execution

**Residual Risk**: Low (with local LLM usage)

### MITRE ATT&CK Mapping

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

---

## Security Controls by Layer

### Layer 1: Perimeter (Host)

- **Firewall**: iptables rules (localhost-only services)
- **Intrusion Detection**: Falco (container runtime security)
- **Monitoring**: Prometheus node-exporter
- **Hardening**: CIS Benchmark applied where possible

### Layer 2: Platform (AIXCL)

- **Secret Management**: Vault dynamic secrets (implemented)
- **LLM Security**: llm-firewall agent (future work)
- **Threat Detection**: threat-detector agent (future work)
- **Audit Logging**: Vault audit file (future: PostgreSQL hash-chain)

### Layer 3: Application (Built on Platform)

- **Input Validation**: Schema validation
- **Output Encoding**: Context-aware encoding
- **Authentication**: OAuth2/OIDC (external)
- **Authorization**: RBAC with principle of least privilege

---

## Control Mapping

Each attack vector maps to specific compensating controls:

| Attack Vector | Primary Control | Secondary Control | Tertiary Control |
|---------------|-----------------|-------------------|------------------|
| Prompt Injection | LLM Firewall (future) | Output PII scanning | Rate limiting |
| Container Escape | Disable privileged containers | seccomp + no-new-privileges | Host firewall |
| Credential Theft | Vault dynamic secrets | Host firewall (localhost) | Credential rotation |
| Model Extraction | Rate limiting (future) | Anomaly detection (future) | Query pattern analysis |
| Supply Chain | Local LLM preference | Image pinning | Provenance verification (future) |

---

## Agent Decision Guidance

When an agent detects potential threat activity, use this decision tree:

```
Is activity in threat detector rules? (future system)
|-- YES --> CRITICAL or HIGH?
|   |-- CRITICAL --> Page human, do not auto-remediate
|   \-- HIGH --> Alert security team, monitor
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
- [ ] Verify all implemented mitigations are still effective
- [ ] Check MITRE ATT&CK for newly published techniques relevant to AIXCL
- [ ] Review residual risk ratings against actual incident data
- [ ] Update control mapping if compensating controls changed
- [ ] Check that planned mitigations have realistic timelines
- [ ] Validate that agent decision guidance still matches current stack configuration

### On-Demand Review Triggers

- New service added to stack
- New upstream dependency introduced
- Security incident reveals new attack vector
- Major version update of runtime core (Ollama, OpenCode)
- Profile changes (new services enabled)

---

## Incident Response

### 4-Hour RTO Playbook

**T+0 minutes**: Automated Detection
- Threat-detector identifies anomaly
- Alert sent to Slack #security
- Incident ID generated

**T+5 minutes**: Automated Containment
- Emergency lockdown triggered (if critical)
- Compromised container stopped
- Network isolation applied

**T+30 minutes**: Human Assessment
- Security team acknowledges alert
- Forensic evidence preserved
- Scope of breach determined

**T+2 hours**: Eradication
- Root cause identified
- Malicious artifacts removed
- Vulnerability patched

**T+3 hours**: Recovery
- Services restored from clean backups
- Monitoring enhanced
- User notification (if required)

**T+4 hours**: Post-Incident
- Lessons learned documented
- Controls updated
- Team debrief

### Escalation Matrix

| Severity | Initial Response | Escalation | Notification |
|----------|-----------------|------------|--------------|
| CRITICAL | Auto-containment | Page on-call | Slack @channel + Phone |
| HIGH | Throttle + Alert | Security team | Slack #security |
| MEDIUM | Log + Monitor | Next business day | Weekly summary |
| LOW | Log only | None | Monthly report |

---

## Compliance Mapping

### PCI DSS Requirements

| Requirement | Status | Gap | Plan |
|-------------|--------|-----|------|
| 1. Network Security | Partial | Host networking | Compensating controls documented |
| 2. System Hardening | Partial | Privileged containers | Remove cAdvisor, secure Alloy |
| 3. Data Protection | Implemented | - | Vault secrets management (Phase 1.6) |
| 4. Encryption | Implemented | - | PostgreSQL SSL enabled (Phase 1.6) |
| 6. Secure Development | Implemented | - | Issue-First workflow, code review |
| 8. Authentication | Implemented | - | Human approval, RBAC |
| 10. Logging | Implemented | - | Comprehensive audit trail |
| 11. Testing | Planned | - | Penetration testing scheduled |

**Overall PCI DSS Readiness**: ~70%

**Blockers for Full Compliance**:
1. Host networking (requires VM-level isolation or AIXCL fork)
2. Privileged containers (requires architecture change)

**Recommendation**: Deploy customer-facing apps inside isolated VMs with hypervisor-level network policies.

---

## Security Roadmap

### Phase 1.5 (Completed - April 2026)

- [ ] LLM firewall agent
- [x] Host firewall rules
- [ ] Threat detection agent
- [x] Blast radius controller
- [x] SECURITY.md (this document)

### Phase 1.6 (Completed - May 2026)

- [x] Docker secrets management
- [x] Migration scripts from .env
- [x] PostgreSQL SSL encryption (sslmode=require)
- [x] Certificate generation and management
- [x] Update connection strings for SSL

### Phase 2 (Completed - May 2026)

- [x] GPG-signed commits
- [x] Podman migration (rootless)
- [x] Automated credential rotation (threat-adaptive with human-in-the-loop)
- [ ] Penetration testing
- [ ] Security training for team

### Phase 3 (Q3 2026)

- [x] Vault integration (HashiCorp)
- [x] Vault production mode (persistent storage, GPG-encrypted unseal keys)
- [ ] mTLS between services
- [ ] Zero-trust service mesh
- [ ] Red team exercises

### Phase 4 (Q4 2026)

- [ ] AIXCL fork for microsegmentation (decision pending)
- [ ] PCI DSS audit
- [ ] SOC 2 Type II certification
- [ ] Bug bounty program

---

## Vault Unseal Key Management

Vault now runs in **production server mode** (not `-dev`). Secrets persist to the
`aixcl-vault-data` volume across restarts. This requires operator management of unseal
keys and the root token.

### How Keys Are Stored

On first `./aixcl vault init` (or `./aixcl stack start` with Vault enabled):

1. `vault operator init` generates **5 unseal key shares** (threshold: 3-of-5) and a **root token**.
2. Both are GPG-encrypted with your git signing key and written to `.security/`:
   - `.security/vault-keys.gpg` - encrypted JSON containing all 5 key shares
   - `.security/vault-root-token.gpg` - encrypted root token string
3. Vault is immediately unsealed using key shares 1, 2, and 3.

The `.security/` directory is gitignored. The files are mode 600 and the directory is mode 700.

### Unseal on Restart

After a stack restart, Vault starts **sealed**. `stack start` automatically unseals it by
decrypting the key file using your GPG key. If your GPG key is not in the keyring (e.g.
fresh login, key on a hardware token), the auto-unseal will fail and you will see:

```
[ERROR] Failed to decrypt unseal keys. Is your GPG key available?
  Check: gpg --list-secret-keys
```

Manually unseal with:

```bash
./aixcl vault unseal
```

### Backup Requirement (Critical)

**Loss of all 5 key shares = permanent loss of all Vault data** (passwords, leases, audit
log, policies). There is no recovery path.

Recommended backup procedure:

```bash
# Export your GPG private key to a secure offline location
gpg --export-secret-keys --armor <your-key-id> > my-gpg-key.asc

# Copy .security/vault-keys.gpg to a separate encrypted USB or offline store
cp .security/vault-keys.gpg /path/to/secure/location/
```

The backup remains encrypted (requires your GPG private key to decrypt), so storing it
on a USB drive or a separate encrypted volume is safe.

### Root Token Usage

The root token is used only by `./aixcl vault init` and the Vault bootstrap agents. It is
never written to plaintext files or shell history. Scripts load it on demand by calling
`gpg --decrypt .security/vault-root-token.gpg`.

For day-to-day operations, prefer scoped AppRole tokens (already configured for
`aixcl-open-webui` and `aixcl-postgres-exporter`) over the root token.

---

## Security Team Contacts

| Role | Responsibility | Contact |
|------|---------------|---------|
| Maintainer | Security strategy, incident response, compliance | @sbadakhc (GitHub) |

**Emergency / Non-Emergency**: Open a security advisory at https://github.com/xencon/aixcl/security/advisories

---

## Security Debt Acceptance

This document acknowledges the following security debts that cannot be resolved without significant architectural changes:

1. **Host Networking**: AIXCL architectural invariant prevents container network isolation. Compensated by host-level firewall rules.

2. **Privileged Containers**: cAdvisor requires privileged mode for metrics. Compensated by disabling in production and using node-exporter.

3. **Root User Requirements**: Ollama/pgAdmin require root for initialization. Compensated by VM-level isolation for production.

**Risk Acceptance**: These debts are accepted for internal development and testing. Customer-facing deployments require VM-level isolation or AIXCL fork.

**Review Date**: 2026-08-01 (Quarterly)

---

## References

- [AIXCL Platform Invariants](/docs/architecture/governance/00_invariants.md)
- [Security Runbook](/docs/operations/security-runbook.md)
- [Incident Response Playbook](/docs/operations/incident-response.md)
- [Compensating Controls](/docs/security/compensating-controls.md)

---

**Document History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-01 | Security Team | Initial document |

**Next Review**: 2026-08-01