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
    
    # Remove all existing LLM Council configuration (old and new format)
    # This ensures we completely overwrite any existing configuration
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS uses BSD sed
        # Remove old format
        sed -i '' '/^[[:space:]]*#.*COUNCIL_MODELS/d' "$env_file"
        sed -i '' '/^COUNCIL_MODELS=/d' "$env_file"
        sed -i '' '/^[[:space:]]*#.*CHAIRMAN_MODEL/d' "$env_file"
        sed -i '' '/^CHAIRMAN_MODEL=/d' "$env_file"
        # Remove new format
        sed -i '' '/^[[:space:]]*#.*CHAIRMAN=/d' "$env_file"
        sed -i '' '/^CHAIRMAN=/d' "$env_file"
        sed -i '' '/^[[:space:]]*#.*COUNCILLOR-/d' "$env_file"
        sed -i '' '/^COUNCILLOR-/d' "$env_file"
    else
        # Linux uses GNU sed
        # Remove old format
        sed -i '/^[[:space:]]*#.*COUNCIL_MODELS/d' "$env_file"
        sed -i '/^COUNCIL_MODELS=/d' "$env_file"
        sed -i '/^[[:space:]]*#.*CHAIRMAN_MODEL/d' "$env_file"
        sed -i '/^CHAIRMAN_MODEL=/d' "$env_file"
        # Remove new format
        sed -i '/^[[:space:]]*#.*CHAIRMAN=/d' "$env_file"
        sed -i '/^CHAIRMAN=/d' "$env_file"
        sed -i '/^[[:space:]]*#.*COUNCILLOR-/d' "$env_file"
        sed -i '/^COUNCILLOR-/d' "$env_file"
    fi
    
    # Add new format: CHAIRMAN and COUNCILLOR-XX
    echo "" >> "$env_file"
    echo "# LLM Council Configuration" >> "$env_file"
    echo "# Chairman model - synthesizes final response" >> "$env_file"
    echo "CHAIRMAN=${chairman_model}" >> "$env_file"
    echo "" >> "$env_file"
    echo "# Council Members - Individual models that participate in the council" >> "$env_file"
    echo "# Up to 4 councillors supported (total of 5 models: 1 chairman + 4 councillors)" >> "$env_file"
    
    # Split council_models by comma and write individual COUNCILLOR-XX variables
    if [[ -n "$council_models" ]]; then
        IFS=',' read -ra MODELS <<< "$council_models"
        local index=1
        for model in "${MODELS[@]}"; do
            model=$(echo "$model" | xargs)  # Trim whitespace
            if [[ -n "$model" ]] && [[ $index -le 4 ]]; then
                echo "COUNCILLOR-$(printf "%02d" $index)=${model}" >> "$env_file"
                ((index++))
            fi
        done
        # Add empty slots for remaining councillors
        while [[ $index -le 4 ]]; do
            echo "COUNCILLOR-$(printf "%02d" $index)=" >> "$env_file"
            ((index++))
        done
    else
        # No councillors, add empty slots
        for i in {1..4}; do
            echo "COUNCILLOR-$(printf "%02d" $i)=" >> "$env_file"
        done
    fi
    
    print_success "Updated .env file with council configuration (new format: CHAIRMAN and COUNCILLOR-XX)"
    return 0
}
