# Compensating Controls Reference

## Overview

This document specifies the compensating controls that offset known security debts in AIXCL. It is intended as **agent-executable reference material with human-in-the-loop oversight**.

**Classification**: Internal Use Only  
**Last Updated**: 2026-05-07  
**Owner**: Security Team  
**Review Cycle**: Quarterly  
**Scope**: AIXCL runtime and operational services

---

## 1. Host Firewall (iptables)

### Purpose

Container-level network isolation is impossible because AIXCL uses `network_mode: host` as an architectural invariant. The host firewall enforces network policies at the OS level.

### Configuration

Applied via `scripts/security/host-firewall.sh`:

```bash
#!/bin/bash
# Host Firewall for AIXCL
# Run as root or via sudo

# Flush existing rules
iptables -F
iptables -X

# Default policy: DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Block all external access to service ports
# Services bind to localhost only; this is defense in depth
for port in 3000 8080 8081 8086 9090 9093 5432 11434 11435; do
    iptables -A INPUT -p tcp --dport $port -j DROP
    iptables -A OUTPUT -p tcp --dport $port -d ! 127.0.0.1 -j DROP
done

# Allow SSH if needed (customize per environment)
# iptables -A INPUT -p tcp --dport 22 -s <admin-network> -j ACCEPT
```

### Verification

| Check | Command | Expected Result |
|-------|---------|---------------|
| Default policy | `iptables -L -n \| grep Policy` | `Chain INPUT (policy DROP)`, `Chain FORWARD (policy DROP)`, `Chain OUTPUT (policy DROP)` |
| Loopback allowed | `iptables -L INPUT -n \| grep lo` | `ACCEPT all -- 0.0.0.0/0 0.0.0.0/0` with `lo` |
| Service ports blocked | `iptables -L INPUT -n \| grep 11434` | `DROP tcp -- 0.0.0.0/0 0.0.0.0/0 tcp dpt:11434` |

### Failure Modes

| Symptom | Cause | Agent Action | Human Action |
|---------|-------|------------|--------------|
| `iptables: command not found` | iptables not installed | Alert human | Install iptables package |
| Rules not persisting after reboot | No persistent config | Alert human | Add to `/etc/iptables/rules.v4` or equivalent |
| Service unreachable externally | Intended behavior | Log expected | None unless external access required |
| Host firewall bypassed | Attacker gained root | Trigger incident response | Manual investigation per incident-response.md |

### Agent vs Human Responsibilities

| Task | Agent | Human |
|------|-------|-------|
| Apply rules on startup | Automated via stack start | Verify once |
| Verify rules active | Check every 5 minutes in ops/sys profiles | Review weekly |
| Modify rules | **NEVER** -- requires approval | Only after documented change request |
| Diagnose failures | Run verification commands, report | Decide on remediation |

---

## 2. LLM Firewall (llm-firewall agent)

### Purpose

Sanitizes all LLM interactions to prevent prompt injection, PII leakage, and data exfiltration through the inference API.

### Deployment

- **Location**: `localhost:11435` (proxy to Ollama on `:11434`)
- **Implementation**: `.opencode/agents/llm-firewall.md`
- **Integration**: All LLM requests route through this proxy

### Capabilities

| Capability | Description | Verification |
|------------|-------------|------------|
| Prompt injection detection | Pattern matching + heuristic analysis on input prompts | Send known injection payload, expect block |
| PII/PCI redaction | Regex + NER-based detection on input and output | Send test SSN/credit card, expect redaction |
| Rate limiting | 100 requests/hour per source IP | Exceed limit, expect HTTP 429 |
| Output filtering | Block encoded/escaped output patterns | Request base64-encoded response, expect block |
| Audit logging | Every interaction logged to PostgreSQL | Query `llm_interactions` table |

### Verification Commands

```bash
# Check proxy is listening
ss -tlnp | grep 11435

# Test rate limiting (requires 101+ requests)
# See scripts/security/test-rate-limit.sh

# Check audit log
psql -U postgres -d aixcl -c "SELECT COUNT(*) FROM llm_interactions WHERE created_at > NOW() - INTERVAL '1 hour';"
```

### Failure Modes

| Symptom | Cause | Agent Action | Human Action |
|---------|-------|------------|--------------|
| Port 11435 not listening | llm-firewall not running | Restart service | Investigate why it stopped |
| False positive (legitimate prompt blocked) | Overly aggressive filter | Log and alert | Tune filter rules |
| False negative (malicious prompt passed) | Bypass technique | Escalate immediately | Review logs, update patterns |
| High latency (>200ms) | Filter complexity | Report metric | Acceptable up to ~50ms baseline |

### Agent vs Human Responsibilities

| Task | Agent | Human |
|------|-------|-------|
| Monitor proxy health | Check port every 60 seconds | Review dashboards weekly |
| Respond to alerts | Auto-throttle if rate limit exceeded | Investigate sustained attacks |
| Update filter rules | **NEVER** | After security review only |
| Tune false positive rate | Report statistics | Adjust thresholds quarterly |

---

## 3. Threat Detection (threat-detector agent)

### Purpose

Continuous monitoring for anomalous behavior targeting the AIXCL runtime and infrastructure.

### Deployment

- **Implementation**: `.opencode/agents/threat-detector.md`
- **Alerting**: Slack #security channel
- **Metrics**: Prometheus alerts, Loki logs

### Detection Rules

| Rule | Trigger | Severity | Response |
|------|---------|----------|----------|
| Model extraction attempt | >50 API queries in 10 minutes from single source | HIGH | Throttle + alert |
| Data exfiltration pattern | Encoding request (base64, hex, rot13) in prompt | HIGH | Block + alert |
| Docker socket access | Process attempts to read `/var/run/docker.sock` | CRITICAL | Alert + log |
| Privilege escalation | Container runs with `--privileged` or cap_add | CRITICAL | Alert + log |
| After-hours access | API request outside business hours (configurable) | MEDIUM | Log + monitor |
| Anomalous query volume | >500 requests/hour (10x baseline) | HIGH | Throttle + alert |

### Verification

```bash
# Check threat-detector agent is active
# (Agent runs as part of operational stack)
./aixcl stack status | grep threat-detector

# Verify Prometheus alert rules
promtool check rules prometheus/alerts.yml

# Check Slack webhook configuration
# Defined in .env: THREAT_DETECTOR_SLACK_WEBHOOK
```

### Failure Modes

| Symptom | Cause | Agent Action | Human Action |
|---------|-------|------------|--------------|
| No alerts in Slack | Webhook misconfigured | Test webhook | Verify URL in .env |
| High false positive rate (~>10%) | ML model drift | Report statistics | Retune model |
| Missed detection | Bypass technique | Escalate if discovered | Review logs, update rules |
| Agent not running | Crash or OOM | Restart service | Investigate resource usage |

### Agent vs Human Responsibilities

| Task | Agent | Human |
|------|-------|-------|
| Monitor metrics | Continuous | Review alerts |
| Respond to HIGH/CRITICAL | Alert immediately | Acknowledge within 30 minutes |
| Tune detection thresholds | Report false positive metrics | Adjust quarterly |
| Update detection rules | **NEVER** | After security review |

---

## 4. Audit Trail

### Purpose

Immutable logging of all security-relevant events with cryptographic integrity verification.

### Implementation

- **Storage**: PostgreSQL `audit_log` table
- **Chain**: Cryptographic hash chain (each entry hashes previous entry's hash)
- **Retention**: 30 days live, optional S3 archive
- **Verification**: `scripts/audit/verify-chain.sh`

### Schema

| Field | Type | Description |
|-------|------|-------------|
| id | SERIAL PRIMARY KEY | Sequential entry ID |
| timestamp | TIMESTAMP WITH TIME ZONE | Event time |
| actor | TEXT | Agent or human identifier |
| action | TEXT | Action performed |
| resource | TEXT | Target resource |
| outcome | TEXT | SUCCESS / FAILURE / DENIED |
| prev_hash | TEXT | Hash of previous entry |
| entry_hash | TEXT | SHA-256 of this entry's content |
| metadata | JSONB | Additional context |

### Verification Commands

```bash
# Verify hash chain integrity
./scripts/audit/verify-chain.sh

# Check latest entries
psql -U postgres -d aixcl -c "SELECT id, timestamp, actor, action, outcome FROM audit_log ORDER BY id DESC LIMIT 10;"

# Check for gaps in sequence
psql -U postgres -d aixcl -c "SELECT generate_series AS missing_id FROM generate_series(1, (SELECT MAX(id) FROM audit_log)) EXCEPT SELECT id FROM audit_log;"
```

### Expected Output (verify-chain.sh)

```
Verifying audit chain...
Total entries: 12345
Chain intact: YES
Last hash: a1b2c3d4...
Verification complete. Chain valid.
```

### Failure Modes

| Symptom | Cause | Agent Action | Human Action |
|---------|-------|------------|--------------|
| Chain broken (hash mismatch) | Tampering or corruption | **HALT** all agent activity | Immediate investigation |
| Missing entries | Database failure or rollback | **HALT** all agent activity | Database forensics |
| Verification script fails | Missing dependency | Alert human | Fix script environment |
| High write latency | Database under load | Buffer and retry | Scale database if persistent |

### Agent vs Human Responsibilities

| Task | Agent | Human |
|------|-------|-------|
| Write audit entry | Every action before execution | None (automated) |
| Verify chain | Daily automated check | Review weekly report |
| Investigate broken chain | **HALT** and alert | Immediate response |
| Archive to S3 | Automated after 30 days | Verify monthly |

---

## 5. Human-in-the-Loop

### Purpose

Critical actions require human approval to prevent irreversible or high-impact automated mistakes.

### Approval Gates

| Action | Severity | Approval SLA | Timeout |
|--------|----------|--------------|---------|
| git push to main or dev | CRITICAL | 4 hours | 24 hours |
| `rm -rf` operations | CRITICAL | 4 hours | 24 hours |
| Docker container deletion | HIGH | 4 hours | 24 hours |
| Database schema changes | HIGH | 4 hours | 24 hours |
| External network requests | MEDIUM | Next business day | 72 hours |
| Credential rotation | HIGH | 4 hours | 24 hours |

### Implementation

- **Queue**: PostgreSQL `human_approvals` table
- **Notification**: Slack #security + email
- **Approval Interface**: CLI (`./aixcl security approve <request-id>`) or GitHub PR review
- **Timeout**: Request auto-denied if no response within timeout period

### Schema

| Field | Type | Description |
|-------|------|-------------|
| id | UUID PRIMARY KEY | Request identifier |
| timestamp | TIMESTAMP WITH TIME ZONE | Request time |
| actor | TEXT | Agent or system requesting |
| action | TEXT | Action description |
| severity | TEXT | CRITICAL / HIGH / MEDIUM |
| status | TEXT | PENDING / APPROVED / DENIED / TIMEOUT |
| reviewer | TEXT | Human who responded |
| response_time | TIMESTAMP WITH TIME ZONE | When human responded |
| justification | TEXT | Reason for approval/denial |

### Verification Commands

```bash
# List pending approvals
psql -U postgres -d aixcl -c "SELECT id, actor, action, severity, status FROM human_approvals WHERE status = 'PENDING';"

# Check approval statistics
psql -U postgres -d aixcl -c "SELECT severity, status, COUNT(*) FROM human_approvals GROUP BY severity, status;"

# Check average response time
psql -U postgres -d aixcl -c "SELECT AVG(EXTRACT(EPOCH FROM (response_time - timestamp))) / 60 AS avg_minutes FROM human_approvals WHERE status IN ('APPROVED', 'DENIED');"
```

### Failure Modes

| Symptom | Cause | Agent Action | Human Action |
|---------|-------|------------|--------------|
| Request timed out | No human response | Auto-deny, log | Review queue backlog |
| Approval without review | Human clicked approve without reading | Flag in audit | Retrain reviewer |
| Queue backlog >10 | High activity or understaffing | Escalate to on-call | Adjust staffing or SLAs |
| Critical request auto-approved | Bug in approval logic | **HALT** all automation | Emergency review |

### Agent vs Human Responsibilities

| Task | Agent | Human |
|------|-------|-------|
| Submit approval request | Automated before critical action | Receive notification |
| Approve or deny | **NEVER** -- only human can approve | Review context, decide |
| Escalate overdue | Auto-escalate at 50% SLA | Respond to escalation |
| Audit approvals | Report statistics | Review quarterly |

---

## Control Interactions

The five controls work as a defense-in-depth stack:

```
Attacker
   |
   v
[Host Firewall]  <-- Blocks network-level access
   |
   v
[LLM Firewall]   <-- Blocks malicious prompts / data exfiltration
   |
   v
[Threat Detector] <-- Detects anomalous patterns
   |
   v
[Audit Trail]    <-- Records everything for forensics
   |
   v
[Human Approval] <-- Gates critical actions
```

No single control is sufficient. Controls 1-3 are preventive, control 4 is detective, control 5 is corrective.

---

## Verification Summary

Run these checks to verify all compensating controls are operational:

```bash
#!/bin/bash
# Quick verification of all compensating controls
# Run this daily in ops/sys profiles

echo "=== Host Firewall ==="
iptables -L -n | grep -E "Policy|DROP" | head -5

echo "=== LLM Firewall ==="
ss -tlnp | grep 11435 || echo "FAIL: LLM firewall not listening"

echo "=== Threat Detector ==="
./aixcl stack status | grep threat-detector || echo "FAIL: Threat detector not in status"

echo "=== Audit Chain ==="
./scripts/audit/verify-chain.sh | grep "Chain intact" || echo "FAIL: Audit chain broken"

echo "=== Pending Approvals ==="
psql -U postgres -d aixcl -c "SELECT COUNT(*) FROM human_approvals WHERE status = 'PENDING';"
```

---

## References

- [AIXCL Platform Invariants](/docs/architecture/governance/00_invariants.md)
- [Incident Response Playbook](/docs/operations/incident-response.md)
- [Threat Model](/docs/security/threat-model.md)
- [Security Runbook](/docs/operations/security-runbook.md)
- [Agentic Guidance](/docs/architecture/governance/01_ai_guidance.md)

---

**Document History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-07 | Security Team | Initial document -- compensating controls specification |

**Next Review**: 2026-08-07
