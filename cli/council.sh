#!/usr/bin/env bash
# Council management commands (configure, status)

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_utils.sh"
source "${SCRIPT_DIR}/lib/color.sh"
source "${SCRIPT_DIR}/lib/council_utils.sh"

# Council status command
council_status() {
    echo "📋 LLM Council Status"
    echo "===================="
    echo ""
    
    # Check if services are running
    local llm_council_running=false
    local ollama_running=false
    
    if is_container_running "llm-council"; then
        llm_council_running=true
    fi
    
    if is_container_running "ollama"; then
        ollama_running=true
    fi
    
    # Read configuration from .env file
    local council_models=""
    local chairman_model=""
    local backend_mode="ollama"
    local env_file="${SCRIPT_DIR}/.env"
    
    if [[ ! -f "$env_file" ]]; then
        print_error ".env file not found."
        echo "   Please run 'aixcl stack start' first to create it, then configure the council with 'aixcl council configure'"
        return 1
    fi
    
    # Read .env file - use legacy format (CHAIRMAN_MODEL and COUNCIL_MODELS)
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" ]] && continue
        [[ "${line#\#}" != "$line" ]] && continue
        
        if [[ "$line" =~ ^BACKEND_MODE[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            backend_mode="${BASH_REMATCH[1]}"
            backend_mode=$(echo "$backend_mode" | xargs | tr -d '"' | tr -d "'")
        elif [[ "$line" =~ ^COUNCIL_MODELS[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            council_models="${BASH_REMATCH[1]}"
            council_models=$(echo "$council_models" | xargs | tr -d '"' | tr -d "'")
        elif [[ "$line" =~ ^CHAIRMAN_MODEL[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            chairman_model="${BASH_REMATCH[1]}"
            chairman_model=$(echo "$chairman_model" | xargs | tr -d '"' | tr -d "'")
        fi
    done < "$env_file"
    
    echo "Configuration:"
    echo "  Backend Mode: ${backend_mode:-ollama}"
    echo ""
    echo "  Chairman: ${chairman_model:-<not set>}"
    echo "  Council Members: ${council_models:-<not set>}"
    echo ""
    
    # Check if council is configured
    if [[ -z "$council_models" ]] && [[ -z "$chairman_model" ]]; then
        print_warning "Council is not configured yet."
        echo ""
        echo "To configure the council, run:"
        echo "  aixcl council configure"
        return 0
    fi
    
    # Clean up values
    council_models=$(echo "$council_models" | xargs | tr -d '"' | tr -d "'")
    chairman_model=$(echo "$chairman_model" | xargs | tr -d '"' | tr -d "'")
    
    # Build list of all models (avoid duplicates)
    local all_models=()
    local seen_models=()
    
    # Add council members
    if [[ -n "$council_models" ]]; then
        IFS=',' read -ra MEMBERS <<< "$council_models"
        for member in "${MEMBERS[@]}"; do
            member=$(echo "$member" | xargs | tr -d '"' | tr -d "'")
            if [[ -n "$member" ]]; then
                local already_added=false
                for seen in "${seen_models[@]}"; do
                    if [[ "$seen" == "$member" ]]; then
                        already_added=true
                        break
                    fi
                done
                if [[ "$already_added" == "false" ]]; then
                    all_models+=("$member")
                    seen_models+=("$member")
                fi
            fi
        done
    fi
    
    # Add chairman if not already in the list
    if [[ -n "$chairman_model" ]]; then
        local already_added=false
        for seen in "${seen_models[@]}"; do
            if [[ "$seen" == "$chairman_model" ]]; then
                already_added=true
                break
            fi
        done
        if [[ "$already_added" == "false" ]]; then
            all_models+=("$chairman_model")
        fi
    fi
    
    if [[ ${#all_models[@]} -eq 0 ]]; then
        print_error "No models configured"
        return 1
    fi
    
    # Test operational status for each model
    echo "Operational Status:"
    echo "-------------------"
    echo ""
    
    local operational_count=0
    local total_count=${#all_models[@]}
    
    for model in "${all_models[@]}"; do
        local role="Council Member"
        if [[ "$model" == "$chairman_model" ]]; then
            role="Chairman"
        fi
        
        echo -n "  $model ($role): "
        
        # Test if model is operational
        local is_operational=false
        local status_msg=""
        
        if [[ "$backend_mode" == "ollama" ]] && [[ "$ollama_running" == "true" ]]; then
            # Test model by sending a simple query to Ollama
            local test_payload
            test_payload=$(python3 -c "
import json
import sys
model = sys.argv[1]
payload = {
    'model': model,
    'messages': [{'role': 'user', 'content': 'Say OK'}],
    'stream': False
}
print(json.dumps(payload))
" "$model" 2>/dev/null)
            
            if [[ -n "$test_payload" ]]; then
                local response
                local status_code
                response=$(curl -s -w "\n%{http_code}" -X POST http://localhost:11434/api/chat \
                    -H "Content-Type: application/json" \
                    -d "$test_payload" 2>/dev/null)
                
                status_code=$(echo "$response" | tail -n1)
                response_body=$(echo "$response" | sed '$d')
                
                if [[ "$status_code" == "200" ]] && echo "$response_body" | grep -q "message"; then
                    is_operational=true
                    operational_count=$((operational_count + 1))
                fi
            fi
        elif [[ "$backend_mode" != "ollama" ]]; then
            # For OpenRouter, assume operational (can't test without API key)
            is_operational=true
            operational_count=$((operational_count + 1))
            status_msg=" (OpenRouter - not tested)"
        fi
        
        if [[ "$is_operational" == "true" ]]; then
            print_success "Operational$status_msg"
        else
            if [[ "$ollama_running" == "false" ]]; then
                print_warning "Cannot test (Ollama not running)"
            else
                print_error "Not Operational"
            fi
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "  Total Models: $total_count"
    echo "  Operational: $operational_count"
    echo "  Not Operational: $((total_count - operational_count))"
    echo ""
    
    # Service status
    if [[ "$llm_council_running" == "true" ]]; then
        print_success "LLM-Council service is running"
    else
        print_warning "LLM-Council service is not running"
    fi
    
    if [[ "$ollama_running" == "true" ]]; then
        print_success "Ollama service is running"
    else
        print_warning "Ollama service is not running"
    fi
    echo ""
}

# Council configure command (interactive)
council_configure() {
    echo "🔧 Configuring LLM Council"
    echo "=========================="
    echo ""
    echo "Note: This will ignore any existing .env configuration and create a new one."
    echo ""
    
    # Check if Ollama is running
    if ! is_container_running "ollama"; then
        print_error "Ollama container is not running."
        echo "   Please start the services first with: aixcl stack start"
        return 1
    fi
    
    # Get available models
    echo "Fetching available models from Ollama..."
    local available_models
    available_models=$(get_available_models)
    
    if [[ -z "$available_models" ]]; then
        print_error "No models found in Ollama."
        echo "   Please add models first with: aixcl models add <model-name>"
        return 1
    fi
    
    # Convert to array for easier handling
    local models_array=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && models_array+=("$line")
    done <<< "$available_models"
    
    local model_count=${#models_array[@]}
    
    if [[ $model_count -lt 2 ]]; then
        print_error "At least 2 models are required for the council (1 chairman + 1 member)."
        echo "   You currently have $model_count model(s)."
        echo "   Please add more models first with: aixcl models add <model-name>"
        return 1
    fi
    
    # Display available models
    echo ""
    echo "Available models:"
    echo "-----------------"
    local index=1
    for model in "${models_array[@]}"; do
        echo "  [$index] $model"
        ((index++))
    done
    echo ""
    
    # Select chairman
    local chairman_index
    local chairman_model
    while true; do
        read -p "Select chairman model (1-$model_count): " chairman_index
        if [[ "$chairman_index" =~ ^[0-9]+$ ]] && [[ "$chairman_index" -ge 1 ]] && [[ "$chairman_index" -le $model_count ]]; then
            chairman_model="${models_array[$((chairman_index - 1))]}"
            print_success "Selected chairman: $chairman_model"
            break
        else
            print_error "Invalid selection. Please enter a number between 1 and $model_count."
        fi
    done
    
    # Select council members (up to 4 more, for a total of 5)
    local council_members=()
    local max_members=4
    local current_count=0
    local min_members_required=1
    
    echo ""
    echo "Select council members (at least 1 member required, up to $max_members more models):"
    echo "Note: Chairman is already included. Total council size will be 1 + number of members selected."
    echo ""
    
    set +e
    
    while true; do
        local remaining=$((max_members - current_count))
        local total_selected=$((${#council_members[@]} + 1))
        
        if [[ $total_selected -ge 5 ]]; then
            echo ""
            print_success "Maximum of 5 models reached (1 chairman + ${#council_members[@]} members)."
            break
        fi
        
        echo ""
        echo "Currently selected:"
        echo "  Chairman: $chairman_model"
        if [[ ${#council_members[@]} -gt 0 ]]; then
            echo "  Members:"
            for member in "${council_members[@]}"; do
                echo "    - $member"
            done
        else
            echo "  Members: (none yet - at least 1 required)"
        fi
        echo ""
        echo "Available models:"
        local available_count=0
        local index=1
        for model in "${models_array[@]}"; do
            local is_selected=0
            local marker=""
            if [[ "$model" == "$chairman_model" ]]; then
                marker=" (chairman)"
                is_selected=1
            fi
            for member in "${council_members[@]}"; do
                if [[ "$model" == "$member" ]]; then
                    marker=" (selected)"
                    is_selected=1
                    break
                fi
            done
            if [[ $is_selected -eq 0 ]]; then
                marker=""
                ((available_count++))
            fi
            echo "  [$index] $model$marker"
            ((index++))
        done
        
        if [[ $available_count -eq 0 ]]; then
            echo ""
            echo "  (no more models available)"
            break
        fi
        
        local prompt_msg="Select model (1-$model_count)"
        if [[ ${#council_members[@]} -ge $min_members_required ]]; then
            prompt_msg="$prompt_msg, or 'done' to finish"
            if [[ $remaining -gt 0 ]]; then
                prompt_msg="$prompt_msg [$remaining remaining]"
            fi
        else
            local needed=$((min_members_required - ${#council_members[@]}))
            prompt_msg="$prompt_msg (at least $needed more required)"
        fi
        prompt_msg="$prompt_msg: "
        
        echo ""
        read -p "$prompt_msg" selection
        
        if [[ "$selection" == "done" ]] || [[ "$selection" == "d" ]]; then
            if [[ ${#council_members[@]} -lt $min_members_required ]]; then
                local needed=$((min_members_required - ${#council_members[@]}))
                print_error "At least $needed more member(s) required. Please select more models."
                continue
            else
                print_success "Finished selecting council members."
                break
            fi
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le $model_count ]]; then
            local selected_model="${models_array[$((selection - 1))]}"
            
            local already_selected=0
            if [[ "$selected_model" == "$chairman_model" ]]; then
                already_selected=1
            fi
            for member in "${council_members[@]}"; do
                if [[ "$selected_model" == "$member" ]]; then
                    already_selected=1
                    break
                fi
            done
            
            if [[ $already_selected -eq 1 ]]; then
                print_error "Model '$selected_model' is already selected. Please choose a different model."
            else
                council_members+=("$selected_model")
                print_success "Added '$selected_model' to council members"
                ((current_count++))
            fi
        else
            print_error "Invalid selection. Please enter a number between 1 and $model_count"
            if [[ ${#council_members[@]} -ge $min_members_required ]]; then
                echo "   or type 'done' to finish."
            fi
        fi
    done
    
    set -e
    
    local total_models=$((${#council_members[@]} + 1))
    if [[ $total_models -lt 2 ]]; then
        echo ""
        print_error "Council must have at least 2 models (1 chairman + 1 member)."
        echo "   You selected only the chairman."
        exit 1
    fi
    
    # Build council models string
    local council_models_str=""
    for member in "${council_members[@]}"; do
        if [[ -z "$council_models_str" ]]; then
            council_models_str="$member"
        else
            council_models_str="$council_models_str,$member"
        fi
    done
    
    # Show summary
    echo ""
    echo "=========================="
    echo "Council Configuration Summary"
    echo "=========================="
    echo "Chairman: $chairman_model"
    echo "Council Members (${#council_members[@]}):"
    for member in "${council_members[@]}"; do
        echo "  - $member"
    done
    echo "Total models: $total_models"
    echo ""
    echo "This will update .env file with:"
    echo "  - CHAIRMAN_MODEL: $chairman_model"
    echo "  - COUNCIL_MODELS: $council_models_str"
    echo ""
    print_warning "Note: Any existing council configuration in .env will be replaced."
    echo ""
    
    read -p "Apply this configuration? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]] && [[ "$confirm" != "y" ]]; then
        echo "Configuration cancelled."
        exit 0
    fi
    
    if ! update_env_file "$council_models_str" "$chairman_model"; then
        exit 1
    fi
    
    echo ""
    print_success "Council configuration updated successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart the LLM-Council service to apply changes:"
    echo "     aixcl stack restart"
    echo "  2. The configuration will be loaded automatically"
    echo ""
    
    read -p "Restart LLM-Council service now? (yes/no): " restart_confirm
    if [[ "$restart_confirm" == "yes" ]] || [[ "$restart_confirm" == "y" ]]; then
        echo ""
        echo "Restarting LLM-Council service to apply new configuration..."
        set_compose_cmd
        # Stop if running
        if is_container_running "llm-council"; then
            "${COMPOSE_CMD[@]}" stop llm-council 2>/dev/null || true
        fi
        # Always remove the container to avoid docker-compose ContainerConfig KeyError
        # when using images from registry (older docker-compose versions have this bug)
        # This also handles the case where container exists but is stopped
        "${COMPOSE_CMD[@]}" rm -f llm-council 2>/dev/null || docker rm -f llm-council 2>/dev/null || true
        "${COMPOSE_CMD[@]}" build llm-council
        "${COMPOSE_CMD[@]}" up -d llm-council
        print_success "LLM-Council service restarted with new configuration"
    fi
    exit 0
}
