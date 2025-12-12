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
    
    COMPLETION_SCRIPT="${SCRIPT_DIR}/completion/aixcl.bash"
    
    if [[ ! -f "$COMPLETION_SCRIPT" ]]; then
        print_error "Completion script not found at $COMPLETION_SCRIPT"
        exit 1
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
    
    print_success "Bash completion installed to $COMPLETION_DIR/aixcl"
    echo "To use it immediately, run: source $COMPLETION_DIR/aixcl"
    echo "It will be automatically loaded in new shell sessions."
    
    # Add to .bashrc if not already there (with safer file handling)
    if ! grep -q "source.*$COMPLETION_DIR/aixcl" "$HOME/.bashrc" 2>/dev/null; then
        # Create backup of .bashrc before modification
        if [ -f "$HOME/.bashrc" ]; then
            cp "$HOME/.bashrc" "$HOME/.bashrc.backup.$(date +%s)"
        fi
        
        # Create a temporary file with atomic operations
        local temp_bashrc="$(mktemp)"
        
        # Copy existing .bashrc content, removing old aixcl entries
        if [ -f "$HOME/.bashrc" ] && grep -q "Added by aixcl installer" "$HOME/.bashrc"; then
            grep -v -A 3 "Added by aixcl installer" "$HOME/.bashrc" | sed '/^$/d' > "$temp_bashrc"
        elif [ -f "$HOME/.bashrc" ]; then
            cp "$HOME/.bashrc" "$temp_bashrc"
        else
            touch "$temp_bashrc"
        fi
        
        # Add new entry
        cat >> "$temp_bashrc" << EOF

# Added by aixcl installer
if [ -f "$COMPLETION_DIR/aixcl" ]; then
    source "$COMPLETION_DIR/aixcl"
fi
EOF
        
        # Atomically replace .bashrc
        mv "$temp_bashrc" "$HOME/.bashrc"
        echo "Added sourcing to ~/.bashrc for persistent completion"
    else
        echo "Completion script already referenced in ~/.bashrc"
    fi
}
