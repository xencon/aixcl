#!/usr/bin/env bash
# Utility commands (check-env, bash-completion)

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/env_check.sh"
source "${SCRIPT_DIR}/lib/color.sh"

# Utils check-env command
utils_check_env() {
    check_env
}

# Utils bash-completion command
utils_bash_completion() {
    echo "Installing bash completion for aixcl..."
    echo "Cleaning up any existing completion files..."
    
    COMPLETION_SCRIPT="${SCRIPT_DIR}/completion/aixcl.bash"
    
    if [[ ! -f "$COMPLETION_SCRIPT" ]]; then
        print_error "Completion script not found at $COMPLETION_SCRIPT"
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
        local temp_bashrc="$(mktemp)"
        # Remove all lines related to aixcl completion
        grep -v "Added by aixcl installer" "$HOME/.bashrc" | \
        grep -v "source.*bash-completion.*aixcl" | \
        grep -v "source.*completions/aixcl" > "$temp_bashrc" || true
        
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
    
    print_success "Bash completion installed to $COMPLETION_DIR/aixcl"
    echo ""
    echo "To use it immediately in this shell, run:"
    echo "  source $COMPLETION_DIR/aixcl"
    echo ""
    echo "Or restart your shell. It will be automatically loaded in new shell sessions."
    echo ""
    
    # Add to .bashrc
    local bashrc_entry="# Added by aixcl installer
if [ -f \"$COMPLETION_DIR/aixcl\" ]; then
    source \"$COMPLETION_DIR/aixcl\"
fi"
    
    if ! grep -q "Added by aixcl installer" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "$bashrc_entry" >> "$HOME/.bashrc"
        echo "Added sourcing to ~/.bashrc for persistent completion"
    else
        echo "Completion script already referenced in ~/.bashrc"
    fi
    
    echo ""
    echo "Installation complete! To test:"
    echo "  1. Source it now: source $COMPLETION_DIR/aixcl"
    echo "  2. Or restart your shell"
    echo "  3. Then try: ./aixcl <TAB>"
}
