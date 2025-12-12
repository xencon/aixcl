#!/usr/bin/env bash
#
# Bash completion script for aixcl
# 
# This script provides command completion for the aixcl command-line tool.
# It offers suggestions for commands and model names when using the add/remove commands.
#
# To use this script:
# 1. Source it directly: source /path/to/completion/aixcl.bash
# 2. Or install it system-wide: sudo cp completion/aixcl.bash /etc/bash_completion.d/aixcl
# 3. Or run: ./aixcl.sh utils bash-completion
#

# Function to get available models from Ollama
_get_ollama_models() {
    # Check if Ollama container is running
    if docker ps --format "{{.Names}}" | grep -q "ollama" 2>/dev/null; then
        # Get list of models from Ollama
        local models=$(docker exec ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}')
        echo "$models"
    fi
}

_aixcl_complete() {
    local cur prev words cword
    # Only initialize completion if we're actually in a completion context
    # and _init_completion is available
    if declare -f _init_completion >/dev/null 2>&1; then
        # Suppress errors from _init_completion to prevent stack corruption errors
        # when the script is interrupted (e.g., with Ctrl+C)
        _init_completion 2>/dev/null || {
            # If initialization fails, set variables manually
            # This handles cases where the completion stack might be corrupted
            words=("${COMP_WORDS[@]}")
            cword=${COMP_CWORD:-0}
            cur="${COMP_WORDS[COMP_CWORD]:-}"
            prev="${COMP_WORDS[COMP_CWORD-1]:-}"
        }
    else
        # Fallback if _init_completion is not available
        words=("${COMP_WORDS[@]}")
        cword=${COMP_CWORD:-0}
        cur="${COMP_WORDS[COMP_CWORD]:-}"
        prev="${COMP_WORDS[COMP_CWORD-1]:-}"
    fi

    # List of all possible commands (new nested structure)
    local commands="stack service models dashboard utils council help"

    # List of all services (must match ALL_SERVICES in lib/common.sh)
    local services="ollama open-webui postgres pgadmin watchtower llm-council prometheus grafana cadvisor node-exporter postgres-exporter nvidia-gpu-exporter loki promtail"

    # Handle the case where the command might be './aixcl.sh' or just 'aixcl'
    # Get the actual command name (last word before current)
    local cmd_name="${words[0]}"
    # Extract just the filename if it's a path
    if [[ "$cmd_name" == *"/"* ]]; then
        cmd_name=$(basename "$cmd_name")
    fi
    
    case "$prev" in
        'aixcl.sh'|'./aixcl.sh'|'aixcl')
            # Complete with available commands
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
            return 0
            ;;
        'stack')
            # Complete with stack subcommands
            local stack_actions="start stop restart status logs clean"
            COMPREPLY=( $(compgen -W "$stack_actions" -- "$cur") )
            return 0
            ;;
        'logs')
            # Complete with available services
            COMPREPLY=( $(compgen -W "$services" -- "$cur") )
            return 0
            ;;
        'service')
            # Complete with service actions
            local service_actions="start stop restart"
            COMPREPLY=( $(compgen -W "$service_actions" -- "$cur") )
            return 0
            ;;
        'start'|'stop'|'restart')
            # If previous word was 'service', complete with service names
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "service" ]]; then
                COMPREPLY=( $(compgen -W "$services" -- "$cur") )
                return 0
            fi
            ;;
        'dashboard')
            local dashboards="openwebui grafana pgadmin"
            COMPREPLY=( $(compgen -W "$dashboards" -- "$cur") )
            return 0
            ;;
        'models')
            local model_actions="add remove list"
            COMPREPLY=( $(compgen -W "$model_actions" -- "$cur") )
            return 0
            ;;
        'utils')
            local utils_actions="check-env bash-completion"
            COMPREPLY=( $(compgen -W "$utils_actions" -- "$cur") )
            return 0
            ;;
        'council')
            local council_actions="configure status list"
            COMPREPLY=( $(compgen -W "$council_actions" -- "$cur") )
            return 0
            ;;
        'add'|'remove')
            # If previous word was 'models', complete with available models
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "models" ]]; then
                local available_models=$(_get_ollama_models)
                if [ -n "$available_models" ]; then
                    COMPREPLY=( $(compgen -W "$available_models" -- "$cur") )
                fi
                return 0
            fi
            ;;
        'list'|'status')
            # These commands don't take arguments
            COMPREPLY=()
            return 0
            ;;
    esac
    
    # Default: no completion
    COMPREPLY=()
    return 0
}

# Register the completion function
complete -F _aixcl_complete aixcl.sh aixcl
