#!/usr/bin/env bash
# CLI argument parsing and help functionality for AIXCL

# Completion script path (set by main script)
COMPLETION_SCRIPT="${SCRIPT_DIR}/completion/aixcl.bash"

function help_menu() {
    cat << 'EOF'
./aixcl <command> [<args>]

COMMANDS

    stack <action> [options]
        start [--profile <profile> | -p <profile>]    Start services
        stop                                            Stop all services
        restart [--profile <profile>]                   Restart services
        status                                          Show service status
        logs [<service>] [<lines>=50]                   Show service logs
        init                                            Initialize .env and credentials

    engine <action> [<engine>]
        set {ollama}                                    Set inference engine
        auto                                            Auto-detect optimal engine

    models <action> [<name>...]
        add <model> [<model>...]                        Add model(s)
        remove <model> [<model>...]                     Remove model(s)
        list                                            List installed models

    service <action> <name>
        start <service>                                 Start a service
        stop <service>                                  Stop a service
        restart <service>                               Restart a service

    app <action> [<name>]
        list                                            List installed applications
        start <app>                                     Start an application
        stop <app>                                      Stop an application
        restart <app>                                   Restart an application
        status <app>                                    Show application status
        build <app>                                     Build an application image
        remove <app>                                    Stop, rm, and clean an application
        scaffold <name>                                 Create a new application scaffold
        install <url>                                   Install an application from a URL
        help                                            Show app command help

    utils <action>
        check-env                                       Verify environment
        bash-completion                                 Install bash completion
        prune                                           Clean Docker resources (keeps images)
        prune --all                                     Full wipe including images

    checks <action>
        all                                             Run every local CI check with summary
        paths                                           Documentation links and stale paths
        agents                                          .claude/.opencode mirror parity
        elisions                                        AI-elision placeholders, mass deletions
        generated                                       Tracked generated files
        ascii                                           Non-ASCII punctuation in markdown
        yaml                                            yamllint over the repository
        compose                                         Compose file validation
        env                                             Environment prerequisites
        pr-refs <file>                                  Issue/PR body reference style

    vault <action>
        start                                           Start Vault container
        stop                                            Stop Vault container
        restart                                         Restart Vault container
        init                                            Initialize Vault
        unseal                                          Unseal Vault
        status                                          Check Vault health
        credentials                                     View dynamic credentials
        passwords                                       View bootstrap passwords
        rotate                                          Trigger credential rotation
        logs [n]                                        View Vault logs

    release <action>
        prep                                            Draft changelog, create issue and branch
        tag                                             Tag merged release, verify publication
        finish                                          Sync dev, close issues, clean up
        status                                          Show release cycle state

    restart                                             Shortcut for stack restart

PROFILES

    bld     Builder-focused (monitoring stack)
    sys     Complete stack with automation

NOTES

    [*] ./aixcl restart is a shortcut for ./aixcl stack restart
    [*] See docs/architecture/governance/02_profiles.md for profile details
EOF
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
