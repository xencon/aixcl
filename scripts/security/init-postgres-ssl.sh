#!/bin/bash
#
# PostgreSQL SSL Certificate Generation
# Phase 1.6: Enable SSL/TLS encryption for database connections
#
# Usage:
#   ./scripts/security/init-postgres-ssl.sh              # Generate certificates
#   ./scripts/security/init-postgres-ssl.sh --clean      # Remove certificates (DANGER)
#   ./scripts/security/init-postgres-ssl.sh --verify   # Verify certificates exist
#
# Security: Creates 2048-bit RSA certificates with 365-day validity
#           Certificate Authority (CA) signs server certificate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CERT_DIR="${PROJECT_ROOT}/.security/postgres-certs"
DAYS_VALID=365
KEY_SIZE=2048

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if OpenSSL is available
check_openssl() {
  if ! command -v openssl >/dev/null 2>&1; then
    log_error "OpenSSL is not installed"
    exit 1
  fi
}

# Create certificate directory
setup_cert_dir() {
  if [[ ! -d "$CERT_DIR" ]]; then
    log_info "Creating certificate directory: $CERT_DIR"
    mkdir -p "$CERT_DIR"
  fi
  
  # Ensure proper permissions
  chmod 700 "$CERT_DIR"
}

# Generate Certificate Authority (CA)
generate_ca() {
  log_info "Generating Certificate Authority (CA)..."
  
  local ca_key="${CERT_DIR}/ca-key.pem"
  local ca_cert="${CERT_DIR}/ca-cert.pem"
  
  # Generate CA private key
  openssl genrsa -out "$ca_key" $KEY_SIZE 2>/dev/null
  
  # Generate CA certificate (self-signed)
  openssl req -new -x509 -days $DAYS_VALID -key "$ca_key" \
    -out "$ca_cert" \
    -subj "/C=US/ST=Security/O=AIXCL/CN=AIXCL-PostgreSQL-CA" \
    2>/dev/null
  
  # Restrict permissions
  chmod 600 "$ca_key"
  chmod 644 "$ca_cert"
  
  log_info "CA certificate generated: $ca_cert"
}

# Generate server certificate (signed by CA)
generate_server_cert() {
  log_info "Generating PostgreSQL server certificate..."
  
  local ca_cert="${CERT_DIR}/ca-cert.pem"
  local ca_key="${CERT_DIR}/ca-key.pem"
  local server_key="${CERT_DIR}/server-key.pem"
  local server_csr="${CERT_DIR}/server.csr"
  local server_cert="${CERT_DIR}/server-cert.pem"
  
  # Generate server private key
  openssl genrsa -out "$server_key" $KEY_SIZE 2>/dev/null
  
  # Create certificate signing request (CSR)
  openssl req -new -key "$server_key" \
    -out "$server_csr" \
    -subj "/C=US/ST=Security/O=AIXCL/CN=localhost" \
    2>/dev/null
  
  # Sign server certificate with CA
  openssl x509 -req -days $DAYS_VALID -in "$server_csr" \
    -CA "$ca_cert" -CAkey "$ca_key" \
    -CAcreateserial -out "$server_cert" \
    2>/dev/null
  
  # Remove CSR (no longer needed)
  rm -f "$server_csr"
  rm -f "${CERT_DIR}/ca-cert.srl"
  
  # Restrict permissions
  chmod 600 "$server_key"
  chmod 644 "$server_cert"
  
  log_info "Server certificate generated: $server_cert"
}

# Initialize all certificates
init_certs() {
  log_info "Initializing PostgreSQL SSL certificates..."
  
  check_openssl
  setup_cert_dir
  
  # Generate CA and server certificates
  generate_ca
  generate_server_cert
  
  log_info ""
  log_info "SSL certificates initialized successfully!"
  log_info "Certificate directory: $CERT_DIR"
  log_info ""
  log_info "Files generated:"
  log_info "  - CA certificate:     ca-cert.pem"
  log_info "  - CA private key:     ca-key.pem (keep secure)"
  log_info "  - Server certificate: server-cert.pem"
  log_info "  - Server private key: server-key.pem (keep secure)"
  log_info ""
  log_info "To use SSL, restart PostgreSQL with:"
  log_info "  ./aixcl stack restart postgres"
}

# Clean up certificates
clean_certs() {
  log_warn "This will DELETE all PostgreSQL SSL certificates!"
  log_warn "Database connections will fail until new certificates are generated."
  read -r -p "Are you absolutely sure? Type 'DELETE' to confirm: " reply
  if [[ "$reply" != "DELETE" ]]; then
    log_info "Aborted"
    exit 0
  fi
  
  if [[ -d "$CERT_DIR" ]]; then
    rm -rf "$CERT_DIR"
    log_info "Certificates removed: $CERT_DIR"
  else
    log_info "No certificates to remove"
  fi
}

# Verify certificates exist
verify_certs() {
  log_info "Verifying PostgreSQL SSL certificates..."
  
  local all_exist=true
  local required_files=("ca-cert.pem" "ca-key.pem" "server-cert.pem" "server-key.pem")
  
  if [[ ! -d "$CERT_DIR" ]]; then
    log_error "Certificate directory does not exist: $CERT_DIR"
    return 1
  fi
  
  for file in "${required_files[@]}"; do
    if [[ -f "${CERT_DIR}/${file}" ]]; then
      log_info "[OK] ${file} exists"
    else
      log_error "[MISSING] ${file}"
      all_exist=false
    fi
  done
  
  if $all_exist; then
    log_info "All certificates verified!"
    
    # Verify certificate validity
    local cert_file="${CERT_DIR}/server-cert.pem"
    local cert_info
    cert_info=$(openssl x509 -in "$cert_file" -noout -dates -subject 2>/dev/null)
    log_info ""
    log_info "Server certificate details:"
    echo "$cert_info" | while read -r line; do
      log_info "  $line"
    done
    
    return 0
  else
    log_error "Some certificates are missing. Run: $0"
    return 1
  fi
}

# Show usage
usage() {
  cat << EOF
PostgreSQL SSL Certificate Management

Usage: $0 [OPTION]

Options:
  (none)        Generate all certificates (default)
  --clean       Remove all certificates (DANGER - requires regeneration)
  --verify      Verify certificates exist and are valid
  --help        Show this help message

Examples:
  $0                    # Generate certificates for first time
  $0 --verify          # Check certificates before starting services
  $0 --clean           # Rotate certificates (must regenerate after)

Security Notes:
  - Uses 2048-bit RSA keys with SHA-256 signatures
  - Certificates valid for 365 days
  - CA private key must be kept secure
  - Server certificates are signed by the CA
  - Private keys have 600 permissions (owner only)
EOF
}

# Main
case "${1:-}" in
  --clean)
    clean_certs
    ;;
  --verify)
    verify_certs
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  "")
    init_certs
    ;;
  *)
    log_error "Unknown option: $1"
    usage
    exit 1
    ;;
esac
