#!/usr/bin/env bash
# Profile management library for AIXCL
# Defines profiles and provides functions to query profile information
#
# IMPORTANT: Profile service composition is now authoritative in
# config/profiles/<profile>.env. This file loads those env files and falls
# back to the hard-coded lists below only if an env file is missing or empty.
# When adding a new service, update BOTH:
#   1. config/profiles/<profile>.env - add the service name to PROFILE_SERVICES
#   2. services/docker-compose.yml - define the service
# See: docs/developer/adding-services.md for complete checklist

# Get the repository root relative to this script.
# Intentionally namespaced to avoid overwriting the caller's SCRIPT_DIR.
_PROFILE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Valid profiles array
# shellcheck disable=SC2034
VALID_PROFILES=(bld sys)

# Engine detection (Ollama is the only supported engine)
INFERENCE_ENGINE=${INFERENCE_ENGINE:-ollama}
if [[ "$INFERENCE_ENGINE" != "ollama" ]]; then
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
    [bld]="Builder-focused (monitoring/logging)"
    [sys]="System-oriented (complete stack)"
)

# Load PROFILE_SERVICES from the authoritative env file for a profile.
# Runs in a subshell to avoid leaking profile-specific variables into the
# calling shell. Expands $INFERENCE_ENGINE using the current environment.
_load_profile_services() {
    local profile="$1"
    local env_file="${_PROFILE_SCRIPT_DIR}/config/profiles/${profile}.env"
    (
        # shellcheck disable=SC1090
        source "$env_file" 2>/dev/null || true
        printf '%s' "${PROFILE_SERVICES:-}"
    )
}

# Derive the Vault bootstrap agent list for a profile directly from
# services/docker-compose.yml service names matching ^vault-agent-.*-bootstrap$,
# then intersect with the active profile's services. This eliminates the need
# to maintain the same list in lib/cli/profile.sh and lib/aixcl/commands/stack.sh.
_get_vault_bootstrap_agents() {
    local profile="$1"
    local compose_file="${_PROFILE_SCRIPT_DIR}/services/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        return 0
    fi

    if ! python3 -c 'import yaml' 2>/dev/null; then
        echo "[ERROR] python3 PyYAML is required to discover Vault bootstrap agents." >&2
        echo "        Install with: pip3 install pyyaml" >&2
        return 1
    fi

    local all_agents
    all_agents=$(python3 -c '
import re, sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
for name in sorted(data.get("services", {}).keys()):
    if re.match(r"^vault-agent-.*-bootstrap$", name):
        print(name)
' "$compose_file")

    if [ -z "$all_agents" ]; then
        return 0
    fi

    local active_services
    active_services=$(get_profile_services_for_profile "$profile" | tr ' ' '\n')

    # Intersection: agents that exist in both compose and the active profile.
    comm -12 <(printf '%s\n' "$all_agents" | sort) <(printf '%s\n' "$active_services" | sort)
}

# Profile service mappings (Docker-managed services only)
# Each profile includes runtime core services plus profile-specific services.
# NOTE: This is now a function to ensure INFERENCE_ENGINE is read after .env loading
# Vault and bootstrap services are ONLY included in bld and sys profiles.
get_profile_services_for_profile() {
    local profile="$1"
    # Ensure INFERENCE_ENGINE has a default value before sourcing the env file
    INFERENCE_ENGINE="${INFERENCE_ENGINE:-ollama}"

    local env_services
    env_services="$(_load_profile_services "$profile")"
    if [ -n "$env_services" ]; then
        echo "$env_services"
        return 0
    fi

    # Fallback: hard-coded lists if env file is missing or PROFILE_SERVICES is empty.
    local engine="${INFERENCE_ENGINE:-ollama}"
    case "$profile" in
        bld)
            echo "$engine vault postgres prometheus alertmanager grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter blackbox-exporter json-exporter vault-agent-postgres vault-agent-postgres-bootstrap"
            ;;
        sys)
            echo "$engine vault open-webui postgres pgadmin prometheus alertmanager grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter blackbox-exporter json-exporter vault-agent-postgres vault-agent-openwebui vault-agent-postgres-bootstrap vault-agent-openwebui-bootstrap vault-agent-pgadmin-bootstrap vault-agent-grafana-bootstrap"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

# Profile database storage settings
# All profiles use database storage for persistence
declare -A PROFILE_DB_STORAGE=(
    [bld]="true"
    [sys]="true"
)

# Check if a profile name is valid
is_valid_profile() {
    local profile="$1"
    if [ -z "$profile" ]; then
        return 1
    fi
    case "$profile" in
        bld|sys)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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
    echo "  - bld: $(get_profile_description "bld")"
    echo "  - sys: $(get_profile_description "sys")"
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
export -f get_profile_services_for_profile get_runtime_core_services _load_profile_services _get_vault_bootstrap_agents
