#!/usr/bin/env bash
# Environment validation functions

# Source dependencies
# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/color.sh"

# Classify a container's PID 1 user for the UID audit (#1822).
# Allowlist: containers where PID 1 legitimately runs as root. Keep this
# list short and each entry justified; anything else on root gets a warning.
_uid_audit_verdict() {
    local name="$1"
    local user="$2"
    local allowlist=(
        "cadvisor"              # needs CAP_SYS_PTRACE for host-wide metrics
        "nvidia-gpu-exporter"   # needs direct GPU device access
    )

    if [ "$user" != "0" ] && [ "$user" != "root" ]; then
        echo "ok"
        return 0
    fi

    local entry
    for entry in "${allowlist[@]}"; do
        if [ "$name" = "$entry" ]; then
            echo "intentional-root"
            return 0
        fi
    done
    echo "unexpected-root"
}

check_env() {
    echo "Checking environment dependencies..."
    local missing_deps=0

    local is_wsl=0
    if grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null || \
       grep -qi "microsoft" /proc/version 2>/dev/null; then
        is_wsl=1
        print_info "Windows Subsystem for Linux detected. GPU checks rely on nvidia-smi/docker instead of lspci."
    fi

    # Check Docker / Podman
    local engine_found=0

    if command -v podman &> /dev/null; then
        print_success "Podman is installed"
        engine_found=1
        if ! podman info &> /dev/null; then
            print_error "Podman service is not running or accessible"
            missing_deps=1
        else
            print_success "Podman service is running"
        fi
    elif command -v docker &> /dev/null; then
        print_success "Docker is installed"
        engine_found=1
        if ! ${DOCKER_BIN:-docker} info &> /dev/null; then
            print_error "Docker daemon is not running"
            echo "   Start with: sudo systemctl start docker"
            missing_deps=1
        else
            print_success "Docker daemon is running"
        fi
    else
        print_error "Neither Docker nor Podman is installed"
        echo "   Install Docker from: https://docs.docker.com/get-docker/"
        echo "   Or Podman from: https://podman.io/getting-started/installation"
        missing_deps=1
    fi

    # Check for rootless mode
    if [ $engine_found -eq 1 ]; then
        # Explicit diagnostic for Podman (mirrors README manual verification step)
        if command -v podman &> /dev/null; then
            local rootless_info
            rootless_info=$(podman info 2>/dev/null | grep "rootless" || true)
            if [ -n "$rootless_info" ]; then
                print_info "Podman rootless status: $rootless_info"
            fi
        fi

        if is_rootless; then
            print_success "Rootless container engine detected (Enhanced Security)"
        else
            # Get current profile if possible (it might not be loaded yet in utils check-env)
            local profile="${PROFILE:-}"
            if [[ "$profile" == "bld" || "$profile" == "sys" ]]; then
                print_warning "Root container engine detected in production profile ($profile)."
                echo "   Consider migrating to rootless Podman/Docker for better security isolation."
            else
                print_info "Running in rootful mode (standard for local development)"
            fi
        fi
    fi

    # Check Docker Compose / podman-compose
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose is installed"
    elif docker compose version &> /dev/null; then
        print_success "Docker Compose (V2 plugin) is available"
    elif command -v podman-compose &> /dev/null; then
        print_success "podman-compose is installed"
    else
        print_error "No Docker Compose compatible tool found"
        echo "   Install from: https://docs.docker.com/compose/install/"
        missing_deps=1
    fi

    # Check Bash shell
    echo -e "\nChecking shell environment..."
    if ! command -v bash &> /dev/null; then
        print_error "Bash shell is not installed"
        echo "   Install bash to continue: https://www.gnu.org/software/bash/"
        missing_deps=1
    else
        print_success "Bash shell is available"
    fi

    # Check NVIDIA drivers and toolkit (optional)
    echo -e "\nChecking NVIDIA support..."
    local os_id=""
    local os_pretty=""
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_id="${ID:-}"
        os_pretty="${PRETTY_NAME:-$os_id}"
    fi

    if [ -n "$os_pretty" ]; then
        echo "Detected operating system: $os_pretty"
    else
        print_warning "Could not determine operating system (using generic GPU checks)"
    fi

    local has_gpu_hardware=0
    if command -v lspci &> /dev/null; then
        if lspci | grep -qi "nvidia"; then
            print_success "NVIDIA GPU hardware detected"
            has_gpu_hardware=1
        else
            print_warning "NVIDIA GPU hardware not detected"
        fi
    else
        if [ "$is_wsl" -eq 1 ]; then
            print_warning "lspci is unavailable in WSL; falling back to runtime detection."
            if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
                print_success "NVIDIA GPU support detected via nvidia-smi"
                has_gpu_hardware=1
            elif [ -e /dev/dxg ]; then
                print_success "NVIDIA GPU hardware exposed via /dev/dxg"
                has_gpu_hardware=1
            elif has_nvidia_container_toolkit; then
                print_success "NVIDIA GPU support detected via Container Toolkit"
                has_gpu_hardware=1
            else
                print_info "Unable to confirm NVIDIA GPU support in WSL."
                echo "   If you expect GPU access, ensure you've installed the Windows CUDA drivers"
                echo "   and enabled GPU sharing in WSL: https://learn.microsoft.com/windows/wsl/tutorials/gpu-compute"
            fi
        else
            print_warning "Unable to detect GPU hardware (missing lspci command)"
            echo "   Install pciutils to enable hardware detection (e.g., sudo apt install pciutils)"
        fi
    fi

    if command -v nvidia-smi &> /dev/null; then
        print_success "NVIDIA drivers installed"
    elif [ "$has_gpu_hardware" -eq 1 ]; then
        print_error "NVIDIA drivers not found"
        case "$os_id" in
            ubuntu|debian)
                echo "   Install drivers with: sudo ubuntu-drivers autoinstall"
                ;;
            fedora)
                echo "   Install drivers with RPM Fusion: sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda"
                ;;
            *)
                echo "   Refer to NVIDIA docs for driver installation: https://www.nvidia.com/Download/index.aspx"
                ;;
        esac
    else
        print_warning "NVIDIA drivers not found (no GPU detected)"
    fi

    # Check NVIDIA Container Toolkit
    if command -v nvidia-container-cli &> /dev/null; then
        print_success "NVIDIA Container Toolkit installed"
    elif command -v dpkg &> /dev/null && dpkg -l | grep -q nvidia-container-toolkit; then
        print_success "NVIDIA Container Toolkit installed"
    elif command -v rpm &> /dev/null && rpm -qa | grep -q nvidia-container-toolkit; then
        print_success "NVIDIA Container Toolkit installed"
    else
        print_warning "NVIDIA Container Toolkit not found (REQUIRED for GPU support; falling back to CPU)"
        case "$os_id" in
            ubuntu|debian)
                echo "   Install toolkit with:"
                echo "   sudo apt update && sudo apt install -y nvidia-container-toolkit"
                ;;
            fedora)
                echo "   Install toolkit with:"
                echo "   sudo dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/fedora/libnvidia-container.repo"
                echo "   sudo dnf install -y nvidia-container-toolkit"
                ;;
            *)
                echo "   Install instructions: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
                ;;
        esac
    fi

    # Check available disk space
    echo -e "\nChecking system resources..."
    local required_space=10 # GB
    local available_space
    # Use -k and manual conversion for better portability, or ensure output format
    available_space=$(df -k "${SCRIPT_DIR}" | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
    # Handle line wrapping in df output
    if [ -z "$available_space" ] || [[ ! "$available_space" =~ ^[0-9]+$ ]]; then
        available_space=$(df -k "${SCRIPT_DIR}" | awk 'END{print $3}' 2>/dev/null || echo "0")
    fi

    # Convert KB to GB (roughly)
    local available_gb=$((available_space / 1024 / 1024))

    if [ "$available_gb" -lt "$required_space" ]; then
        print_warning "Low disk space. Required: ${required_space}GB, Available: ${available_gb}GB"
        # Only fail if it's extremely low, otherwise just warn for CI/small environments
        if [ "$available_gb" -lt 2 ]; then
            print_error "Extremely low disk space detected."
            missing_deps=1
        fi
    else
        print_success "Sufficient disk space available (${available_gb}GB)"
    fi

    # Check memory
    local total_mem
    total_mem=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "")

    if [[ -n "$total_mem" && "$total_mem" =~ ^[0-9]+$ ]]; then
        if [ "$total_mem" -lt 8 ]; then
            print_warning "Low memory detected (${total_mem}GB). Recommended: 8GB+"
        else
            print_success "Sufficient memory available (${total_mem}GB)"
        fi
    else
        print_warning "Could not determine total memory (skipping check)"
    fi

    # Check .env configuration if it exists
    echo -e "\nChecking environment configuration..."
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        local env_errors=0
        # Check for required variables
        # NOTE: Passwords are managed by Vault. Do not require them in .env.
        for var in POSTGRES_USER POSTGRES_DATABASE; do
            if ! grep -q "^[[:space:]]*${var}=" "${SCRIPT_DIR}/.env"; then
                print_error "Missing required environment variable in .env: $var"
                env_errors=1
            fi
        done

        # Validate database name using the shared function
        local db_name
        db_name=$(grep "^[[:space:]]*POSTGRES_DATABASE=" "${SCRIPT_DIR}/.env" | head -1 | cut -d'=' -f2 | sed "s/['\"]//g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$db_name" ]; then
            local val_out
            if ! val_out=$(validate_db_name "$db_name" "POSTGRES_DATABASE" 2>&1); then
                print_error "$val_out"
                env_errors=1
            fi
        fi

        if [ $env_errors -eq 1 ]; then
            missing_deps=1
        else
            print_success ".env configuration is valid"
        fi
    else
        print_info ".env file not found (will be created on first start)"
    fi

    # Check developer tooling (warnings only -- does not block stack)
    echo -e "\nChecking developer tooling..."

    if command -v pre-commit &>/dev/null; then
        local pc_version
        pc_version=$(pre-commit --version 2>/dev/null | head -1 || echo "version unknown")
        print_success "pre-commit installed ($pc_version)"
        if [ -f ".git/hooks/pre-commit" ]; then
            print_success "pre-commit hooks activated"
        else
            print_warning "pre-commit installed but hooks not activated"
            echo "   Run: pre-commit install"
        fi
    else
        print_warning "pre-commit not installed -- local quality gates will not run"
        echo "   Install: pip install pre-commit"
        echo "   Activate: pre-commit install"
    fi

    if command -v gitleaks &>/dev/null; then
        local gl_version
        gl_version=$(gitleaks version 2>/dev/null | head -1 || echo "version unknown")
        print_success "gitleaks installed ($gl_version)"
    else
        print_warning "gitleaks not installed -- secret scanning runs CI-only until installed"
        echo "   Install v8.21.2+ from: https://github.com/gitleaks/gitleaks/releases"
    fi

    if command -v git-cliff &>/dev/null; then
        local gc_version
        gc_version=$(git-cliff --version 2>/dev/null | head -1 || echo "version unknown")
        print_success "git-cliff installed ($gc_version)"
    else
        print_warning "git-cliff not installed -- required for the release skill"
        echo "   Install from: https://github.com/orhun/git-cliff/releases"
    fi

    if command -v yamllint &>/dev/null; then
        local yl_version
        yl_version=$(yamllint --version 2>/dev/null | head -1 || echo "version unknown")
        print_success "yamllint installed ($yl_version)"
    else
        print_warning "yamllint not installed -- YAML validation runs CI-only until installed"
        echo "   Install: pip install yamllint==1.35.1  or  sudo apt-get install yamllint"
    fi

    # Per-container UID audit (#1822): report the user PID 1 ACTUALLY runs
    # as (via the process table), not the image's configured user --
    # entrypoints that fail to drop privileges (the #1674 interpolation
    # bug) only show up in the live process table.
    echo -e "\nChecking container users..."
    local audit_bin=""
    if command -v podman &> /dev/null && podman info &> /dev/null; then
        audit_bin="podman"
    elif command -v docker &> /dev/null && ${DOCKER_BIN:-docker} info &> /dev/null; then
        audit_bin="${DOCKER_BIN:-docker}"
    fi

    local audit_names=""
    if [ -n "$audit_bin" ]; then
        audit_names=$($audit_bin ps --format '{{.Names}}' 2>/dev/null || true)
    fi

    if [ -z "$audit_names" ]; then
        print_info "Stack is not running (container UID audit skipped)"
    else
        local cname cuser verdict
        while IFS= read -r cname; do
            [ -z "$cname" ] && continue
            if [ "$audit_bin" = "podman" ]; then
                cuser=$(podman top "$cname" user 2>/dev/null | sed -n '2p')
            else
                cuser=$($audit_bin top "$cname" 2>/dev/null | awk 'NR==2 {print $1}')
            fi
            if [ -z "$cuser" ]; then
                print_warning "$cname: could not determine PID 1 user"
                continue
            fi
            verdict=$(_uid_audit_verdict "$cname" "$cuser")
            case "$verdict" in
                ok)
                    print_success "$cname runs as non-root ($cuser)"
                    ;;
                intentional-root)
                    print_info "$cname runs as root (known-intentional; see allowlist in lib/core/env_check.sh)"
                    ;;
                unexpected-root)
                    print_warning "$cname runs as root (unexpected -- investigate)"
                    ;;
            esac
        done <<< "$audit_names"
    fi

    if [ $missing_deps -eq 1 ]; then
        echo -e "\n"
        print_error "Environment check failed. Please address the issues above."
        return 1
    else
        echo -e "\n"
        print_success "Environment check passed! You're ready to run AIXCL."
        return 0
    fi
}
