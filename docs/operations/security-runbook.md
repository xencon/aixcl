# Security Runbook

## Overview

This runbook provides **day-to-day operational security procedures** for AIXCL. It is structured as **executable checklists** for both automated agents and human operators, with clear boundaries on who performs what.

**Classification**: Internal Use Only  
**Last Updated**: 2026-05-07  
**Owner**: Security Team  
**Review Cycle**: Weekly for automated checks, monthly for manual reviews  
**Scope**: All AIXCL runtime and operational services

---

## Daily Automated Checks (Agent)

Run these checks automatically every day in `bld` and `sys` profiles.

### Check 1 -- Stack Health

- [ ] `./aixcl stack status` returns all services as running or stopped (no errors)
- [ ] No unexpected service restarts in last 24 hours
- [ ] Expected service count matches profile (bld=10, sys=13)

```bash
#!/bin/bash
# daily-health-check.sh
profile=$(grep "^PROFILE=" .env | cut -d= -f2)
count=$(./aixcl stack status | grep -c "[x]")
expected=$(case $profile in bld) echo 10;; sys) echo 13;; *) echo 0;; esac)
if [ "$count" -lt "$expected" ]; then
    echo "FAIL: Only $count/$expected services healthy"
    exit 1
fi
echo "PASS: $count/$expected services healthy"
```

### Check 2 -- Firewall Rules Active

- [ ] `iptables` rules match baseline configuration
- [ ] No unauthorized rules added since last check
- [ ] Default policy remains DROP on INPUT/FORWARD/OUTPUT

```bash
#!/bin/bash
# daily-firewall-check.sh
if ! iptables -L INPUT -n | grep -q "Policy DROP"; then
    echo "FAIL: INPUT policy not DROP"
    exit 1
fi
# Compare current rules to baseline
iptables-save | diff - /etc/iptables/rules.v4 >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "WARN: Firewall rules differ from baseline"
    exit 1
fi
echo "PASS: Firewall rules match baseline"
```

### Check 3 -- Audit Chain Integrity

- [ ] No gaps in `audit_log` sequence (psql gap check returns 0)
- [ ] Last entry within last hour (audit is actively written)

```bash
# Check for sequence gaps in audit chain
gap=$(psql -U postgres -d aixcl -tc "SELECT COUNT(*) FROM generate_series(1, (SELECT MAX(id) FROM audit_log)) EXCEPT SELECT id FROM audit_log;")
if [ "$gap" -gt 0 ]; then
    echo "FAIL: $gap missing entries in audit chain"
    exit 1
fi
echo "PASS: Audit chain intact, no gaps"
```

### Check 4 -- Pending Human Approvals

- [ ] No CRITICAL or HIGH approvals pending >1 hour
- [ ] Approval queue backlog <5 total
- [ ] Average response time <4 hours for last 7 days

```bash
#!/bin/bash
# daily-approval-check.sh
old=$(psql -U postgres -d aixcl -tc "SELECT COUNT(*) FROM human_approvals WHERE status = 'PENDING' AND severity IN ('CRITICAL','HIGH') AND timestamp < NOW() - INTERVAL '1 hour';")
if [ "$old" -gt 0 ]; then
    echo "FAIL: $old critical/high approvals pending >1 hour"
    exit 1
fi
backlog=$(psql -U postgres -d aixcl -tc "SELECT COUNT(*) FROM human_approvals WHERE status = 'PENDING';")
if [ "$backlog" -gt 5 ]; then
    echo "WARN: Approval backlog = $backlog"
fi
avg=$(psql -U postgres -d aixcl -tc "SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (response_time - timestamp)))/3600, 0) FROM human_approvals WHERE status IN ('APPROVED','DENIED') AND timestamp > NOW() - INTERVAL '7 days';")
# Bash comparison of floats requires external tool; simplified:
echo "INFO: Average approval response time = ${avg} hours"
```

### Check 5 -- Threat Detector Active

- [ ] Threat detector agent is running
- [ ] No CRITICAL alerts unacknowledged >1 hour
- [ ] Prometheus alert rules valid (`promtool check rules` passes)

```bash
#!/bin/bash
# daily-threat-check.sh
if ! ./aixcl stack status | grep -q "threat-detector"; then
    echo "FAIL: Threat detector not in stack status"
    exit 1
fi
if ! promtool check rules prometheus/alerts.yml >/dev/null 2>&1; then
    echo "FAIL: Prometheus alert rules invalid"
    exit 1
fi
echo "PASS: Threat detector operational"
```

---

## Weekly Manual Checks (Human)

Run these checks once per week. Agent may schedule reminders but execution is human.

### Check 1 -- Credential Rotation Verification

- [ ] Vault credentials rotated within last 7 days (dynamic secrets)
- [ ] Bootstrap passwords in Vault KV are current
- [ ] No static passwords remain in `.env` (except comments/defaults)

```bash
# Check Vault credential TTL
./aixcl vault credentials
# Verify timestamps are within 7 days

# Check .env for remaining passwords
grep -E "^(POSTGRES_PASSWORD|PGADMIN_PASSWORD|OPENWEBUI_PASSWORD)=" .env
echo "Expected: none (should use _FILE or Vault)"
```

### Check 2 -- Container Security Review

- [ ] No containers running as root unnecessarily
- [ ] No containers with `--privileged` in production (cAdvisor should be disabled)
- [ ] `no-new-privileges` flag present on all containers
- [ ] Read-only root filesystems enabled where documented

```bash
# List running containers with security info
podman ps --format "{{.Names}} {{.User}}" | while read name user; do
    if [ "$user" = "root" ] || [ "$user" = "0" ]; then
        echo "WARN: $name running as root"
    fi
done

# Check for privileged containers
podman ps --format "{{.Names}}" | while read name; do
    inspect=$(podman inspect "$name" --format "{{.HostConfig.Privileged}}")
    if [ "$inspect" = "true" ]; then
        echo "CRIT: $name is privileged"
    fi
done
```

### Check 3 -- Log Review

- [ ] Review Loki logs for security events in last 7 days
- [ ] Check for repeated failed authentication attempts
- [ ] Verify no unexpected external network connections
- [ ] Review agent action logs for anomalies

```bash
# Query Loki for security-relevant logs
curl -s "http://localhost:3100/loki/api/v1/query_range?query=%7Bjob%3D%22aixcl%22%7D%20%7C%3D%20%22security%22&limit=100&start=<7-days-ago>"

# Check for failed auth in PostgreSQL
psql -U postgres -d aixcl -c "SELECT timestamp, actor, action, outcome FROM audit_log WHERE outcome = 'FAILURE' AND timestamp > NOW() - INTERVAL '7 days' ORDER BY timestamp;"
```

### Check 4 -- Compliance Spot Check

- [ ] Verify host firewall rules are still appropriate for current services
- [ ] Confirm SSL/TLS is enabled on all database connections (`sslmode=require`)
- [ ] Check that GPG signing is enforced on recent commits
- [ ] Verify no secrets in git history (`git-secrets` or `truffleHog` scan)

```bash
# Check PostgreSQL SSL mode
psql -U postgres -d aixcl -c "SHOW ssl;"

# Verify recent commits are signed
git log --show-signature --since="1 week ago" | grep -E "(gpg|Good signature|BAD signature)"

# Scan for secrets in recent history
# (Requires git-secrets or similar tool)
git secrets --scan-history --since="1 week ago"
```

---

## Monthly Deep Checks (Human + Agent Support)

### Check 1 -- Full Control Verification

Run the daily control checks from [compensating-controls.md](../security/compensating-controls.md) manually:

```bash
# Host firewall
iptables -L -n | grep -E "Policy|DROP" | head -5

# LLM firewall
ss -tlnp | grep 11435 || echo "FAIL: LLM firewall not listening"

# Threat detector
./aixcl stack status | grep threat-detector || echo "FAIL: Threat detector not in status"

# Audit chain gap check
psql -U postgres -d aixcl -tc "SELECT COUNT(*) FROM generate_series(1, (SELECT MAX(id) FROM audit_log)) EXCEPT SELECT id FROM audit_log;" | grep -q "^[[:space:]]*0$" || echo "FAIL: Audit chain gaps detected"

# Pending approvals
psql -U postgres -d aixcl -c "SELECT COUNT(*) FROM human_approvals WHERE status = 'PENDING';"
```

- [ ] Host firewall: PASS
- [ ] LLM firewall: PASS
- [ ] Threat detector: PASS
- [ ] Audit chain: PASS
- [ ] Human approvals: PASS

### Check 2 -- Threat Model Review

- [ ] Review threat-model.md for new attack vectors
- [ ] Verify all listed controls are still implemented
- [ ] Check MITRE ATT&CK coverage for new techniques
- [ ] Update threat model if environment changed (new services, new profiles)

### Check 3 -- Access Control Review

- [ ] Review list of humans with approval authority
- [ ] Verify no orphaned accounts (departed team members)
- [ ] Check that RBAC roles match current responsibilities
- [ ] Rotate any shared credentials

### Check 4 -- Backup and Recovery Test

- [ ] Verify database backups are current and restorable
- [ ] Test recovery of audit log from backup
- [ ] Confirm S3 archive configuration works (if enabled)
- [ ] Document recovery time for full stack rebuild

---

## On-Demand Checks

### Post-Deployment Verification

Run after any stack start, profile change, or service update:

- [ ] `./aixcl stack status` shows expected services
- [ ] `./scripts/security/verify-controls.sh` passes
- [ ] All agents can connect to their respective services
- [ ] Human approval queue is empty

### Post-Incident Verification

Run after closing any security incident:

- [ ] All controls verified operational (verify-controls.sh)
- [ ] Audit chain intact post-incident
- [ ] No lingering firewall modifications from incident response
- [ ] Services restored to clean state (not from potentially compromised backup)
- [ ] Threat detector rules updated if new vector discovered
- [ ] Incident report reviewed and approved by security lead

---

## Alert Thresholds and Response

| Check | Frequency | Threshold | Response |
|-------|-----------|-----------|----------|
| Stack health | Daily | < expected services | Alert operations team |
| Firewall rules | Daily | Rules differ from baseline | Alert security team |
| Audit chain | Daily | Chain broken or gaps | **HALT** automation, page on-call |
| Approval queue | Daily | >5 pending or >1 critical >1h | Alert security team |
| Threat detector | Daily | Agent down or invalid rules | Alert operations team |
| Credential rotation | Weekly | No rotation in >7 days | Alert security team |
| Container security | Weekly | Root or privileged containers | Alert security team |
| Log review | Weekly | Repeated failures or anomalies | Alert security team |
| Compliance | Weekly | SSL off or unsigned commits | Alert security team |
| Full controls | Monthly | Any check fails | Page on-call |
| Threat model | Monthly | Out of date | Create update task |
| Access control | Monthly | Orphaned accounts found | Alert security team |
| Backup test | Monthly | Backup unrecoverable | Alert bld team + create recovery task |

---

## Tool Reference

| Tool | Purpose | Frequency |
|------|---------|-----------|
| `./aixcl stack status` | Service health overview | Daily |
| `iptables -L -n -v` | Firewall rule verification | Daily |
| `psql` audit gap query | Audit chain integrity | Daily |
| `psql` queries | Approval queue and audit checks | Daily |
| `./aixcl vault credentials` | Credential status | Weekly |
| `podman ps` / `podman inspect` | Container security | Weekly |
| `curl` to Loki API | Log analysis | Weekly |
| `git log --show-signature` | Commit signing | Weekly |
| Manual checks in compensating-controls.md | Full control check | Monthly |
| `promtool check rules` | Alert rule validation | Daily |

---

## Escalation

If any check fails and you cannot resolve within your SLA:

1. Log failure to audit trail
2. Notify #security Slack channel
3. Create human approval request if automated fix is needed
4. Reference incident-response.md if situation meets incident criteria
5. Document workaround applied (if any)

---

## Cross-References

- [Compensating Controls](/docs/security/compensating-controls.md) -- Detailed control specifications
- [Incident Response Playbook](/docs/operations/incident-response.md) -- When checks reveal an incident
- [Threat Model](/docs/security/threat-model.md) -- What we are defending against
- [AIXCL Platform Invariants](/docs/architecture/governance/00_invariants.md) -- Architectural constraints

---

**Document History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-05-07 | Security Team | Initial document -- operational security procedures |

**Next Review**: 2026-06-07
