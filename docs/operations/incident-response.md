# Incident Response Playbook

## Overview

This playbook provides a **4-hour Recovery Time Objective (RTO)** for security incidents affecting AIXCL. It is structured as **agent-executable checklists with mandatory human approval gates**.

**Classification**: Internal Use Only  
**Last Updated**: 2026-05-07  
**Owner**: Security Team  
**RTO**: 4 hours  
**Scope**: All AIXCL runtime and operational services

---

## Activation Criteria

An incident is declared when any of the following occur:

| Indicator | Severity | Auto-Response |
|-----------|----------|---------------|
| Threat-detector reports CRITICAL alert | CRITICAL | Auto-contain + page on-call |
| Audit chain verification fails | CRITICAL | HALT all automation |
| LLM firewall bypass detected | CRITICAL | Auto-contain + page on-call |
| Unapproved privileged container launch | HIGH | Alert + log |
| Sustained anomalous query volume (>10x baseline) | HIGH | Auto-throttle + alert |
| Host firewall rules modified outside change window | HIGH | Alert + revert if automated |
| Any agent requests `rm -rf` or git push without approval | CRITICAL | Auto-deny + alert |
| Human approval queue backlog >24 hours | MEDIUM | Alert ops team |

**Human decision required to declare an incident if auto-response did not trigger.**

---

## Phase 1 -- Detection (T+0 minutes)

### Automated Actions (Agent)

- [ ] Threat-detector identifies anomaly
- [ ] Alert sent to Slack #security with incident ID format `AIXCL-INC-YYYYMMDD-NNNN`
- [ ] Incident ID logged to `audit_log` with `action = 'incident_declared'`
- [ ] Human approval queue entry created with severity = CRITICAL

### Human Actions

- [ ] Acknowledge alert in Slack within 5 minutes
- [ ] Open incident tracking document (copy from template below)
- [ ] Verify incident is genuine (not false positive)
- [ ] If false positive, close incident, log reason, tune detector

### Verification

```bash
# Check latest incident entries
psql -U postgres -d aixcl -c "SELECT id, timestamp, actor, action, outcome FROM audit_log WHERE action = 'incident_declared' ORDER BY id DESC LIMIT 5;"

# Verify Slack alert sent
grep "AIXCL-INC" /var/log/aixcl/threat-detector.log | tail -5
```

---

## Phase 2 -- Automated Containment (T+5 minutes)

### Automated Actions (Agent) -- CRITICAL only

- [ ] Emergency lockdown triggered if incident severity = CRITICAL
- [ ] Compromised container stopped via `./aixcl service stop <service>`
- [ ] Network isolation applied (host firewall rules tightened if applicable)
- [ ] All non-essential services paused
- [ ] Audit log entry created for each containment action

### Human Actions

- [ ] Review automated containment actions
- [ ] Confirm containment did not over-reach (verify unaffected services still running)
- [ ] If manual containment needed, approve via human approval queue
- [ ] Do NOT approve recovery actions yet

### Verification

```bash
# Check stack status after containment
./aixcl stack status

# Verify affected service is stopped
podman ps --filter "name=<service>" --format "{{.Names}} {{.State}}"

# Verify firewall is still active
iptables -L -n | head -5
```

---

## Phase 3 -- Human Assessment (T+30 minutes)

### Human Actions (Required -- no agent automation)

- [ ] Security team member acknowledges incident ownership
- [ ] Preserve forensic evidence before any remediation:
  - [ ] Snapshot affected container state if possible
  - [ ] Copy relevant audit log entries to incident tracking doc
  - [ ] Export Prometheus metrics for incident window
  - [ ] Save Loki logs for affected service (last 1 hour)
- [ ] Determine scope of breach:
  - [ ] Which services affected?
  - [ ] Which data accessed or modified?
  - [ ] Which agents/humans involved?
  - [ ] Attack vector identified?
- [ ] Document findings in incident tracking document

### Agent Support Actions (Information gathering only)

- [ ] Generate service status report for incident window
- [ ] Extract audit log entries for affected actors
- [ ] Pull Prometheus alert history for time window
- [ ] Compile Loki log export for specified service

### Verification

```bash
# Export audit log for incident window
psql -U postgres -d aixcl -c "\copy (SELECT * FROM audit_log WHERE timestamp BETWEEN '<start>' AND '<end>' ORDER BY timestamp) TO '/tmp/incident-audit-<incident-id>.csv' CSV;"

# Export Loki logs
# (Requires Grafana API key or direct Loki query)
curl -s "http://localhost:3100/loki/api/v1/query_range?query=%7Bjob%3D%22aixcl%22%7D&start=<unix-nano-start>&end=<unix-nano-end>" | jq '.data.result[] | .values[]'

# Export Prometheus alerts
curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts[] | select(.labels.severity | IN("critical","high"))'
```

---

## Phase 4 -- Eradication (T+2 hours)

### Human Actions (Required)

- [ ] Root cause identified and documented
- [ ] All malicious artifacts identified and removed
- [ ] Vulnerability that enabled breach is patched or mitigated
- [ ] Verify no persistence mechanisms remain (cron, systemd units, backdoor containers)
- [ ] Re-scan affected systems with updated threat detector rules

### Agent Support Actions (After human approval)

- [ ] Once approved, apply patch or configuration fix
- [ ] Restart affected service with hardened configuration
- [ ] Verify service passes health checks before marking operational
- [ ] Log all remediation actions to audit trail

### Human Approval Gate

Before any eradication action:

```
REQUEST: incident-eradication-<incident-id>
ACTION: Apply fix and restart <service>
JUSTIFICATION: <human-provided>
SEVERITY: CRITICAL
APPROVAL REQUIRED FROM: security-oncall
```

### Verification

```bash
# Verify service health after restart
./aixcl stack status | grep <service>

# Run targeted threat detector scan
# (Detector re-runs all rules against current state)
./aixcl stack logs threat-detector --tail 50

# Verify no new alerts
# Check Prometheus for 10 minutes after remediation
curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts | length'
```

---

## Phase 5 -- Recovery (T+3 hours)

### Human Actions (Required)

- [ ] Confirm eradication is complete and verified
- [ ] Approve service restoration via human approval queue
- [ ] Verify restored services are functioning correctly
- [ ] Enhanced monitoring enabled for affected services (increased scrape frequency)
- [ ] Determine if user notification is required (data breach, service outage)

### Agent Actions (After approval)

- [ ] Restore services from clean state (not backups -- clean rebuild preferred)
- [ ] Re-apply security configurations (firewall, secrets, SSL)
- [ ] Verify all compensating controls are active post-recovery
- [ ] Run `./scripts/security/verify-controls.sh` (from compensating-controls.md)

### Verification

```bash
# Full stack verification
./aixcl stack status

# Verify all controls
./scripts/security/verify-controls.sh

# Check no pending approvals
psql -U postgres -d aixcl -c "SELECT COUNT(*) FROM human_approvals WHERE status = 'PENDING';"
```

---

## Phase 6 -- Post-Incident (T+4 hours)

### Human Actions (Required)

- [ ] Document lessons learned in incident tracking document
- [ ] Update threat detection rules if new attack vector discovered
- [ ] Update compensating controls if gaps found
- [ ] Schedule control review if incident revealed systemic issue
- [ ] Conduct team debrief within 48 hours
- [ ] Close incident in tracking system

### Agent Actions

- [ ] Generate incident summary report:
  - Timeline of events
  - Actions taken (automated and human)
  - Metrics affected
  - Controls that succeeded and failed
- [ ] Archive incident data to long-term storage (S3 if configured)
- [ ] Reset monitoring to baseline (remove enhanced frequency)
- [ ] Update audit log with `action = 'incident_closed'`

### Verification

```bash
# Verify incident closed in audit log
psql -U postgres -d aixcl -c "SELECT * FROM audit_log WHERE action = 'incident_closed' ORDER BY id DESC LIMIT 1;"

# Verify monitoring reset
# (Check Prometheus scrape intervals returned to normal)
curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | .labels.job'
```

---

## Escalation Matrix

| Severity | Initial Response | Escalation Path | Notification |
|----------|-----------------|-----------------|--------------|
| CRITICAL | Automated containment | Page on-call immediately | Slack @channel + Phone + PagerDuty |
| HIGH | Auto-throttle + alert | Security team within 30 min | Slack #security |
| MEDIUM | Log + monitor | Next business day | Weekly summary email |
| LOW | Log only | None | Monthly report |

### Escalation Rules

- CRITICAL not acknowledged in 15 minutes --> escalate to secondary on-call
- HIGH not assessed in 1 hour --> escalate to security team lead
- Queue backlog >5 CRITICAL/HIGH --> page all security team
- Agent HALT triggered --> immediate page regardless of severity

---

## Incident Tracking Document Template

Copy this template for each incident:

```markdown
# Incident AIXCL-INC-YYYYMMDD-NNNN

## Metadata
- **Declared**: YYYY-MM-DD HH:MM UTC
- **Severity**: CRITICAL / HIGH / MEDIUM / LOW
- **Owner**: <security-team-member>
- **Status**: DETECTED / CONTAINED / ASSESSING / ERADICATING / RECOVERING / CLOSED

## Summary
<2-sentence description>

## Timeline
- T+0: Detection
- T+5: Automated containment
- T+30: Human assessment started
- T+2h: Eradication
- T+3h: Recovery
- T+4h: Post-incident

## Affected Services
- [ ] <list>

## Data Impact
- [ ] No data accessed
- [ ] Data accessed but not modified
- [ ] Data modified
- [ ] Data exfiltrated

## Root Cause
<description>

## Actions Taken
### Automated
- <list>

### Human
- <list>

## Lessons Learned
- <list>

## Control Updates Required
- [ ] None
- [ ] Threat detector rules
- [ ] Compensating controls
- [ ] Human approval gates

## Closed By**: <name>
**Closed Date**: YYYY-MM-DD HH:MM UTC
```

---

## Communication Templates

### Slack #security Alert (Automated)

```
**AIXCL SECURITY INCIDENT**
ID: AIXCL-INC-YYYYMMDD-NNNN
Severity: CRITICAL
Detected: <attack-vector>
Auto-Response: <action-taken>
Owner: <security-oncall>
Acknowledge: React with ACK
```

### Human Approval Request (Automated)

```
:warning: APPROVAL REQUIRED
Request ID: <uuid>
Action: <description>
Severity: CRITICAL
Timeout: 24 hours
Justification: <auto-generated>

> **Note:** Human approval workflow is planned but not yet implemented. For now, review via Slack #security and document decisions in the incident tracking document.
```

---

## Tool Reference

| Tool | Purpose | Command |
|------|---------|---------|
| Stack status | Check service health | `./aixcl stack status` |
| Stack logs | View service logs | `./aixcl stack logs <service>` |
| Audit log | Query audit trail | `psql -U postgres -d aixcl -c "SELECT ..."` |
| Chain verify | Verify audit integrity | `./scripts/audit/verify-chain.sh` |
| Firewall check | Verify iptables rules | `iptables -L -n -v | grep DROP` |
| Prometheus alerts | View active alerts | `curl -s localhost:9090/api/v1/alerts` |
| Loki logs | Query log aggregator | `curl -s localhost:3100/loki/api/v1/query_range?...` |

---

## Cross-References

- [Compensating Controls](/docs/security/compensating-controls.md) -- Detailed control specifications and verification
- [Threat Model](/docs/security/threat-model.md) -- Attack vectors and mitigations
- [Security Runbook](/docs/operations/security-runbook.md) -- Day-to-day operational procedures
- [AIXCL Platform Invariants](/docs/architecture/governance/00_invariants.md) -- Architectural constraints affecting response options

---

**Document History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-07 | Security Team | Initial document -- 4-hour RTO playbook |

**Next Review**: 2026-08-07
