#!/usr/bin/env bash
#
# Bash completion script for aixcl
# 
# This script provides command completion for the aixcl command-line tool.
# It offers suggestions for commands and model names when using the add/remove commands.
#
# To use this script:
# 1. Source it directly: source /path/to/aixcl_completion.sh
# 2. Or install it system-wide: sudo cp aixcl_completion.sh /etc/bash_completion.d/aixcl
# 3. Or run: ./aixcl install-completion
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

_aixcl_completion() {
    local commands="start stop restart logs clean stats status add remove list help install-completion"
    COMPREPLY=()
    
    # Get the current word being completed
    local cur="${COMP_WORDS[COMP_CWORD]}"
    
    # Complete the first argument with available commands
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
        return 0
    fi
    
    # Get the previous word for context
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Handle subcommands for specific commands
    case "${prev}" in
        add)
            # For add, suggest only the specified models
            local available_models="nomic-embed-text:latest starcoder2:latest deepseek-coder:latest"
            COMPREPLY=($(compgen -W "${available_models}" -- "${cur}"))
            return 0
            ;;
        remove)
            # For remove, suggest installed models
            local installed_models=$(_get_ollama_models)
            if [[ -n "$installed_models" ]]; then
                COMPREPLY=($(compgen -W "${installed_models}" -- "${cur}"))
            fi
            return 0
            ;;
        *)
            # Check if we're in a multi-model add or remove command
            if [[ ${COMP_CWORD} -gt 2 ]]; then
                local cmd="${COMP_WORDS[1]}"
                if [[ "$cmd" == "add" ]]; then
                    # For add, suggest only the specified models
                    local available_models="nomic-embed-text:latest starcoder2:latest deepseek-coder:latest"
                    COMPREPLY=($(compgen -W "${available_models}" -- "${cur}"))
                    return 0
                elif [[ "$cmd" == "remove" ]]; then
                    # For remove, suggest installed models
                    local installed_models=$(_get_ollama_models)
                    if [[ -n "$installed_models" ]]; then
                        COMPREPLY=($(compgen -W "${installed_models}" -- "${cur}"))
                    fi
                    return 0
                fi
            fi
            # No completions for other subcommands
            return 0
            ;;
    esac
}

# Register the completion function
complete -F _aixcl_completion aixcl 