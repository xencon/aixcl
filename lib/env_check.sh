#!/usr/bin/env bash
# Environment validation functions

# Source dependencies
source "${BASH_SOURCE%/*}/common.sh"
source "${BASH_SOURCE%/*}/color.sh"

check_env() {
    echo "Checking environment dependencies..."
    local missing_deps=0

    local is_wsl=0
    if grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null || \
       grep -qi "microsoft" /proc/version 2>/dev/null; then
        is_wsl=1
        print_info "Windows Subsystem for Linux detected. GPU checks rely on nvidia-smi/docker instead of lspci."
    fi

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "   Install from: https://docs.docker.com/get-docker/"
        missing_deps=1
    else
        print_success "Docker is installed"
        # Check if Docker daemon is running
        if ! docker info &> /dev/null; then
            print_error "Docker daemon is not running"
            echo "   Start with: sudo systemctl start docker"
            missing_deps=1
        else
            print_success "Docker daemon is running"
        fi
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        echo "   Install from: https://docs.docker.com/compose/install/"
        missing_deps=1
    else
        print_success "Docker Compose is installed"
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
            elif has_nvidia; then
                print_success "NVIDIA GPU support detected via Docker runtime checks"
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
        print_warning "NVIDIA Container Toolkit not found (optional)"
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
    local available_space=$(df -BG "$(pwd)" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "Insufficient disk space. Required: ${required_space}GB, Available: ${available_space}GB"
        missing_deps=1
    else
        print_success "Sufficient disk space available"
    fi

    # Check memory
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 8 ]; then
        print_warning "Low memory detected (${total_mem}GB). Recommended: 8GB+"
    else
        print_success "Sufficient memory available"
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
