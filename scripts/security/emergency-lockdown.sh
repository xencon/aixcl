#!/bin/bash
# scripts/security/emergency-lockdown.sh
# Emergency lockdown procedure for agentic system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."
LOCKDOWN_REASON="${1:-'Emergency security lockdown initiated'}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error() {
    echo -e "${RED}[EMERGENCY]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create lockdown marker
log_error "INITIATING EMERGENCY LOCKDOWN"
log_error "Reason: $LOCKDOWN_REASON"
echo ""

# Create emergency mode file
cat > "$PROJECT_ROOT/.security/emergency-mode" <<EOF
EMERGENCY_LOCKDOWN=true
LOCKDOWN_TIMESTAMP=$(date -Iseconds)
LOCKDOWN_REASON="$LOCKDOWN_REASON"
LOCKDOWN_INITIATED_BY=${GITHUB_ACTOR:-$(whoami)}
UNLOCK_REQUIRES="Manual intervention by security team"
EOF

log_success "Emergency mode file created"

# Preserve evidence
echo ""
log_warning "Preserving evidence..."
mkdir -p "$PROJECT_ROOT/.security/evidence/$(date +%Y%m%d-%H%M%S)"
cp -r "$PROJECT_ROOT/.audit/actions/"* "$PROJECT_ROOT/.security/evidence/$(date +%Y%m%d-%H%M%S)/" 2>/dev/null || true

# Database backup
echo ""
log_warning "Creating database backup..."
if command -v pg_dump >/dev/null 2>&1; then
    pg_dump -h localhost -U admin -d webui \
        -t agent_sessions \
        -t agent_actions \
        -t human_approvals \
        -t audit_logs \
        > "$PROJECT_ROOT/.security/evidence/$(date +%Y%m%d-%H%M%S)/audit-db-backup.sql" 2>/dev/null || {
        log_warning "Database backup failed (expected if postgres not running)"
    }
else
    log_warning "pg_dump not available"
fi

# Disable git operations temporarily
echo ""
log_warning "Blocking git operations..."
cat > "$PROJECT_ROOT/.git/hooks/pre-commit" <<'EOF'
#!/bin/bash
# Emergency lockdown - all commits blocked
if [[ -f .security/emergency-mode ]]; then
    echo "EMERGENCY LOCKDOWN ACTIVE"
    echo "All commits are blocked pending security review"
    echo "Contact security team to unlock"
    exit 1
fi
EOF
chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"

log_success "Git pre-commit hook installed"

# Create incident report template
cat > "$PROJECT_ROOT/.security/incident-$(date +%Y%m%d-%H%M%S).md" <<EOF
# Security Incident Report

**Date**: $(date -Iseconds)
**Status**: ACTIVE
**Severity**: CRITICAL
**Reason**: $LOCKDOWN_REASON

## Lockdown Details

- **Initiated by**: ${GITHUB_ACTOR:-$(whoami)}
- **Git commit**: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
- **Branch**: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")

## Evidence Location

- Filesystem: .security/evidence/$(date +%Y%m%d-%H%M%S)/
- Database: audit tables (agent_sessions, agent_actions, human_approvals, audit_logs)
- Audit chain: .audit/chain/

## Next Steps

1. [ ] Review audit logs for breach indicators
2. [ ] Verify chain integrity: ./scripts/audit/verify-chain.sh
3. [ ] Assess scope of incident
4. [ ] Create remediation plan
5. [ ] Get security team sign-off
6. [ ] Remove .security/emergency-mode to unlock

## Unlock Procedure

\`\`\`bash
# 1. Verify chain integrity
./scripts/audit/verify-chain.sh

# 2. Review all changes since lockdown
git diff HEAD

# 3. Get security team approval

# 4. Remove lockdown
rm .security/emergency-mode
git config --local --unset hooks.pre-commit  # Remove git hook
\`\`\`

---
**DO NOT REMOVE LOCKDOWN WITHOUT SECURITY TEAM APPROVAL**
EOF

log_success "Incident report created: .security/incident-$(date +%Y%m%d-%H%M%S).md"

# Display summary
echo ""
echo "=========================================="
log_error "EMERGENCY LOCKDOWN COMPLETE"
echo "=========================================="
echo ""
echo "All agent activity is BLOCKED"
echo "Git commits are DISABLED"
echo "Audit evidence preserved"
echo ""
echo "Next steps:"
echo "1. Review incident report: .security/incident-$(date +%Y%m%d-%H%M%S).md"
echo "2. Alert security team via Slack/GitHub"
echo "3. Investigate root cause"
echo "4. Get approval before unlocking"
echo ""
log_error "DO NOT PROCEED WITHOUT SECURITY TEAM APPROVAL"

exit 0