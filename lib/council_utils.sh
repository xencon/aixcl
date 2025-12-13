#!/usr/bin/env bash
# Council utility functions

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source dependencies
source "${BASH_SOURCE%/*}/common.sh"
source "${BASH_SOURCE%/*}/docker_utils.sh"
source "${BASH_SOURCE%/*}/color.sh"

# Get available models from Ollama
get_available_models() {
    # Find the actual Ollama container name (handle hash-prefixed containers)
    local ollama_container
    ollama_container=$(get_ollama_container)
    
    if [ -z "$ollama_container" ]; then
        print_error "Ollama container is not running. Please start the services first."
        return 1
    fi
    
    # Get models list, skip header line, extract model names
    docker exec "$ollama_container" ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -v "^$"
}

# Update .env file with council configuration
update_env_file() {
    local council_models="$1"
    local chairman_model="$2"
    local env_file="${SCRIPT_DIR}/.env"
    
    # Check if .env file exists
    if [[ ! -f "$env_file" ]]; then
        print_error ".env file not found. Please run 'aixcl stack start' first to create it."
        return 1
    fi
    
    # Create backup
    cp "$env_file" "${env_file}.backup.$(date +%s)"
    
    # Remove all existing COUNCIL_MODELS lines (including commented ones)
    # This ensures we completely overwrite any existing configuration
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS uses BSD sed
        sed -i '' '/^[[:space:]]*#.*COUNCIL_MODELS/d' "$env_file"
        sed -i '' '/^COUNCIL_MODELS=/d' "$env_file"
        # Remove all existing CHAIRMAN_MODEL lines
        sed -i '' '/^[[:space:]]*#.*CHAIRMAN_MODEL/d' "$env_file"
        sed -i '' '/^CHAIRMAN_MODEL=/d' "$env_file"
        # Add new values at the end
        echo "COUNCIL_MODELS=${council_models}" >> "$env_file"
        echo "CHAIRMAN_MODEL=${chairman_model}" >> "$env_file"
    else
        # Linux uses GNU sed
        sed -i '/^[[:space:]]*#.*COUNCIL_MODELS/d' "$env_file"
        sed -i '/^COUNCIL_MODELS=/d' "$env_file"
        # Remove all existing CHAIRMAN_MODEL lines
        sed -i '/^[[:space:]]*#.*CHAIRMAN_MODEL/d' "$env_file"
        sed -i '/^CHAIRMAN_MODEL=/d' "$env_file"
        # Add new values at the end
        echo "COUNCIL_MODELS=${council_models}" >> "$env_file"
        echo "CHAIRMAN_MODEL=${chairman_model}" >> "$env_file"
    fi
    
    print_success "Updated .env file with council configuration"
    return 0
}
