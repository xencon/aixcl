#!/usr/bin/env bash
# CLI argument parsing and help functionality for AIXCL

# Completion script path (set by main script)
COMPLETION_SCRIPT="${SCRIPT_DIR}/completion/aixcl.bash"

function help_menu() {
    echo "Usage: ./aixcl <cmd> [options]"
    echo ""
    echo "Stack: stack <action> [options]"
    echo "  stack start [--profile <profile>]    - Start services (uses PROFILE from .env if set)"
    echo "  stack start -p <profile>            - Short form: Start with profile"
    echo "  stack start                         - Start with profile from .env (or show profiles)"
    echo "  stack stop                          - Stop all services"
    echo "  stack restart [--profile <profile>] - Restart services (uses .env PROFILE if not specified)"
    echo "  stack status                        - Show service status"
    echo "  stack logs [service] [lines]        - Show logs"
    echo "  stack export-quadlet                - Export services as Podman Quadlets (Systemd)"
    echo ""
    echo "  Profiles (usr, dev, ops, sys):"
    echo "    usr   - User-oriented runtime (runtime core, PostgreSQL for persistence)"
    echo "    dev   - Developer workstation (runtime core + UI + DB)"
    echo "    ops   - Observability-focused (runtime core + monitoring/logging)"
    echo "    sys   - System-oriented (complete stack with automation)"
    echo ""
    echo "Engine: engine <action> [engine]"
    echo "  engine set <engine>                 - Set the inference engine (ollama, vllm, llamacpp)"
    echo "  engine auto                         - Auto-detect optimal engine based on hardware"
    echo ""
    echo "Restart: restart [service]             - Short form for 'stack restart'"
    echo ""
    echo "Service: service <action> <name>"
    echo "  Runtime Core (always enabled): engine (${INFERENCE_ENGINE:-ollama})"
    echo ""
    echo "Models: models <action> [name]"
    echo "  models add <name>                   - Add model(s) to Ollama/vLLM/llama.cpp"
    echo "  models remove <name>                - Remove model(s) from active engine"
    echo "  models list                         - List installed models"
    echo ""
    echo "Utils: utils <action>"
    echo "  utils check-env                     - Verify environment setup"
    echo "  utils bash-completion               - Install bash completion"
    echo "  utils clean                         - Clean up unused Docker resources"
    echo ""
    echo "For detailed profile definitions, see: docs/architecture/governance/02_profiles.md"
    exit 0
}

function install_completion() {
    echo "Installing bash completion for aixcl..."
    echo "Cleaning up any existing completion files..."
    
    # Get the script directory (already set globally)
    # SCRIPT_DIR and COMPLETION_SCRIPT are already defined at script startup
    
    if [[ ! -f "$COMPLETION_SCRIPT" ]]; then
        echo "Error: Completion script not found at $COMPLETION_SCRIPT"
        exit 1
    fi
    
    # Clean up existing completion files
    local cleanup_dirs=(
        "$HOME/.local/share/bash-completion/completions"
        "/etc/bash_completion.d"
    )
    
    for dir in "${cleanup_dirs[@]}"; do
        if [[ -f "$dir/aixcl" ]]; then
            echo "Removing existing completion file: $dir/aixcl"
            rm -f "$dir/aixcl"
        fi
    done
    
    # Clean up .bashrc - remove any old aixcl completion references
    if [[ -f "$HOME/.bashrc" ]]; then
        echo "Cleaning up .bashrc..."
        local temp_bashrc
        temp_bashrc="$(mktemp)"
        # Remove the entire completion block using sed
        # Pattern: from "Added by aixcl installer" through the next standalone "fi"
        sed '/Added by aixcl installer/,/^[[:space:]]*fi[[:space:]]*$/d' "$HOME/.bashrc" > "$temp_bashrc" || cp "$HOME/.bashrc" "$temp_bashrc"
        
        # Also remove any broken if/fi pairs where if contains aixcl but source was already removed
        # This handles the case where only "if ... then" and "fi" remain
        awk '
            BEGIN { prev_line = ""; prev_prev_line = "" }
            {
                # Check if current line is "fi" and previous was an empty if statement for aixcl
                if (/^[[:space:]]*fi[[:space:]]*$/) {
                    if (prev_line ~ /^[[:space:]]*if[[:space:]]+\[.*aixcl.*\][[:space:]]*;[[:space:]]*then[[:space:]]*$/) {
                        # This is an empty if/fi block for aixcl, skip both
                        prev_line = ""
                        prev_prev_line = ""
                        next
                    } else {
                        # Normal fi, keep it
                        if (prev_prev_line != "") print prev_prev_line
                        if (prev_line != "") print prev_line
                        print $0
                        prev_prev_line = ""
                        prev_line = ""
                        next
                    }
                }
                # Not a fi, so print previous lines if we have them
                if (prev_prev_line != "") {
                    print prev_prev_line
                    prev_prev_line = ""
                }
                if (prev_line != "") {
                    prev_prev_line = prev_line
                }
                prev_line = $0
            }
            END {
                if (prev_prev_line != "") print prev_prev_line
                if (prev_line != "") print prev_line
            }
        ' "$temp_bashrc" > "${temp_bashrc}.2" || cp "$temp_bashrc" "${temp_bashrc}.2"
        mv "${temp_bashrc}.2" "$temp_bashrc"
        
        # Only replace if we actually removed something or if file is different
        if ! cmp -s "$HOME/.bashrc" "$temp_bashrc"; then
            cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%s)" 2>/dev/null || true
            mv "$temp_bashrc" "$HOME/.bashrc"
            echo "Cleaned up old completion references from .bashrc"
        else
            rm -f "$temp_bashrc"
        fi
    fi
    
    # Determine the appropriate completion directory
    if [[ -d "/etc/bash_completion.d" ]] && [[ -w "/etc/bash_completion.d" ]]; then
        # System-wide installation (requires write permission)
        COMPLETION_DIR="/etc/bash_completion.d"
    elif [[ -d "$HOME/.local/share/bash-completion/completions" ]]; then
        # User-specific installation (preferred)
        COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
    else
        # Create user directory if it doesn't exist
        COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
        mkdir -p "$COMPLETION_DIR"
    fi
    
    # Copy the completion script
    cp "$COMPLETION_SCRIPT" "$COMPLETION_DIR/aixcl"
    chmod +x "$COMPLETION_DIR/aixcl"
    
    echo "[x] Bash completion installed to $COMPLETION_DIR/aixcl"
    echo ""
    echo "To use it immediately in this shell, run:"
    echo "  source $COMPLETION_DIR/aixcl"
    echo ""
    echo "Or restart your shell. It will be automatically loaded in new shell sessions."
    echo ""
}
