#!/usr/bin/env bash
#
# Bash completion script for aixcl
# 
# This script provides command completion for the aixcl command-line tool.
# It offers suggestions for commands and model names when using the add/remove commands.
#
# Compatibility: macOS, WSL, Linux, and other Unix systems
# Requires: bash 3.2+ (macOS default), docker
#
# Governance Model:
# - Runtime Core (Strict): Always enabled, never optional (ollama, llm-council)
# - Operational Services (Guided): Profile-dependent, support/observe runtime
# - See docs/architecture/governance/ for full architectural documentation
#
# To use this script:
# 1. Source it directly: source /path/to/completion/aixcl.bash
# 2. Or install it system-wide: 
#    - Linux/WSL: sudo cp completion/aixcl.bash /etc/bash_completion.d/aixcl
#    - macOS: cp completion/aixcl.bash /usr/local/etc/bash_completion.d/aixcl
# 3. Or run: ./aixcl utils bash-completion
#

# Function to get available models from Ollama
# Compatible with macOS, WSL, and Linux Docker implementations
_get_ollama_models() {
    # Check if docker command is available
    if ! command -v docker >/dev/null 2>&1; then
        return 0
    fi
    
    # Check if Ollama container is running
    # Use portable grep syntax that works on macOS, WSL, and Linux
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -qE "^ollama$|_ollama$|ollama_" 2>/dev/null; then
        # Get list of models from Ollama
        # Handle both docker exec formats (works on all platforms)
        local models=$(docker exec ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}' 2>/dev/null)
        if [ -n "$models" ]; then
            echo "$models"
        fi
    fi
}

_aixcl_complete() {
    local cur prev words cword
    COMPREPLY=()
    
    # Disable default filename completion to prevent showing files/directories like "tests"
    # compopt is bash 4.0+, so handle gracefully for macOS bash 3.2 compatibility
    if type compopt >/dev/null 2>&1; then
        compopt -o default 2>/dev/null || true
    fi
    
    # Get current word and previous word
    # Use safe array access compatible with bash 3.2+ (macOS default)
    if [ ${COMP_CWORD} -ge 0 ] && [ ${COMP_CWORD} -lt ${#COMP_WORDS[@]} ]; then
        cur="${COMP_WORDS[COMP_CWORD]}"
    else
        cur=""
    fi
    
    if [ ${COMP_CWORD} -ge 1 ] && [ $((COMP_CWORD - 1)) -lt ${#COMP_WORDS[@]} ]; then
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    else
        prev=""
    fi
    
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
    
    # List of all possible commands
    local commands="stack service models dashboard utils council help bash-completion check-env"
    
    # Service categorization per AIXCL governance model (docs/architecture/governance/00_invariants.md)
    # Runtime Core (Strict): Always enabled, required for AIXCL to function
    # Note: Continue is a VS Code plugin, not a containerized service
    local runtime_core_services="ollama llm-council"
    
    # Operational Services (Guided): Profile-dependent, support/observe runtime
    # - Persistence: postgres, pgadmin
    # - Observability: prometheus, grafana, loki, promtail, cadvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter
    # - UI: open-webui
    # - Automation: watchtower
    local operational_services="open-webui postgres pgadmin watchtower prometheus grafana cadvisor node-exporter postgres-exporter nvidia-gpu-exporter loki promtail"
    
    # Combined list of all services (for backward compatibility and general completion)
    # Must match ALL_SERVICES in lib/common.sh
    local services="$runtime_core_services $operational_services"
    
    # Valid profiles (must match VALID_PROFILES in cli/lib/profile.sh)
    local profiles="usr dev ops sys"
    
    # If we're completing the first argument (right after the command)
    # Use arithmetic comparison compatible with bash 3.2+ (macOS default)
    if [ "$cword" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi
    
    # Handle subcommands
    case "$prev" in
        'stack')
            local stack_actions="start stop restart status logs clean"
            COMPREPLY=( $(compgen -W "$stack_actions" -- "$cur") )
            return 0
            ;;
        'logs')
            # Complete with all services (runtime core + operational)
            COMPREPLY=( $(compgen -W "$services" -- "$cur") )
            return 0
            ;;
        'service')
            local service_actions="start stop restart"
            COMPREPLY=( $(compgen -W "$service_actions" -- "$cur") )
            return 0
            ;;
        'start')
            # If previous word was 'service', complete with service names
            # Note: Runtime core services (ollama, llm-council) should always be running
            # Operational services are profile-dependent
            # Use arithmetic comparison compatible with bash 3.2+ (macOS default)
            if [ "$cword" -ge 2 ]; then
                local prev_idx=$((cword - 2))
                if [ "$prev_idx" -ge 0 ] && [ "$prev_idx" -lt ${#words[@]} ] && [ "${words[$prev_idx]}" = "service" ]; then
                    COMPREPLY=( $(compgen -W "$services" -- "$cur") )
                    return 0
                fi
                # If previous word was 'stack', complete with profile options (optional)
                # Profile can come from .env file, but --profile/-p is still available
                if [ "$prev_idx" -ge 0 ] && [ "$prev_idx" -lt ${#words[@]} ] && [ "${words[$prev_idx]}" = "stack" ]; then
                    COMPREPLY=( $(compgen -W "--profile -p" -- "$cur") )
                    return 0
                fi
            fi
            ;;
        'restart')
            # If previous word was 'service', complete with service names
            if [ "$cword" -ge 2 ]; then
                local prev_idx=$((cword - 2))
                if [ "$prev_idx" -ge 0 ] && [ "$prev_idx" -lt ${#words[@]} ] && [ "${words[$prev_idx]}" = "service" ]; then
                    COMPREPLY=( $(compgen -W "$services" -- "$cur") )
                    return 0
                fi
                # If previous word was 'stack', complete with profile options (optional)
                # Profile can come from .env file, but --profile/-p is still available
                if [ "$prev_idx" -ge 0 ] && [ "$prev_idx" -lt ${#words[@]} ] && [ "${words[$prev_idx]}" = "stack" ]; then
                    COMPREPLY=( $(compgen -W "--profile -p" -- "$cur") )
                    return 0
                fi
            fi
            ;;
        'stop')
            # If previous word was 'service', complete with service names
            if [ "$cword" -ge 2 ]; then
                local prev_idx=$((cword - 2))
                if [ "$prev_idx" -ge 0 ] && [ "$prev_idx" -lt ${#words[@]} ] && [ "${words[$prev_idx]}" = "service" ]; then
                    COMPREPLY=( $(compgen -W "$services" -- "$cur") )
                    return 0
                fi
            fi
            ;;
        '--profile'|'-p')
            # Complete with valid profiles when --profile or -p is used
            COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
            return 0
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
            local council_actions="configure status"
            COMPREPLY=( $(compgen -W "$council_actions" -- "$cur") )
            return 0
            ;;
        'add'|'remove')
            # If previous word was 'models', complete with available models
            # Use arithmetic comparison compatible with bash 3.2+ (macOS default)
            if [ "$cword" -ge 2 ]; then
                local prev_idx=$((cword - 2))
                if [ "$prev_idx" -ge 0 ] && [ "$prev_idx" -lt ${#words[@]} ] && [ "${words[$prev_idx]}" = "models" ]; then
                    local available_models=$(_get_ollama_models)
                    if [ -n "$available_models" ]; then
                        COMPREPLY=( $(compgen -W "$available_models" -- "$cur") )
                    fi
                    return 0
                fi
            fi
            ;;
    esac
    
    # If we reach here and COMPREPLY is empty, explicitly prevent filename completion
    # Use portable array length check compatible with bash 3.2+ (macOS default)
    if [ ${#COMPREPLY[@]} -eq 0 ]; then
        COMPREPLY=()
        return 0
    fi
    
    return 0
}

# Register the completion function
# This will work for: aixcl, ./aixcl, /path/to/aixcl, etc.
# Compatible with macOS, WSL, and Linux bash completion systems
# -o default is not set, so filename completion won't be used as fallback
complete -F _aixcl_complete aixcl 2>/dev/null || true
