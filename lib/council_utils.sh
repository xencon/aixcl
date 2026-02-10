#!/usr/bin/env bash
# Council utility functions

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source dependencies
source "${BASH_SOURCE%/*}/common.sh"
source "${BASH_SOURCE%/*}/docker_utils.sh"
source "${BASH_SOURCE%/*}/color.sh"

# Get available models from Ollama (table parsing from ollama list)
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

# Get complete list of Ollama model names via API (reliable); fall back to get_available_models if API fails.
# Use this when a complete list is required (e.g. Continue CLI config). Output: one model name per line.
get_ollama_models_complete() {
    local json
    json=$(curl -s --max-time 3 "http://localhost:11434/api/tags" 2>/dev/null) || true
    if [[ -n "$json" ]] && echo "$json" | grep -q '"models"'; then
        # Parse "name":"model:tag" from JSON (no jq required)
        local parsed
        parsed=$(echo "$json" | grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/"name"[[:space:]]*:[[:space:]]*"([^"]+)"/\1/' | grep -v "^$")
        if [[ -n "$parsed" ]]; then
            echo "$parsed"
            return
        fi
    fi
    # Fall back to ollama list parsing (requires container)
    get_available_models 2>/dev/null || true
}

# Update .env file with council configuration
update_env_file() {
    local council_models="$1"
    local chairman_model="$2"
    local env_file="${SCRIPT_DIR}/.env"
    
    # Validate inputs
    if [[ -z "$chairman_model" ]]; then
        print_error "Chairman model is required"
        return 1
    fi
    
    if [[ -z "$council_models" ]]; then
        print_error "At least one council member is required"
        return 1
    fi
    
    # Check if .env file exists
    if [[ ! -f "$env_file" ]]; then
        print_error ".env file not found at: $env_file"
        print_error "Please run 'aixcl stack start' first to create it."
        return 1
    fi
    
    # Create backup
    cp "$env_file" "${env_file}.backup.$(date +%s)" || {
        print_error "Failed to create backup of .env file"
        return 1
    }
    
    # Remove all existing Council configuration
    # This ensures we completely overwrite any existing configuration
    # Remove entire section including all comment lines and variables
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS uses BSD sed
        # Remove section header and all related comments
        sed -i '' '/^[[:space:]]*#.*Council Configuration/d' "$env_file"
        sed -i '' '/^[[:space:]]*#.*Chairman/d' "$env_file"
        sed -i '' '/^[[:space:]]*#.*Council Members/d' "$env_file"
        sed -i '' '/^[[:space:]]*#.*COUNCIL_MODELS/d' "$env_file"
        sed -i '' '/^[[:space:]]*#.*CHAIRMAN_MODEL/d' "$env_file"
        sed -i '' '/^[[:space:]]*#.*CHAIRMAN=/d' "$env_file"
        sed -i '' '/^[[:space:]]*#.*COUNCILLOR-/d' "$env_file"
        # Remove variable assignments
        sed -i '' '/^[[:space:]]*COUNCIL_MODELS=/d' "$env_file"
        sed -i '' '/^[[:space:]]*CHAIRMAN_MODEL=/d' "$env_file"
        sed -i '' '/^[[:space:]]*CHAIRMAN=/d' "$env_file"
        sed -i '' '/^[[:space:]]*COUNCILLOR-/d' "$env_file"
        # Remove "Configure with" comment lines
        sed -i '' '/^[[:space:]]*#.*Configure with.*council configure/d' "$env_file"
    else
        # Linux uses GNU sed
        # Remove section header and all related comments
        sed -i '/^[[:space:]]*#.*Council Configuration/d' "$env_file"
        sed -i '/^[[:space:]]*#.*Chairman/d' "$env_file"
        sed -i '/^[[:space:]]*#.*Council Members/d' "$env_file"
        sed -i '/^[[:space:]]*#.*COUNCIL_MODELS/d' "$env_file"
        sed -i '/^[[:space:]]*#.*CHAIRMAN_MODEL/d' "$env_file"
        sed -i '/^[[:space:]]*#.*CHAIRMAN=/d' "$env_file"
        sed -i '/^[[:space:]]*#.*COUNCILLOR-/d' "$env_file"
        # Remove variable assignments
        sed -i '/^[[:space:]]*COUNCIL_MODELS=/d' "$env_file"
        sed -i '/^[[:space:]]*CHAIRMAN_MODEL=/d' "$env_file"
        sed -i '/^[[:space:]]*CHAIRMAN=/d' "$env_file"
        sed -i '/^[[:space:]]*COUNCILLOR-/d' "$env_file"
        # Remove "Configure with" comment lines
        sed -i '/^[[:space:]]*#.*Configure with.*council configure/d' "$env_file"
    fi
    
    # Remove consecutive blank lines (more than 2 in a row) to clean up the file
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: Use awk to remove excessive blank lines
        awk 'BEGIN{blank=0} /^[[:space:]]*$/{blank++; if(blank<=1) print; next} {blank=0; print}' "$env_file" > "${env_file}.tmp" && mv "${env_file}.tmp" "$env_file"
    else
        # Linux: Use awk to remove excessive blank lines
        awk 'BEGIN{blank=0} /^[[:space:]]*$/{blank++; if(blank<=1) print; next} {blank=0; print}' "$env_file" > "${env_file}.tmp" && mv "${env_file}.tmp" "$env_file"
    fi
    
    # Ensure file ends with newline before appending
    if [[ -s "$env_file" ]] && [[ "$(tail -c 1 "$env_file" 2>/dev/null)" != "" ]]; then
        echo "" >> "$env_file" || {
            print_error "Failed to append newline to .env file"
            return 1
        }
    fi
    
    # Add legacy format: CHAIRMAN_MODEL and COUNCIL_MODELS (bash-compatible)
    {
        echo ""
        echo "# Council Configuration"
        echo "# Chairman model - synthesizes final response"
        echo "CHAIRMAN_MODEL=${chairman_model}"
        echo ""
        echo "# Council Members - Comma-separated list of models that participate in the council"
        echo "COUNCIL_MODELS=${council_models}"
    } >> "$env_file" || {
        print_error "Failed to write council configuration to .env file"
        return 1
    }
    
    # Verify the values were written correctly
    if ! grep -q "^CHAIRMAN_MODEL=${chairman_model}$" "$env_file" 2>/dev/null; then
        print_error "Failed to verify CHAIRMAN_MODEL was written correctly"
        return 1
    fi
    
    if ! grep -q "^COUNCIL_MODELS=${council_models}$" "$env_file" 2>/dev/null; then
        print_error "Failed to verify COUNCIL_MODELS was written correctly"
        return 1
    fi
    
    print_success "Updated .env file with council configuration (CHAIRMAN_MODEL and COUNCIL_MODELS)"
    return 0
}
