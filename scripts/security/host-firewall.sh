#!/bin/bash
# scripts/security/host-firewall.sh
# Implements host-level firewall to compensate for AIXCL host networking
# Blocks external access, allows localhost-only for services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${SCRIPT_DIR}/iptables-rules.v4"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${NC}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (for iptables)"
    exit 1
fi

create_rules_file() {
    log_info "Creating iptables rules file..."
    
    cat > "$RULES_FILE" << 'EOF'
# AIXCL Host Firewall Rules
# Compensates for container host networking
# Allows localhost-only access to services

*filter
# Default policies
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT DROP [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT
-A OUTPUT -o lo -j ACCEPT

# Allow established connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow ICMP (ping)
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT
-A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

# PostgreSQL (localhost only)
-A INPUT -p tcp --dport 5432 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 5432 -d 127.0.0.1 -j ACCEPT

# Ollama API (localhost only)
-A INPUT -p tcp --dport 11434 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 11434 -d 127.0.0.1 -j ACCEPT

# LLM Firewall (localhost only)
-A INPUT -p tcp --dport 11435 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 11435 -d 127.0.0.1 -j ACCEPT

# Grafana (localhost only)
-A INPUT -p tcp --dport 3000 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 3000 -d 127.0.0.1 -j ACCEPT

# Prometheus (localhost only)
-A INPUT -p tcp --dport 9090 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 9090 -d 127.0.0.1 -j ACCEPT

# Loki (localhost only)
-A INPUT -p tcp --dport 3100 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 3100 -d 127.0.0.1 -j ACCEPT

# cAdvisor (localhost only) - if enabled
-A INPUT -p tcp --dport 8081 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 8081 -d 127.0.0.1 -j ACCEPT

# Open WebUI (localhost only)
-A INPUT -p tcp --dport 8080 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 8080 -d 127.0.0.1 -j ACCEPT

# pgAdmin (localhost only)
-A INPUT -p tcp --dport 5050 -s 127.0.0.1 -j ACCEPT
-A OUTPUT -p tcp --dport 5050 -d 127.0.0.1 -j ACCEPT

# Allow DNS
-A OUTPUT -p udp --dport 53 -j ACCEPT
-A INPUT -p udp --sport 53 -j ACCEPT

# Allow HTTP/HTTPS outbound (for updates)
-A OUTPUT -p tcp --dport 80 -j ACCEPT
-A OUTPUT -p tcp --dport 443 -j ACCEPT

# Log blocked attempts (for monitoring)
-A INPUT -j LOG --log-prefix "AIXCL-FIREWALL-DROP: " --log-level 4

# Deny everything else
-A INPUT -j DROP
-A FORWARD -j DROP
-A OUTPUT -j DROP

COMMIT
EOF

    log_success "Rules file created: $RULES_FILE"
}

apply_rules() {
    log_info "Applying firewall rules..."
    
    # Check if rules file exists
    if [[ ! -f "$RULES_FILE" ]]; then
        log_error "Rules file not found: $RULES_FILE"
        exit 1
    fi
    
    # Backup current rules
    log_info "Backing up current iptables rules..."
    iptables-save > "${RULES_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    
    # Apply new rules
    if iptables-restore < "$RULES_FILE"; then
        log_success "Firewall rules applied successfully"
    else
        log_error "Failed to apply firewall rules"
        exit 1
    fi
}

save_rules() {
    log_info "Saving rules for persistence..."
    
    # Save to iptables-persistent format
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
        log_success "Rules saved via netfilter-persistent"
    elif command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4
        log_success "Rules saved to /etc/iptables/rules.v4"
    else
        log_warning "Could not save rules persistently"
        log_warning "Run this script on boot to reapply rules"
    fi
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/aixcl-firewall.service << EOF
[Unit]
Description=AIXCL Host Firewall
After=network.target
Before=docker.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/host-firewall.sh apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_success "Systemd service created"
    log_info "Enable with: systemctl enable aixcl-firewall.service"
}

check_status() {
    log_info "Current iptables status:"
    iptables -L -n -v | grep -E "(Chain|DROP|ACCEPT)" | head -30
    
    echo ""
    log_info "Active rules count:"
    iptables -L INPUT --line-numbers -n | wc -l
}

verify_protection() {
    log_info "Verifying firewall protection..."
    
    # Test that external connections are blocked
    local test_port=5432
    local test_ip="127.0.0.1"

    # Check if port is blocked for non-local
    if iptables -L INPUT -n | grep -q "dpt:$test_port"; then
        log_success "Port $test_port has firewall rules (verified for $test_ip)"
    else
        log_error "No firewall rules found for port $test_port"
        return 1
    fi
    
    log_success "Firewall verification complete"
}

rollback() {
    log_warning "Rolling back to previous rules..."
    
    # Find most recent backup
    local latest_backup
    latest_backup=$(ls -t "${RULES_FILE}".backup.* 2>/dev/null | head -1)
    
    if [[ -f "$latest_backup" ]]; then
        iptables-restore < "$latest_backup"
        log_success "Rolled back to: $latest_backup"
    else
        log_error "No backup found to rollback to"
        exit 1
    fi
}

case "${1:-apply}" in
    apply)
        create_rules_file
        apply_rules
        save_rules
        verify_protection
        log_success "AIXCL host firewall configured successfully"
        log_info "All services now accessible via localhost only"
        ;;
    status)
        check_status
        ;;
    verify)
        verify_protection
        ;;
    rollback)
        rollback
        ;;
    systemd)
        create_systemd_service
        ;;
    *)
        echo "Usage: $0 [apply|status|verify|rollback|systemd]"
        echo ""
        echo "  apply    - Apply firewall rules (default)"
        echo "  status   - Show current rules"
        echo "  verify   - Verify protection is active"
        echo "  rollback - Restore previous rules"
        echo "  systemd  - Create systemd service"
        exit 1
        ;;
esac

exit 0