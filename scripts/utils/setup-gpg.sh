#!/usr/bin/env bash
#
# GPG Setup Script for AIXCL Contributors
# Phase 2: Configure GPG-signed commits for code integrity
#
# Usage:
#   ./scripts/utils/setup-gpg.sh              # Interactive GPG setup
#   ./scripts/utils/setup-gpg.sh --verify     # Verify configuration
#   ./scripts/utils/setup-gpg.sh --export     # Export public key for GitHub
#
# Security: Sets up GPG signing for cryptographically verified commits

set -euo pipefail

# Note: This script operates on user-global paths (~/.gnupg/, ~/.gitconfig)
# No project-relative paths needed for GPG key operations
# GPG signing test marker: issue-1046

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/core/color.sh"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if GPG is installed
check_gpg() {
  if ! command -v gpg >/dev/null 2>&1; then
    log_error "GPG is not installed"
    log_info "Install GPG:"
    log_info "  Fedora/RHEL: sudo dnf install gnupg2"
    log_info "  Ubuntu/Debian: sudo apt-get install gnupg2"
    log_info "  macOS: brew install gnupg"
    exit 1
  fi

  local version
  version=$(gpg --version | head -1) || true
  log_info "GPG found: $version"
}

# Check for existing GPG keys
check_existing_keys() {
  log_step "Checking for existing GPG keys..."

  local keys=""
  keys=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null) || true
  if echo "$keys" | grep -q "^sec"; then
    keys=$(echo "$keys" | grep -E "^sec") || true
  fi

  if [[ -n "$keys" ]]; then
    log_info "Existing GPG keys found:"
    gpg --list-secret-keys --keyid-format LONG
    echo ""
    log_warn "You can use an existing key or generate a new one"
    read -r -p "Generate new key? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
      log_info "Using existing key"
      return 0
    fi
  fi

  return 1
}

# Generate new GPG key
generate_key() {
  log_info "Generating GPG key..."

  local name email
  name="${GIT_AUTHOR_NAME:-${USER}}"
  email="${GIT_AUTHOR_EMAIL:-}"

  if [[ -z "$email" ]]; then
    read -r -p "Enter your email address: " email
  fi

  if [[ -z "$name" ]] || [[ "$name" == "$(whoami)" ]]; then
    read -r -p "Enter your full name: " name
  fi

  # Create batch configuration
  local batch_file
  batch_file=$(mktemp)
  cat > "$batch_file" << EOF
%echo Generating GPG key for AIXCL
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $name
Name-Email: $email
Expire-Date: 2y
%commit
%echo done
EOF

  gpg --batch --gen-key "$batch_file" 2>&1 || {
    log_error "Failed to generate GPG key"
    rm -f "$batch_file"
    exit 1
  }

  rm -f "$batch_file"
  log_info "GPG key generated successfully"
}

# Configure terminal for GPG pinentry
configure_terminal() {
  log_step "Configuring terminal for GPG pinentry..."

  # Check if GPG_TTY is already set
  if [[ -n "${GPG_TTY:-}" ]]; then
    log_info "GPG_TTY already set: $GPG_TTY"
    return 0
  fi

  # Detect shell configuration file
  local shell_rc=""
  case "${SHELL:-}" in
    */bash) shell_rc="$HOME/.bashrc" ;;
    */zsh)  shell_rc="$HOME/.zshrc" ;;
    */fish) shell_rc="$HOME/.config/fish/config.fish" ;;
    *)      shell_rc="$HOME/.profile" ;;
  esac

  # Add GPG_TTY export if not present
  if [[ -f "$shell_rc" ]] && ! grep -q "export GPG_TTY" "$shell_rc" 2>/dev/null; then
    echo "" >> "$shell_rc"
    echo "# GPG terminal configuration for signed commits" >> "$shell_rc"
    echo 'export GPG_TTY=$(tty)' >> "$shell_rc"
    log_info "Added 'export GPG_TTY=\$(tty)' to $shell_rc"
    log_warn "Please run: source $shell_rc  (or restart your terminal)"
  else
    log_info "GPG_TTY configuration already present or shell RC not found"
  fi

  # Also configure GPG agent for terminal use
  local gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf"
  if [[ -d "$HOME/.gnupg" ]]; then
    if [[ ! -f "$gpg_agent_conf" ]] || ! grep -q "pinentry-program" "$gpg_agent_conf" 2>/dev/null; then
      # Detect available pinentry
      local pinentry=""
      if command -v pinentry-curses >/dev/null 2>&1; then
        pinentry=$(command -v pinentry-curses)
      elif command -v pinentry-tty >/dev/null 2>&1; then
        pinentry=$(command -v pinentry-tty)
      elif command -v pinentry >/dev/null 2>&1; then
        pinentry=$(command -v pinentry)
      fi

      if [[ -n "$pinentry" ]]; then
        echo "pinentry-program $pinentry" >> "$gpg_agent_conf"
        log_info "Configured pinentry-program: $pinentry"
        # Restart gpg-agent
        gpg-connect-agent reloadagent /bye >/dev/null 2>&1 || true
        log_info "Restarted gpg-agent"
      fi
    fi
  fi
}

# Configure Git to use GPG
configure_git() {
  log_step "Configuring Git for GPG signing..."

  # Get the key ID
  local key_id=""
  local gpg_output=""

  gpg_output=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null) || true
  gpg_output=$(echo "$gpg_output" | grep -E "^sec" | head -1) || true

  if [[ -z "$gpg_output" ]]; then
    log_error "No GPG keys found"
    exit 1
  fi

  # Extract key ID from sec line format: "sec   rsa4096/KEY_ID ..."
  key_id=$(echo "$gpg_output" | awk '{print $2}' | cut -d'/' -f2) || true

  if [[ -z "$key_id" ]]; then
    log_error "Could not determine GPG key ID"
    exit 1
  fi

  log_info "Using GPG key: $key_id"

  # Configure Git
  git config --global user.signingkey "$key_id"
  git config --global commit.gpgsign true

  # Set GPG program (for macOS compatibility)
  if command -v gpg >/dev/null 2>&1; then
    git config --global gpg.program gpg
  fi

  log_info "Git configured for GPG signing"
  log_info "  user.signingkey: $key_id"
  log_info "  commit.gpgsign: true"
}

# Export public key for GitHub
export_key() {
  log_step "Exporting public key for GitHub..."

  local key_id
  key_id=$(git config --global user.signingkey 2>/dev/null || true)

  if [[ -z "$key_id" ]]; then
    log_error "No signing key configured in Git"
    exit 1
  fi

  log_info "Your GPG public key (paste into GitHub):"
  echo ""
  gpg --armor --export "$key_id"
  echo ""
  log_info "Add to GitHub: Settings > SSH and GPG keys > New GPG key"
  log_info "Key ID: $key_id"
}

# Verify setup
verify_setup() {
  log_step "Verifying GPG setup..."

  local all_good=true

  # Check GPG installed
  if command -v gpg >/dev/null 2>&1; then
    log_info "${ICON_SUCCESS:-✅} GPG installed"
  else
    log_error "${ICON_ERROR:-❌} GPG not found"
    all_good=false
  fi

  # Check for private keys
  local gpg_keys
  gpg_keys=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null) || true
  if echo "$gpg_keys" | grep -q "^sec"; then
    log_info "${ICON_SUCCESS:-✅} GPG private key exists"
  else
    log_error "${ICON_ERROR:-❌} No GPG private key found"
    all_good=false
  fi

  # Check Git configuration
  local signing_key
  signing_key=$(git config --global user.signingkey 2>/dev/null || true)
  if [[ -n "$signing_key" ]]; then
    log_info "${ICON_SUCCESS:-✅} Git signing key configured: $signing_key"
  else
    log_error "${ICON_ERROR:-❌} Git signing key not configured"
    all_good=false
  fi

  # Check auto-sign enabled
  if [[ "$(git config --global commit.gpgsign 2>/dev/null)" == "true" ]]; then
    log_info "${ICON_SUCCESS:-✅} Git auto-sign enabled"
  else
    log_warn "${ICON_WARNING:-⚠️} Git auto-sign not enabled (run: git config --global commit.gpgsign true)"
  fi

  # Test signing
  log_step "Testing GPG signing..."
  local test_file
  test_file=$(mktemp)
  echo "test" > "$test_file"

  if gpg --detach-sign --armor "$test_file" 2>/dev/null; then
    log_info "${ICON_SUCCESS:-✅} GPG signing works"
    rm -f "$test_file" "$test_file.asc"
  else
    log_error "${ICON_ERROR:-❌} GPG signing test failed"
    rm -f "$test_file"
    all_good=false
  fi

  if $all_good; then
    log_info ""
    log_info "=== GPG Setup Complete ==="
    log_info ""
    log_info "Your commits will now be automatically signed"
    log_info "Commits will show 'Verified' badge on GitHub"
    log_info ""
    log_info "To export your public key:"
    log_info "  $0 --export"
    return 0
  else
    log_error ""
    log_error "=== Setup Incomplete ==="
    log_error "Please fix the issues above"
    return 1
  fi
}

# Show usage
usage() {
  cat << EOF
GPG Setup for AIXCL Signed Commits

Usage: $0 [OPTION]

Options:
  (none)        Interactive GPG setup (default)
  --verify      Verify current GPG configuration
  --export      Export public key for GitHub
  --help        Show this help message

Examples:
  $0              # First-time setup
  $0 --verify     # Check if GPG is configured
  $0 --export     # Get public key for GitHub

What This Does:
  1. Checks for GPG installation
  2. Generates 4096-bit RSA key (if needed)
  3. Configures Git for automatic signing
  4. Verifies the setup works

Security Benefits:
  - Cryptographic proof of authorship
  - Tamper-evident commit history
  - Protection against credential compromise

After Setup:
  - Commits are automatically signed
  - Push to GitHub shows 'Verified' badge
  - Required for main/dev branch commits
EOF
}

# Main
case "${1:-}" in
  --verify)
    verify_setup
    ;;
  --export)
    export_key
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  "")
    check_gpg
    configure_terminal
    if ! check_existing_keys; then
      generate_key
    fi
    configure_git
    verify_setup
    ;;
  *)
    log_error "Unknown option: $1"
    usage
    exit 1
    ;;
esac
