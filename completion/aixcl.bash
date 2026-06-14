#!/usr/bin/env bash
#
# Bash completion script for aixcl
# 
# This script provides command completion for the aixcl command-line tool.
# It offers suggestions for commands and model names when using the add/remove commands.
#
# Governance Model:
# - Runtime Core (Strict): Always enabled, never optional (ollama)
# - Operational Services (Guided): Profile-dependent, support/observe runtime
# - See docs/architecture/governance/ for full architectural documentation
#
# To use this script:
# 1. Source it directly: source /path/to/completion/aixcl.bash
# 2. Or install it system-wide: sudo cp completion/aixcl.bash /etc/bash_completion.d/aixcl
# 3. Or run: ./aixcl bash-completion
#

# Function to get available models from Ollama
_get_ollama_models() {
    # Check if Ollama container is running
    if docker ps --format "{{.Names}}" | grep -q "ollama" 2>/dev/null; then
        # Get list of models from Ollama
        local models
        models=$(docker exec ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}')
        echo "$models"
    fi
}

_aixcl_complete() {
    local cur prev words cword
    COMPREPLY=()
    
    # Disable default filename completion to prevent showing files/directories like "tests"
    compopt -o default 2>/dev/null || true
    
    # Get current word and previous word
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
    
    # List of all possible commands (must stay in sync with lib/aixcl/dispatcher.sh)
    local commands="app stack service models engine utils vault help restart"

    # Application names: built-in (apps/*/app.yaml) plus externally registered apps
    _aixcl_app_names() {
        local names=""
        local d
        for d in apps/*/; do
            [ -f "${d}app.yaml" ] && names+=" $(basename "$d")"
        done
        local reg="${HOME}/.config/aixcl/registry"
        if [ -f "$reg" ]; then
            local line
            while IFS='=' read -r line _; do
                [[ "$line" == \#* ]] || [ -z "$line" ] && continue
                names+=" $line"
            done < "$reg"
        fi
        echo "$names"
    }
    
    # Service categorization per AIXCL governance model (docs/architecture/governance/00_invariants.md)
    # Runtime Core (Strict): Always enabled, required for AIXCL to function
    # Note: OpenCode is a VS Code plugin, not a containerized service
    local runtime_core_services="ollama vllm llamacpp"
    
    # Operational Services (Guided): Profile-dependent, support/observe runtime
    # - Persistence: postgres, pgadmin
    # - Observability: prometheus, grafana, loki, cadvisor, node-exporter, postgres-exporter, nvidia-gpu-exporter
    # - UI: open-webui
    local operational_services="open-webui postgres pgadmin prometheus grafana cadvisor node-exporter postgres-exporter nvidia-gpu-exporter loki"
    
    # Combined list of all services (for backward compatibility and general completion)
    # Includes 'engine' alias for convenience
    local services="$runtime_core_services $operational_services engine"
    
    # Valid profiles (must match VALID_PROFILES in lib/cli/profile.sh)
    local profiles="bld sys"
    
    # If we're completing the first argument (right after the command)
    if (( cword == 1 )); then
        mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
        return 0
    fi
    
    # Handle subcommands
    case "$prev" in
        'stack')
            local stack_actions="start stop restart status logs init"
            mapfile -t COMPREPLY < <(compgen -W "$stack_actions" -- "$cur")
            return 0
            ;;
        'logs')
            # Complete with all services (runtime core + operational)
            mapfile -t COMPREPLY < <(compgen -W "$services" -- "$cur")
            return 0
            ;;
        'service')
            local service_actions="start stop restart"
            mapfile -t COMPREPLY < <(compgen -W "$service_actions" -- "$cur")
            return 0
            ;;
        'start')
            # If previous word was 'service', complete with service names
            # Note: Runtime core services should always be running
            # Operational services are profile-dependent
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "service" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "$services" -- "$cur")
                return 0
            fi
            # If previous word was 'stack', complete with profile options (optional)
            # Profile can come from .env file, but --profile/-p is still available
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "stack" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "--profile -p" -- "$cur")
                return 0
            fi
            # If previous word was 'app', complete with app names
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                local app_names
                app_names="$(_aixcl_app_names)"
                if [ -n "$app_names" ]; then
                    mapfile -t COMPREPLY < <(compgen -W "$app_names" -- "$cur")
                fi
                return 0
            fi
            ;;
        'restart')
            # If previous word was 'service', complete with service names
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "service" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "$services" -- "$cur")
                return 0
            fi
            # If previous word was 'stack', complete with profile options (optional)
            # Profile can come from .env file, but --profile/-p is still available
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "stack" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "--profile -p" -- "$cur")
                return 0
            fi
            # If previous word was 'app', complete with app names
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                local app_names
                app_names="$(_aixcl_app_names)"
                if [ -n "$app_names" ]; then
                    mapfile -t COMPREPLY < <(compgen -W "$app_names" -- "$cur")
                fi
                return 0
            fi
            ;;
        'stop')
            # If previous word was 'service', complete with service names
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "service" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "$services" -- "$cur")
                return 0
            fi
            # If previous word was 'app', complete with app names
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                local app_names
                app_names="$(_aixcl_app_names)"
                if [ -n "$app_names" ]; then
                    mapfile -t COMPREPLY < <(compgen -W "$app_names" -- "$cur")
                fi
                return 0
            fi
            ;;
        '--profile'|'-p')
            # Complete with valid profiles when --profile or -p is used
            mapfile -t COMPREPLY < <(compgen -W "$profiles" -- "$cur")
            return 0
            ;;

        'models')
            local model_actions="add remove list"
            mapfile -t COMPREPLY < <(compgen -W "$model_actions" -- "$cur")
            return 0
            ;;
        'engine')
            local engine_actions="set auto"
            mapfile -t COMPREPLY < <(compgen -W "$engine_actions" -- "$cur")
            return 0
            ;;
        'set')
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "engine" ]]; then
                local engines="ollama vllm llamacpp"
                mapfile -t COMPREPLY < <(compgen -W "$engines" -- "$cur")
                return 0
            fi
            ;;
        'config')
            # Deprecated command - show helpful message
            COMPREPLY=()
            return 0
            ;;
        'utils')
            local utils_actions="check-env bash-completion prune"
            mapfile -t COMPREPLY < <(compgen -W "$utils_actions" -- "$cur")
            return 0
            ;;
        'prune')
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "utils" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "--all" -- "$cur")
                return 0
            fi
            ;;
        'vault')
            local vault_actions="start stop restart init unseal status credentials passwords rotate logs"
            mapfile -t COMPREPLY < <(compgen -W "$vault_actions" -- "$cur")
            return 0
            ;;
        'app')
            local app_actions="list register unregister start stop restart status build remove scaffold install help"
            mapfile -t COMPREPLY < <(compgen -W "$app_actions" -- "$cur")
            return 0
            ;;
        'status')
            # If previous word was 'app', complete with available app names
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                local app_names=""
                for app_dir in apps/*/; do
                    if [ -f "${app_dir}/app.yaml" ]; then
                        app_names+=" $(basename "$app_dir")"
                    fi
                done
                if [ -n "$app_names" ]; then
                    mapfile -t COMPREPLY < <(compgen -W "$app_names" -- "$cur")
                fi
                return 0
            fi
            ;;
        'build')
            # If previous word was 'app', complete with available app names
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                local app_names=""
                for app_dir in apps/*/; do
                    if [ -f "${app_dir}/app.yaml" ]; then
                        app_names+=" $(basename "$app_dir")"
                    fi
                done
                if [ -n "$app_names" ]; then
                    mapfile -t COMPREPLY < <(compgen -W "$app_names" -- "$cur")
                fi
                return 0
            fi
            ;;
        'register')
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                # Complete with directories for the local path argument
                compopt -o dirnames 2>/dev/null
                mapfile -t COMPREPLY < <(compgen -d -- "$cur")
                return 0
            fi
            ;;
        'unregister')
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                local app_names
                app_names="$(_aixcl_app_names)"
                if [ -n "$app_names" ]; then
                    mapfile -t COMPREPLY < <(compgen -W "$app_names" -- "$cur")
                fi
                return 0
            fi
            ;;
        'install'|'scaffold')
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                # No completions: user must type the URL or name
                COMPREPLY=()
                return 0
            fi
            ;;
        'help')
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "app" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "list register unregister start stop restart status build remove scaffold install" -- "$cur")
                return 0
            fi
            ;;

        'add'|'remove')
            # If previous word was 'models', complete with available models
            if (( cword >= 2 )) && [[ "${words[cword-2]}" == "models" ]]; then
                local available_models
                available_models=$(_get_ollama_models)
                if [ -n "$available_models" ]; then
                    mapfile -t COMPREPLY < <(compgen -W "$available_models" -- "$cur")
                fi
                return 0
            fi
            ;;
    esac
    
    # If we reach here and COMPREPLY is empty, explicitly prevent filename completion
    if [ ${#COMPREPLY[@]} -eq 0 ]; then
        COMPREPLY=()
        return 0
    fi
    
    return 0
}

# Register the completion function for both PATH and relative invocation
complete -F _aixcl_complete aixcl
complete -F _aixcl_complete ./aixcl
