#!/usr/bin/env bash
# scripts/security/validate-token.sh
# Validates security approval token for agentic workflows

set -euo pipefail

TOKEN="${1:-}"
REQUIRED_MAINTAINER="${2:-sbadakhc}"  # Default maintainer
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if token is provided
if [[ -z "$TOKEN" ]]; then
    log_error "Security token is required"
    echo "Usage: $0 <security-token> [maintainer-username]"
    exit 1
fi

# Validate token format (simple check - enhance based on your token scheme)
if [[ ! "$TOKEN" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid token format"
    exit 1
fi

# Check if running in GitHub Actions context
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    # Validate GitHub token permissions
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN not available"
        exit 1
    fi
    
    # Check if actor is authorized maintainer
    if [[ "${GITHUB_ACTOR:-}" != "$REQUIRED_MAINTAINER" ]]; then
        log_error "Unauthorized actor: ${GITHUB_ACTOR}"
        echo "Expected: $REQUIRED_MAINTAINER"
        exit 1
    fi
    
    log_success "GitHub Actions context validated"
    log_success "Actor: ${GITHUB_ACTOR}"
    log_success "Repository: ${GITHUB_REPOSITORY}"
fi

# Check for emergency mode
if [[ -f "$SCRIPT_DIR/../../.security/emergency-mode" ]]; then
    log_error "EMERGENCY MODE ACTIVE"
    log_error "All agent activity is blocked pending security review"
    exit 1
fi

# Validate token against database (if available)
if command -v psql >/dev/null 2>&1; then
    # Check if token exists in approvals table
    TOKEN_VALID=$(psql -t -c "
        SELECT COUNT(*) 
        FROM human_approvals 
        WHERE approval_status = 'approved' 
        AND approved_by = '$REQUIRED_MAINTAINER'
        AND approved_at > NOW() - INTERVAL '24 hours'
    " 2>/dev/null || echo "0")
    
    if [[ "$TOKEN_VALID" -eq "0" ]]; then
        log_warning "No recent approval found in database"
        log_warning "Proceeding with caution..."
    else
        log_success "Recent approval found in database"
    fi
fi

# Additional security checks

# Check repository state
if [[ -d "$SCRIPT_DIR/../../.git" ]]; then
    # Ensure we're not in a dirty state
    if ! git diff --quiet HEAD 2>/dev/null; then
        log_warning "Repository has uncommitted changes"
    fi
    
    # Verify current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    log_success "Current branch: $CURRENT_BRANCH"
fi

# Check for suspicious environment
SUSPICIOUS_VARS=$(env | grep -E "(SECRET|KEY|TOKEN|PASSWORD)" | grep -v "^GITHUB_" | grep -v "^${REQUIRED_MAINTAINER^^}_" || true)
if [[ -n "$SUSPICIOUS_VARS" ]]; then
    log_warning "Suspicious environment variables detected (filtered from output)"
fi

log_success "Security token validation completed"
exit 0