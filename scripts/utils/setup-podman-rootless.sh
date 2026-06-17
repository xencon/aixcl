#!/usr/bin/env bash
#
# Podman Rootless Setup for AIXCL
# Phase 2: Complete Docker to Podman migration
#
# Usage:
#   ./scripts/utils/setup-podman-rootless.sh              # Setup rootless Podman
#   ./scripts/utils/setup-podman-rootless.sh --verify     # Verify configuration
#   ./scripts/utils/setup-podman-rootless.sh --reset     # Reset (WARNING: data loss)
#
# Security: Configures user namespaces, subordinate UIDs, rootless containers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
USER_NAME="$(whoami)"
USER_ID="$(id -u)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if running as root
check_not_root() {
  if [[ "$EUID" -eq 0 ]]; then
    log_error "This script must NOT be run as root for rootless Podman"
    log_error "Run as regular user: ./scripts/utils/setup-podman-rootless.sh"
    exit 1
  fi
}

# Check prerequisites
check_prerequisites() {
  log_step "Checking prerequisites..."
  
  # Check Podman installed
  if ! command -v podman >/dev/null 2>&1; then
    log_error "Podman is not installed"
    log_info "Install Podman:"
    log_info "  Fedora/RHEL: sudo dnf install podman"
    log_info "  Ubuntu/Debian: sudo apt-get install podman"
    log_info "  Arch: sudo pacman -S podman"
    exit 1
  fi
  
  # Check podman-compose
  if ! command -v podman-compose >/dev/null 2>&1; then
    log_error "podman-compose is not installed"
    log_info "Install: pip3 install podman-compose"
    exit 1
  fi
  
  # Check newuidmap/newgidmap for rootless
  if ! command -v newuidmap >/dev/null 2>&1; then
    log_error "newuidmap not found (required for rootless)"
    log_info "Install: sudo dnf install shadow-utils"
    exit 1
  fi
  
  log_info "Prerequisites satisfied"
}

# Configure subordinate UIDs/GIDs
setup_subuids() {
  log_step "Configuring subordinate UIDs/GIDs..."
  
  # Check if already configured
  if grep -q "^${USER_NAME}:" /etc/subuid 2>/dev/null && \
     grep -q "^${USER_NAME}:" /etc/subgid 2>/dev/null; then
    log_info "Subordinate UIDs/GIDs already configured"
    return 0
  fi
  
  log_warn "Requires sudo to configure subordinate UIDs/GIDs"
  
  # Add subordinate UIDs (100000-165535)
  if ! grep -q "^${USER_NAME}:" /etc/subuid 2>/dev/null; then
    echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subuid >/dev/null
    log_info "Added subordinate UIDs to /etc/subuid"
  fi
  
  # Add subordinate GIDs (100000-165535)
  if ! grep -q "^${USER_NAME}:" /etc/subgid 2>/dev/null; then
    echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subgid >/dev/null
    log_info "Added subordinate GIDs to /etc/subgid"
  fi
  
  # Verify sysctl settings
  if [[ -f /proc/sys/kernel/unprivileged_userns_clone ]]; then
    local current_val
    current_val="$(cat /proc/sys/kernel/unprivileged_userns_clone)"
    if [[ "$current_val" != "1" ]]; then
      log_warn "unprivileged_userns_clone is $current_val, should be 1"
      log_info "To enable (temporary): sudo sysctl kernel.unprivileged_userns_clone=1"
      log_info "To enable (permanent): echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf"
    fi
  fi
  
  log_info "Subordinate UID/GID configuration complete"
}

# Initialize rootless Podman
init_rootless() {
  log_step "Initializing rootless Podman..."
  
  # Initialize podman for user
  if ! podman info >/dev/null 2>&1; then
    log_info "Initializing podman storage..."
    podman system migrate || true
  fi
  
  # Check rootless configuration
  local rootless
  rootless="$(podman info --format '{{.Host.ServiceIsRootless}}' 2>/dev/null || echo 'unknown')"
  
  if [[ "$rootless" == "true" ]]; then
    log_info "Rootless mode confirmed"
  else
    log_warn "Rootless mode status: $rootless"
    log_info "Continuing with current configuration"
  fi
  
  log_info "Podman initialized"
}

# Setup Podman socket for Docker compatibility
setup_podman_socket() {
  log_step "Setting up Podman socket..."
  
  # Create systemd user directory
  mkdir -p "${HOME}/.config/systemd/user"
  
  # Check if socket is already running
  local socket_path
  socket_path="${XDG_RUNTIME_DIR:-/run/user/${USER_ID}}/podman/podman.sock"
  
  if [[ -S "$socket_path" ]]; then
    log_info "Podman socket already running: $socket_path"
  else
    log_info "Starting Podman socket..."
    
    # Enable and start podman socket
    systemctl --user enable podman.socket 2>/dev/null || true
    systemctl --user start podman.socket 2>/dev/null || {
      log_warn "Could not start podman.socket via systemd"
      log_info "Manual socket start: podman system service --time=0 unix://$socket_path &"
    }
    
    # Wait for socket
    local count=0
    while [[ ! -S "$socket_path" ]] && [[ $count -lt 10 ]]; do
      sleep 1
      count=$((count + 1))
    done
    
    if [[ -S "$socket_path" ]]; then
      log_info "Podman socket ready: $socket_path"
    else
      log_warn "Socket may not be available yet"
    fi
  fi
  
  # Export for Docker compatibility
  export DOCKER_HOST="unix://$socket_path"
  cat > "${PROJECT_ROOT}/.env.podman" << 'ENVEOF'
# AIXCL Podman Configuration
export DOCKER_BIN=podman
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
alias docker=podman
export GPG_TTY=$(tty)
export PATH="$HOME/.local/bin:$PATH"
ENVEOF
  log_info "DOCKER_HOST set for Docker compatibility"
}

# Configure volume permissions for rootless
setup_volume_permissions() {
  log_step "Configuring volume permissions..."
  
  # Create required directories with proper permissions
  local dirs=(
    "${PROJECT_ROOT}/logs"
    "${PROJECT_ROOT}/.security"
    "${PROJECT_ROOT}/.audit"
  )
  
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
      log_info "Created: $dir"
    fi
    # .security must be owner-only (vault-init verifies mode 700)
    if [[ "$dir" == *".security" ]]; then
      chmod 700 "$dir"
    else
      chmod u+rwx "$dir"
    fi
  done
  
  # Setup Podman volumes (rootless)
  log_info "Initializing Podman volumes..."
  "${PROJECT_ROOT}/scripts/utils/init-volumes.sh"
  
  log_info "Volume permissions configured"
}

# Generate NVIDIA CDI spec so Podman can allocate GPU devices to containers
setup_nvidia_cdi() {
  log_step "Configuring NVIDIA CDI for Podman GPU support..."

  if ! command -v nvidia-ctk >/dev/null 2>&1; then
    log_info "nvidia-ctk not found — skipping GPU setup (no NVIDIA Container Toolkit)"
    return 0
  fi

  if ! nvidia-smi >/dev/null 2>&1; then
    log_info "No NVIDIA GPU detected — skipping CDI setup"
    return 0
  fi

  # Check if CDI spec already has devices
  local cdi_count
  cdi_count=$(nvidia-ctk cdi list 2>/dev/null | grep -c 'nvidia.com' || echo 0)
  if [[ "$cdi_count" -gt 0 ]]; then
    log_info "[OK] NVIDIA CDI already configured ($cdi_count devices)"
    return 0
  fi

  log_info "Generating NVIDIA CDI specification..."

  # Try system-level CDI spec first, fall back to user-level
  if sudo mkdir -p /etc/cdi && sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>/dev/null; then
    log_info "[OK] NVIDIA CDI spec written to /etc/cdi/nvidia.yaml"
  else
    log_warn "Could not write system CDI spec — trying user-level"
    mkdir -p "${HOME}/.config/cdi"
    if nvidia-ctk cdi generate --output="${HOME}/.config/cdi/nvidia.yaml" 2>/dev/null; then
      log_info "[OK] NVIDIA CDI spec written to ${HOME}/.config/cdi/nvidia.yaml"
    else
      log_error "Failed to generate NVIDIA CDI spec"
      log_info "Run manually: sudo mkdir -p /etc/cdi && sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
      return 1
    fi
  fi

  # Verify
  local device_count
  device_count=$(nvidia-ctk cdi list 2>/dev/null | grep -c 'nvidia.com' || echo 0)
  if [[ "$device_count" -gt 0 ]]; then
    log_info "[OK] NVIDIA CDI devices available: $device_count"
  else
    log_warn "CDI spec written but no devices visible yet — a re-login may be required"
  fi
}

# Create Podman-specific configuration
create_podman_config() {
  log_step "Creating Podman configuration..."
  
  # Create containers.conf for rootless optimizations
  mkdir -p "${HOME}/.config/containers"
  
  # Auto-detect OCI runtime: prefer crun for rootless, fall back to runc
  local detected_runtime="runc"
  if command -v crun >/dev/null 2>&1; then
    detected_runtime="crun"
    log_info "Detected crun runtime (preferred for rootless)"
  elif command -v runc >/dev/null 2>&1; then
    detected_runtime="runc"
    log_info "Detected runc runtime (fallback)"
  else
    log_warn "No OCI runtime found (crun or runc). Podman may fail to start containers."
  fi
  
  cat > "${HOME}/.config/containers/containers.conf" << EOF
# AIXCL Podman Configuration
# Rootless container optimizations for adversarial environments

[containers]
# Use host network mode (AIXCL architectural requirement)
netns="host"
# Default capabilities - AIXCL services manage their own
cap_drop=["all"]
# Security options
seccomp_profile="/usr/share/containers/seccomp.json"
# annotations for systemd integration
annotations = ["run.oci.keep_original_groups=false"]

[engine]
# Runtime configuration - crun recommended for rootless, runc as fallback
runtime="${detected_runtime}"
# Enable cgroup management (requires delegation)
cgroup_manager="systemd"
# Events backend
events_logger="journald"

[network]
# Network backend - netavark for modern, cni for compatibility
network_backend="netavark"
# Required for host networking
default_network="host"

[registries]
# Pull policy for AIXCL images (match Docker behavior)
pull_policy="if_not_present"
EOF
  
  log_info "Podman configuration created: ${HOME}/.config/containers/containers.conf"
  
  # Create registries.conf for Docker Hub compatibility
  if [[ ! -f "${HOME}/.config/containers/registries.conf" ]]; then
    cat > "${HOME}/.config/containers/registries.conf" << 'EOF'
# AIXCL Registries Configuration
# Docker Hub as default (Podman prefers short names)

[registries.search]
registries = ['docker.io']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF
    log_info "Registries configuration created"
  fi
  
  # Create storage.conf for rootless optimizations
  cat > "${HOME}/.config/containers/storage.conf" << EOF
# AIXCL Rootless Storage Configuration
[storage]
driver = "overlay"
runroot = "${XDG_RUNTIME_DIR}/containers"
graphroot = "${HOME}/.local/share/containers/storage"

[storage.options]
# Enable fuse-overlayfs for rootless (better performance)
mount_program = "/usr/bin/fuse-overlayfs"

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
EOF
  
  log_info "Storage configuration created"
}

# Verify rootless setup
verify_setup() {
  log_step "Verifying rootless Podman setup..."
  
  local all_good=true
  
  # Check Podman version
  if command -v podman >/dev/null 2>&1; then
    local version
    version="$(podman --version | head -1)"
    log_info "[OK] Podman installed: $version"
  else
    log_error "[FAIL] Podman not found"
    all_good=false
  fi
  
  # Check podman-compose
  if command -v podman-compose >/dev/null 2>&1; then
    log_info "[OK] podman-compose installed"
  else
    log_error "[FAIL] podman-compose not found"
    all_good=false
  fi
  
  # Check subordinate UIDs
  if grep -q "^${USER_NAME}:" /etc/subuid 2>/dev/null; then
    log_info "[OK] Subordinate UIDs configured"
  else
    log_error "[FAIL] Subordinate UIDs not configured"
    all_good=false
  fi
  
  # Check subordinate GIDs
  if grep -q "^${USER_NAME}:" /etc/subgid 2>/dev/null; then
    log_info "[OK] Subordinate GIDs configured"
  else
    log_error "[FAIL] Subordinate GIDs not configured"
    all_good=false
  fi
  
  # Check rootless status
  local rootless
  rootless="$(podman info --format '{{.Host.ServiceIsRootless}}' 2>/dev/null || echo 'unknown')"
  if [[ "$rootless" == "true" ]]; then
    log_info "[OK] Running in rootless mode"
  else
    log_warn "[WARN] Rootless mode: $rootless"
  fi
  
  # Check socket
  local socket_path
  socket_path="${XDG_RUNTIME_DIR:-/run/user/${USER_ID}}/podman/podman.sock"
  if [[ -S "$socket_path" ]]; then
    log_info "[OK] Podman socket available: $socket_path"
  else
    log_warn "[WARN] Podman socket not found"
  fi
  
  # Test basic container operation
  if podman run --rm alpine:latest echo "test" >/dev/null 2>&1; then
    log_info "[OK] Test container ran successfully"
  else
    log_error "[FAIL] Test container failed"
    all_good=false
  fi

  # Check NVIDIA CDI (optional — only relevant when GPU hardware is present)
  if command -v nvidia-ctk >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    local cdi_count
    cdi_count=$(nvidia-ctk cdi list 2>/dev/null | grep -c 'nvidia.com' || echo 0)
    if [[ "$cdi_count" -gt 0 ]]; then
      log_info "[OK] NVIDIA CDI configured ($cdi_count devices)"
    else
      log_warn "[WARN] NVIDIA GPU detected but CDI not configured — GPU unavailable in containers"
      log_info "       Run: sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
    fi
  fi
  
  if $all_good; then
    log_info ""
    log_info "=== Rootless Podman Setup Complete ==="
    log_info ""
    log_info "To use Podman:"
    log_info "  export DOCKER_HOST=\"unix://${socket_path}\""
    log_info "  ./aixcl stack start --profile sys"
    log_info ""
    log_info "Podman will be auto-detected and preferred over Docker"
    return 0
  else
    log_error ""
    log_error "=== Setup Incomplete ==="
    log_error "Please fix the issues above and run again"
    return 1
  fi
}

# Reset rootless configuration (DANGER)
reset_rootless() {
  log_warn "This will RESET all Podman configuration and DATA!"
  log_warn "All containers, images, and volumes will be lost!"
  read -r -p "Are you absolutely sure? Type 'RESET' to confirm: " reply
  if [[ "$reply" != "RESET" ]]; then
    log_info "Aborted"
    exit 0
  fi
  
  log_step "Resetting Podman..."
  
  # Stop all containers
  podman stop -a 2>/dev/null || true
  podman rm -af 2>/dev/null || true
  
  # Remove images
  podman rmi -af 2>/dev/null || true
  
  # Reset storage
  podman system reset -f
  
  # Remove configuration
  rm -rf "${HOME}/.config/containers"
  rm -f "${PROJECT_ROOT}/.env.podman"
  
  log_info "Podman reset complete. Run setup again to reconfigure."
}

# Show usage
usage() {
  cat << EOF
Podman Rootless Setup for AIXCL

Usage: $0 [OPTION]

Options:
  (none)        Setup rootless Podman (default)
  --verify      Verify current configuration
  --reset       Reset Podman (DANGER - data loss)
  --help        Show this help message

Examples:
  $0              # First-time setup
  $0 --verify     # Check if setup is complete
  $0 --reset      # Start fresh (deletes all containers/images)

What This Does:
  1. Configures subordinate UIDs/GIDs (requires sudo)
  2. Initializes rootless Podman storage
  3. Sets up Podman socket for Docker compatibility
  4. Configures volume permissions
  5. Creates Podman-optimized configuration
  6. Generates NVIDIA CDI spec for GPU support (if NVIDIA GPU detected)

Security Benefits:
  - No daemon process (eliminates attack surface)
  - User namespace isolation (containers as non-root)
  - No privileged containers required
  - No Docker socket exposure
EOF
}

# Main
case "${1:-}" in
  --verify)
    verify_setup
    ;;
  --reset)
    reset_rootless
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  "")
    check_not_root
    check_prerequisites
    setup_subuids
    init_rootless
    setup_podman_socket
    setup_volume_permissions
    create_podman_config
    setup_nvidia_cdi
    verify_setup
    ;;
  *)
    log_error "Unknown option: $1"
    usage
    exit 1
    ;;
esac
