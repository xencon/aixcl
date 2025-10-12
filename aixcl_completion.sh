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

_aixcl_complete() {
    local cur prev words cword
    _init_completion || return

    # List of all possible commands
    local commands="start stop restart logs clean stats status add remove list metrics dashboard help install-completion check-env"

    # List of services for logs command
    local services="ollama open-webui postgres pgadmin watchtower prometheus grafana cadvisor node-exporter postgres-exporter nvidia-gpu-exporter"

    case "$prev" in
        'aixcl')
            # Complete with available commands
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
            return 0
            ;;
        'logs')
            # Complete with available services
            COMPREPLY=( $(compgen -W "$services" -- "$cur") )
            return 0
            ;;
        'add'|'remove')
            # If ollama is running, get list of available/installed models
            if docker ps --format "{{.Names}}" | grep -q "ollama"; then
                if [[ "$prev" == "add" ]]; then
                    # For 'add', suggest some common models
                    local models="starcoder2:latest nomic-embed-text:latest"
                    COMPREPLY=( $(compgen -W "$models" -- "$cur") )
                else
                    # For 'remove', list installed models
                    local installed_models=$(docker exec ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}')
                    COMPREPLY=( $(compgen -W "$installed_models" -- "$cur") )
                fi
            fi
            return 0
            ;;
    esac

    # Default to command completion if no specific case matched
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return 0
}

# Register the completion function
complete -F _aixcl_complete aixcl 