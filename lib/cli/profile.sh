#!/usr/bin/env bash
# Profile management library for AIXCL
# Defines profiles and provides functions to query profile information
#
# IMPORTANT: When adding a new service, you MUST update both:
#   1. This file (lib/cli/profile.sh) - service mappings for each profile
#   2. services/docker-compose.yml - service definition
# See: docs/developer/adding-services.md for complete checklist

# Valid profiles array
VALID_PROFILES=(usr dev ops sys)

# Engine detection
INFERENCE_ENGINE=${INFERENCE_ENGINE:-ollama}
if [[ "$INFERENCE_ENGINE" != "ollama" && "$INFERENCE_ENGINE" != "vllm" && "$INFERENCE_ENGINE" != "llamacpp" ]]; then
    INFERENCE_ENGINE="ollama"
fi

# Runtime core services managed by Docker Compose (always present in all profiles).
# NOTE: Use get_runtime_core_services() to get current value after .env loading
# shellcheck disable=SC2034
RUNTIME_CORE_SERVICES=("${INFERENCE_ENGINE:-ollama}")

# Get current runtime core services (respects INFERENCE_ENGINE from .env)
get_runtime_core_services() {
    echo "${INFERENCE_ENGINE:-ollama}"
}

# Profile descriptions
declare -A PROFILE_DESCRIPTIONS=(
    [usr]="User-oriented runtime (minimal footprint with database persistence)"
    [dev]="Developer workstation (UI + DB + admin tools)"
    [ops]="Observability-focused (monitoring/logging)"
    [sys]="System-oriented (complete stack)"
)

# Profile service mappings (Docker-managed services only)
# Each profile includes runtime core services plus profile-specific services.
# NOTE: This is now a function to ensure INFERENCE_ENGINE is read after .env loading
get_profile_services_for_profile() {
    local profile="$1"
    # Use current INFERENCE_ENGINE value (may have been updated after .env loading)
    local engine="${INFERENCE_ENGINE:-ollama}"
    
    case "$profile" in
        usr)
            echo "$engine postgres"
            ;;
        dev)
            echo "$engine open-webui postgres pgadmin"
            ;;
        ops)
            echo "$engine postgres prometheus grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter"
            ;;
        sys)
            echo "$engine open-webui postgres pgadmin prometheus alertmanager grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

# Deprecated: Static array kept for backward compatibility
# Use get_profile_services_for_profile() or get_profile_services() instead
# shellcheck disable=SC2034
declare -A PROFILE_SERVICES=(
    [usr]="INFERENCE_ENGINE_PLACEHOLDER postgres"
    [dev]="INFERENCE_ENGINE_PLACEHOLDER open-webui postgres pgadmin"
    [ops]="INFERENCE_ENGINE_PLACEHOLDER postgres prometheus grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter"
    [sys]="INFERENCE_ENGINE_PLACEHOLDER open-webui postgres pgadmin prometheus alertmanager grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter"
)

# Profile database storage settings
# All profiles use database storage for persistence
declare -A PROFILE_DB_STORAGE=(
    [usr]="true"
    [dev]="true"
    [ops]="true"
    [sys]="true"
)

# Check if a profile name is valid
is_valid_profile() {
    local profile="$1"
    if [ -z "$profile" ]; then
        return 1
    fi
    for valid_profile in "${VALID_PROFILES[@]}"; do
        if [ "$profile" = "$valid_profile" ]; then
            return 0
        fi
    done
    return 1
}

# Get description for a profile
get_profile_description() {
    local profile="$1"
    if [ -z "${PROFILE_DESCRIPTIONS[$profile]}" ]; then
        echo "Unknown profile"
        return 1
    fi
    echo "${PROFILE_DESCRIPTIONS[$profile]}"
}

# Get services for a profile
# Uses current INFERENCE_ENGINE value from environment
get_profile_services() {
    local profile="$1"
    local services
    services=$(get_profile_services_for_profile "$profile")
    
    if [[ -z "$services" ]]; then
        return 1
    fi
    
    # Exclude GPU exporter if NVIDIA Container Toolkit is not available
    # (even if hardware exists, we need the toolkit for container GPU access)
    if ! has_nvidia_container_toolkit; then
        services=$(echo "$services" | sed 's/nvidia-gpu-exporter//g' | xargs)
    fi
    
    echo "$services"
}

# Get database storage enabled setting for a profile
get_profile_db_storage_enabled() {
    local profile="$1"
    if [ -z "${PROFILE_DB_STORAGE[$profile]}" ]; then
        echo "true"  # Default to true if profile not found
        return 1
    fi
    echo "${PROFILE_DB_STORAGE[$profile]}"
}

# List all available profiles with descriptions
list_profiles() {
    echo ""
    echo "Available profiles:"
    echo "==================="
    echo ""
    for profile in "${VALID_PROFILES[@]}"; do
        echo "  - $profile: $(get_profile_description "$profile")"
    done
    echo ""
    echo "For detailed profile information, see: docs/architecture/governance/02_profiles.md"
}

# Print detailed information about a profile
print_profile_info() {
    local profile="$1"
    
    if ! is_valid_profile "$profile"; then
        echo "Error: Invalid profile: $profile" >&2
        return 1
    fi
    
    # Get current runtime core service (respects INFERENCE_ENGINE from .env)
    local current_engine
    current_engine=$(get_runtime_core_services)
    
    echo ""
    echo "Profile: $profile"
    echo "=================="
    echo "Description: $(get_profile_description "$profile")"
    echo ""
    echo "Services included:"
    local services
    read -r -a services <<< "$(get_profile_services "$profile")"
    for service in "${services[@]}"; do
        # Check if it's a runtime core service
        local is_core=false
        if [ "$service" = "$current_engine" ]; then
            is_core=true
        fi
        
        if [ "$is_core" = true ]; then
            echo "  - $service (runtime core)"
        else
            echo "  - $service"
        fi
    done
    echo ""
    echo "Database storage: $(get_profile_db_storage_enabled "$profile")"
    echo ""
}

# Export functions for use in other modules
export -f is_valid_profile get_profile_description get_profile_services
export -f get_profile_db_storage_enabled list_profiles print_profile_info
export -f get_profile_services_for_profile get_runtime_core_services

