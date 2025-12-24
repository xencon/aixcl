#!/usr/bin/env bash
# Profile management library for AIXCL
# Defines profiles and provides functions to query profile information

# Valid profiles array
VALID_PROFILES=(usr dev ops sys)

# Runtime core services (always present in all profiles)
RUNTIME_CORE_SERVICES=(ollama llm-council)

# Profile descriptions
declare -A PROFILE_DESCRIPTIONS=(
    [usr]="User-oriented runtime (minimal footprint with database persistence)"
    [dev]="Developer workstation (UI + DB + admin tools)"
    [ops]="Observability-focused (monitoring/logging)"
    [sys]="System-oriented (complete stack with automation)"
)

# Profile service mappings
# Each profile includes runtime core services plus profile-specific services
declare -A PROFILE_SERVICES=(
    [usr]="ollama llm-council postgres"
    [dev]="ollama llm-council open-webui postgres pgadmin"
    [ops]="ollama llm-council postgres prometheus grafana loki promtail cadvisor node-exporter postgres-exporter nvidia-gpu-exporter"
    [sys]="ollama llm-council open-webui postgres pgadmin prometheus grafana loki promtail cadvisor node-exporter postgres-exporter nvidia-gpu-exporter watchtower"
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
get_profile_services() {
    local profile="$1"
    if [ -z "${PROFILE_SERVICES[$profile]}" ]; then
        echo ""
        return 1
    fi
    echo "${PROFILE_SERVICES[$profile]}"
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
    
    echo ""
    echo "Profile: $profile"
    echo "=================="
    echo "Description: $(get_profile_description "$profile")"
    echo ""
    echo "Services included:"
    local services
    services=($(get_profile_services "$profile"))
    for service in "${services[@]}"; do
        # Check if it's a runtime core service
        local is_core=false
        for core_service in "${RUNTIME_CORE_SERVICES[@]}"; do
            if [ "$service" = "$core_service" ]; then
                is_core=true
                break
            fi
        done
        
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

