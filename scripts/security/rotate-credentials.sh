#!/bin/bash
#
# Threat-Adaptive Credential Rotation for AIXCL
# Phase 2: Automated credential rotation with human-in-the-loop
#
# Usage:
#   ./scripts/security/rotate-credentials.sh --check           # Check if rotation needed
#   ./scripts/security/rotate-credentials.sh --scheduled        # JIT time-based rotation
#   ./scripts/security/rotate-credentials.sh --threat LEVEL     # Threat-triggered rotation
#   ./scripts/security/rotate-credentials.sh --emergency        # Immediate rotation (CRITICAL only)
#
# Security: Rotates credentials based on time OR threat level

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_LOG="${SCRIPT_DIR}/../../.audit/rotation-events.log"
ROTATION_STATE="${SCRIPT_DIR}/../../.security/.rotation-state"
GRACE_PERIOD_SECONDS=60

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_critical() { echo -e "${RED}[CRITICAL]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Audit logging
audit_log() {
  local event="$1"
  local details="${2:-}"
  local timestamp
  timestamp=$(date -Iseconds)
  
  mkdir -p "$(dirname "$AUDIT_LOG")"
  echo "${timestamp} | ${event} | ${details}" >> "$AUDIT_LOG"
}

# Check current threat level
check_threat_level() {
  # Check if threat-detector agent exists
  local threat_detector="${SCRIPT_DIR}/threat-detector.sh"
  
  if [[ -x "$threat_detector" ]]; then
    # Query threat detector
    local level
    level=$("$threat_detector" --assess --quiet 2>/dev/null || echo "UNKNOWN")
    echo "$level"
  else
    # Fallback: Check basic indicators
    check_basic_threat_indicators
  fi
}

# Basic threat indicators (fallback)
check_basic_threat_indicators() {
  local threat_score=0
  
  # Check for failed authentication attempts
  local failed_auths
  failed_auths=$(grep -c "authentication failed" /var/log/postgresql/*.log 2>/dev/null || echo "0")
  if [[ "$failed_auths" -gt 10 ]]; then
    threat_score=$((threat_score + 30))
  fi
  
  # Check for unusual query patterns
  local suspicious_queries
  suspicious_queries=$(grep -cE "(SELECT.*FROM.*password|DROP TABLE|DELETE FROM)" /var/log/postgresql/*.log 2>/dev/null || echo "0")
  if [[ "$suspicious_queries" -gt 5 ]]; then
    threat_score=$((threat_score + 50))
  fi
  
  # Map score to level
  if [[ "$threat_score" -ge 80 ]]; then
    echo "CRITICAL"
  elif [[ "$threat_score" -ge 50 ]]; then
    echo "HIGH"
  elif [[ "$threat_score" -ge 20 ]]; then
    echo "MEDIUM"
  else
    echo "LOW"
  fi
}

# Check if rotation is due (JIT time-based)
rotation_due() {
  if [[ ! -f "$ROTATION_STATE" ]]; then
    log_warn "No rotation state file. Assuming first run."
    return 0
  fi
  
  local last_rotation
  last_rotation=$(cat "$ROTATION_STATE" 2>/dev/null || echo "0")
  local current_time
  current_time=$(date +%s)
  local days_since_rotation=$(( (current_time - last_rotation) / 86400 ))
  
  # Randomized window: 85-95 days
  local min_days=85
  local max_days=95
  
  if [[ "$days_since_rotation" -ge "$max_days" ]]; then
    log_warn "Credentials are $days_since_rotation days old. MANDATORY rotation required."
    return 0
  elif [[ "$days_since_rotation" -ge "$min_days" ]]; then
    log_info "Credentials are $days_since_rotation days old. Rotation recommended (window: $min_days-$max_days days)."
    return 0
  fi
  
  log_info "Credentials are $days_since_rotation days old. No rotation needed yet."
  return 1
}

# Send notification
notify() {
  local level="$1"
  local message="$2"
  
  # Log to audit
  audit_log "NOTIFICATION" "Level: $level, Message: $message"
  
  # Slack notification (if configured)
  if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    local color="danger"
    [[ "$level" == "CRITICAL" ]] && color="danger"
    [[ "$level" == "HIGH" ]] && color="warning"
    [[ "$level" == "MEDIUM" ]] && color="#ff9900"
    [[ "$level" == "LOW" ]] && color="good"
    
    curl -s -X POST "$SLACK_WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -d "{\"attachments\":[{\"color\":\"$color\",\"text\":\"🚨 AIXCL Credential Rotation: $level\n$message\"}]}" \
      2>/dev/null || true
  fi
  
  # Console notification
  if [[ "$level" == "CRITICAL" ]]; then
    log_critical "$message"
  elif [[ "$level" == "HIGH" ]]; then
    log_error "$message"
  else
    log_warn "$message"
  fi
}

# Grace period countdown with abort option
grace_period_countdown() {
  local reason="$1"
  local seconds=$GRACE_PERIOD_SECONDS
  
  log_critical "🚨 EMERGENCY ROTATION INITIATED"
  log_critical "Reason: $reason"
  log_critical "Auto-rotation in $seconds seconds..."
  log_critical "Run: $0 --abort to cancel"
  
  # Create abort file
  local abort_file="/tmp/.aixcl-rotation-abort"
  rm -f "$abort_file"
  
  while [[ $seconds -gt 0 ]]; do
    if [[ -f "$abort_file" ]]; then
      rm -f "$abort_file"
      log_info "Rotation ABORTED by user"
      audit_log "ROTATION_ABORTED" "Reason: $reason, Aborted by: user"
      return 1
    fi
    
    printf "\r⏳ Rotation in: %2d seconds (touch $abort_file to cancel)" "$seconds"
    sleep 1
    seconds=$((seconds - 1))
  done
  
  echo ""
  return 0
}

# Staged credential rotation
rotate_staged() {
  local reason="$1"
  local services=("postgres" "open-webui" "grafana" "pgadmin")
  
  log_info "Starting staged credential rotation..."
  audit_log "ROTATION_START" "Reason: $reason, Mode: staged"
  
  for service in "${services[@]}"; do
    log_info "Rotating credentials for: $service"
    
    # Generate new password
    local new_password
    new_password=$(head -c 4096 /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c 32)
    
    # Update Docker secret
    local secret_name="${service//-/_}_password"
    echo -n "$new_password" | docker secret create "${secret_name}_new" - 2>/dev/null || {
      log_error "Failed to create new secret for $service"
      continue
    }
    
    # Update service
    docker service update --secret-rm "${secret_name}" --secret-add "source=${secret_name}_new,target=${secret_name}" "aixcl_${service}" 2>/dev/null || {
      log_warn "Service update may require manual restart for $service"
    }
    
    # Verify health
    sleep 5
    if docker service ps "aixcl_${service}" | grep -q "Running"; then
      log_info "✓ $service rotated successfully"
      audit_log "ROTATION_SUCCESS" "Service: $service"
      
      # Remove old secret after grace period
      (sleep 300 && docker secret rm "${secret_name}" 2>/dev/null) &
    else
      log_error "✗ $service health check failed"
      audit_log "ROTATION_FAILURE" "Service: $service"
      # Trigger rollback
      return 1
    fi
  done
  
  # Update rotation timestamp
  date +%s > "$ROTATION_STATE"
  
  log_info "Staged rotation complete"
  audit_log "ROTATION_COMPLETE" "Reason: $reason"
}

# Emergency rollback
rollback_rotation() {
  log_critical "EMERGENCY ROLLBACK INITIATED"
  audit_log "ROLLBACK_START" "Emergency rollback due to failure"
  
  # Restore previous secrets (from backup if available)
  # This is a placeholder - implement based on your backup strategy
  log_warn "Rollback requires manual intervention"
  log_warn "Restore from backup: .security/backup/secrets/"
}

# Main execution
main() {
  case "${1:-}" in
    --check)
      if rotation_due; then
        echo "ROTATION_DUE"
        exit 0
      else
        echo "NO_ROTATION_NEEDED"
        exit 0
      fi
      ;;
      
    --scheduled)
      if rotation_due; then
        log_info "Scheduled rotation triggered (JIT time-based)"
        rotate_staged "JIT-scheduled"
      else
        log_info "No rotation needed at this time"
      fi
      ;;
      
    --threat)
      level="${2:-MEDIUM}"
      log_info "Threat-triggered rotation: Level $level"
      
      case "$level" in
        CRITICAL|critical)
          notify "CRITICAL" "Container escape/root compromise detected. Auto-rotating credentials in ${GRACE_PERIOD_SECONDS}s."
          if grace_period_countdown "CRITICAL threat detected"; then
            rotate_staged "threat-CRITICAL"
          fi
          ;;
        HIGH|high)
          notify "HIGH" "Credential theft/lateral movement suspected. Auto-rotating credentials."
          rotate_staged "threat-HIGH"
          ;;
        MEDIUM|medium|LOW|low)
          notify "$level" "Suspicious activity detected. Human approval required for rotation."
          log_info "Run: $0 --approve to proceed with rotation"
          ;;
        *)
          log_error "Unknown threat level: $level"
          exit 1
          ;;
      esac
      ;;
      
    --emergency)
      log_critical "EMERGENCY rotation initiated"
      notify "CRITICAL" "Emergency credential rotation in progress"
      rotate_staged "emergency"
      ;;
      
    --approve)
      log_info "Human approval received for rotation"
      rotate_staged "human-approved"
      ;;
      
    --abort)
      touch /tmp/.aixcl-rotation-abort
      log_info "Abort signal sent"
      ;;
      
    --status)
      if [[ -f "$ROTATION_STATE" ]]; then
        local last_rotation
        last_rotation=$(cat "$ROTATION_STATE")
        local current_time
        current_time=$(date +%s)
        local days_since=$(( (current_time - last_rotation) / 86400 ))
        echo "Last rotation: $days_since days ago"
        echo "Next rotation due: day 85-95"
      else
        echo "No rotation history found"
      fi
      
      local threat_level
      threat_level=$(check_threat_level)
      echo "Current threat level: $threat_level"
      ;;
      
    *)
      cat << EOF
Threat-Adaptive Credential Rotation for AIXCL

Usage: $0 [OPTION]

Options:
  --check              Check if rotation is due (JIT time-based)
  --scheduled          Run scheduled rotation if due
  --threat LEVEL       Rotate based on threat (CRITICAL/HIGH/MEDIUM/LOW)
  --emergency          Immediate emergency rotation
  --approve            Human approval for rotation
  --abort              Cancel pending rotation (during grace period)
  --status             Show rotation status and threat level

Threat Levels:
  CRITICAL (auto)   - Container escape, root compromise
  HIGH (auto)       - Credential theft, lateral movement
  MEDIUM (manual)   - Suspicious patterns
  LOW (manual)    - Minor anomalies

Examples:
  $0 --check                    # Check if rotation needed
  $0 --threat CRITICAL         # Threat-triggered with grace period
  $0 --scheduled               # JIT rotation if due
  $0 --status                  # Show current status

Security: All rotations are logged to .audit/rotation-events.log
EOF
      exit 0
      ;;
  esac
}

main "$@"
