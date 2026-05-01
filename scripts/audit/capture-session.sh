#!/bin/bash
# scripts/audit/capture-session.sh
# Captures OpenCode session data to PostgreSQL and filesystem

set -euo pipefail

SESSION_ID="${1:-}"
RUN_ID="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_DIR="${SCRIPT_DIR}/../../.audit"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_info() {
    echo -e "${NC}[INFO]${NC} $1"
}

# Validate inputs
if [[ -z "$SESSION_ID" || -z "$RUN_ID" ]]; then
    log_error "Usage: $0 <session-id> <run-id>"
    exit 1
fi

# Ensure audit directories exist
mkdir -p "$AUDIT_DIR/actions/$(date +%Y/%m)"
mkdir -p "$AUDIT_DIR/sessions/$(date +%Y/%m)"
mkdir -p "$AUDIT_DIR/chain"

# Capture session data from PostgreSQL
log_info "Capturing session $SESSION_ID..."

# Export session to JSON
psql -t -c "
    SELECT json_build_object(
        'session_id', session_id,
        'agent_name', agent_name,
        'agent_mode', agent_mode,
        'started_at', started_at,
        'ended_at', ended_at,
        'status', status,
        'metadata', metadata,
        'conversation_log', conversation_log
    )
    FROM agent_sessions
    WHERE session_id = '$SESSION_ID'::uuid;
" > "$AUDIT_DIR/sessions/$(date +%Y/%m/%d)/session-${SESSION_ID}.json" 2>/dev/null || {
    log_error "Failed to capture session from database"
    exit 1
}

# Export all actions for session
psql -t -c "
    SELECT json_agg(json_build_object(
        'action_id', action_id,
        'action_type', action_type,
        'tool_used', tool_used,
        'tool_input', tool_input,
        'execution_time_ms', execution_time_ms,
        'timestamp', timestamp,
        'security_scan_status', security_scan_status,
        'compliance_status', compliance_status
    ))
    FROM agent_actions
    WHERE session_id = '$SESSION_ID'::uuid;
" > "$AUDIT_DIR/actions/$(date +%Y/%m/%d)/actions-${SESSION_ID}.json" 2>/dev/null || {
    log_error "Failed to capture actions from database"
}

# Calculate session hash
SESSION_HASH=$(sha256sum "$AUDIT_DIR/sessions/$(date +%Y/%m/%d)/session-${SESSION_ID}.json" | cut -d' ' -f1)

# Append to chain
CHAIN_FILE="$AUDIT_DIR/chain/chain-$(date +%Y%m).log"
PREV_HASH="0"
if [[ -f "$CHAIN_FILE" ]]; then
    PREV_HASH=$(tail -n 1 "$CHAIN_FILE" | cut -d' ' -f2 || echo "0")
fi

echo "$(date -Iseconds) ${SESSION_HASH} ${PREV_HASH} ${RUN_ID}" >> "$CHAIN_FILE"

# Create metadata file
cat > "$AUDIT_DIR/sessions/$(date +%Y/%m/%d)/session-${SESSION_ID}-meta.json" <<EOF
{
    "session_id": "$SESSION_ID",
    "run_id": "$RUN_ID",
    "captured_at": "$(date -Iseconds)",
    "session_hash": "$SESSION_HASH",
    "previous_hash": "$PREV_HASH",
    "capture_tool": "capture-session.sh",
    "version": "1.0"
}
EOF

log_success "Session captured successfully"
log_info "Session file: $AUDIT_DIR/sessions/$(date +%Y/%m/%d)/session-${SESSION_ID}.json"
log_info "Session hash: $SESSION_HASH"

exit 0