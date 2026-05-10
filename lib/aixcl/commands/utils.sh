#!/usr/bin/env bash
# Utility commands for AIXCL

function needs_rebuild() {
    local service="$1"
    # Check if service needs rebuild based on source changes
    # Currently no local-build services remain in the stack.
    # The service parameter is kept for API compatibility.
    case "$service" in
        open-webui|ollama|vllm|llamacpp)
            # These are all remote images now, no local builds
            return 1
            ;;
        *)
            # Unknown service, assume no rebuild needed
            return 1
            ;;
    esac
}

function prune() {
    local docker_cmd="${DOCKER_BIN:-podman}"

    echo "Pruning AIXCL stack (volumes and state, images kept)..."
    echo ""

    echo "Stopping stack..."
    ./aixcl stack stop 2>/dev/null || true
    echo ""

    echo "Removing state files..."
    rm -f .aixcl.initialized .env pgadmin-servers.json
    echo ""

    echo "Removing volumes..."
    local all_volumes
    all_volumes=$($docker_cmd volume ls -q 2>/dev/null || true)
    if [ -n "$all_volumes" ]; then
        echo "$all_volumes" | xargs -r $docker_cmd volume rm -f 2>/dev/null || true
    fi
    echo ""

    echo "Prune complete. Images retained for fast restart."
    echo "Run './aixcl stack init && ./aixcl stack start --profile sys' to bring the stack back up."
}

function prune_all() {
    local docker_cmd="${DOCKER_BIN:-podman}"

    echo "WARNING: This will remove all AIXCL container resources AND system configuration."
    echo "The system will remain operational. This cannot be undone."
    echo ""
    echo "Will remove:"
    echo "  - All containers, images, volumes, networks"
    echo "  - State files (.env, .aixcl.initialized, pgadmin-servers.json)"
    echo "  - Project directories (logs/, .security/, .audit/)"
    echo "  - AIXCL Podman configuration (~/.config/containers/)"
    echo "  - AIXCL NVIDIA CDI user config (~/.config/cdi/nvidia.yaml, if present)"
    echo "  - Bash completion files and ~/.bashrc AIXCL entries"
    echo ""
    echo "Will NOT remove (standard system config, shared with other tools):"
    echo "  - /etc/subuid, /etc/subgid"
    echo "  - ~/.local/share/containers/ (Podman storage)"
    echo "  - podman.socket systemd service"
    echo ""
    read -r -p "Type 'PURGE' to confirm: " reply
    if [[ "$reply" != "PURGE" ]]; then
        echo "Aborted."
        return 0
    fi
    echo ""

    echo "Stopping all containers..."
    $docker_cmd stop -a 2>/dev/null || true
    echo "Removing all containers..."
    $docker_cmd rm -f -a 2>/dev/null || true
    echo ""

    echo "Removing all images..."
    $docker_cmd rmi -f -a 2>/dev/null || true
    echo ""

    echo "Removing all volumes..."
    local all_volumes
    all_volumes=$($docker_cmd volume ls -q 2>/dev/null || true)
    if [ -n "$all_volumes" ]; then
        echo "$all_volumes" | xargs -r $docker_cmd volume rm -f 2>/dev/null || true
    fi
    echo ""

    echo "Removing custom networks..."
    local networks
    networks=$($docker_cmd network ls -q 2>/dev/null | grep -v "^podman$" || true)
    if [ -n "$networks" ]; then
        echo "$networks" | xargs -r $docker_cmd network rm 2>/dev/null || true
    fi
    echo ""

    echo "System prune..."
    $docker_cmd system prune -f --all --volumes 2>/dev/null || true
    echo ""

    echo "Removing state files..."
    rm -f .aixcl.initialized .env pgadmin-servers.json .env.podman
    echo ""

    echo "Removing project directories..."
    rm -rf logs .security .audit
    echo ""

    echo "Removing AIXCL Podman configuration..."
    if [[ -d "${HOME}/.config/containers" ]]; then
        rm -rf "${HOME}/.config/containers"
        echo "  Removed ~/.config/containers"
    fi
    if [[ -f "${HOME}/.config/cdi/nvidia.yaml" ]]; then
        rm -f "${HOME}/.config/cdi/nvidia.yaml"
        rmdir "${HOME}/.config/cdi" 2>/dev/null || true
        echo "  Removed ~/.config/cdi/nvidia.yaml"
    fi
    echo ""

    echo "Removing bash completion..."
    rm -f "${HOME}/.local/share/bash-completion/completions/aixcl"
    rm -f "/etc/bash_completion.d/aixcl" 2>/dev/null || true
    if [[ -f "${HOME}/.bashrc" ]]; then
        local temp_bashrc
        temp_bashrc="$(mktemp)"
        sed '/Added by aixcl installer/,/^[[:space:]]*fi[[:space:]]*$/d' "${HOME}/.bashrc" > "$temp_bashrc" \
            || cp "${HOME}/.bashrc" "$temp_bashrc"
        if ! cmp -s "${HOME}/.bashrc" "$temp_bashrc"; then
            cp "${HOME}/.bashrc" "${HOME}/.bashrc.backup.$(date +%s)" 2>/dev/null || true
            mv "$temp_bashrc" "${HOME}/.bashrc"
            echo "  Cleaned AIXCL entries from ~/.bashrc"
        else
            rm -f "$temp_bashrc"
        fi
    fi
    echo ""

    echo "Purge complete. All AIXCL resources removed."
    echo ""
    echo "NOTE: The following standard system config was intentionally preserved:"
    echo "  /etc/subuid, /etc/subgid   -- required for rootless containers system-wide"
    echo "  ~/.local/share/containers/ -- Podman storage (may contain non-AIXCL data)"
    echo "  podman.socket              -- standard Podman systemd service"
    echo ""
    echo "To also reset Podman storage: podman system reset --force"
}

function utils_cmd() {
    if [[ $# -lt 1 ]]; then
        echo "Error: Utils action is required"
        echo "Usage: $0 utils {check-env|bash-completion|prune [--all]}"
        echo "Examples:"
        echo "  $0 utils check-env         - Verify environment setup"
        echo "  $0 utils bash-completion   - Install bash completion"
        echo "  $0 utils prune             - Remove volumes and state, keep images"
        echo "  $0 utils prune --all       - Remove everything including images"
        return 1
    fi

    local action="$1"
    shift

    case "$action" in
        check-env)
            check_env
            ;;
        bash-completion)
            install_completion
            ;;
        prune)
            if [[ "${1:-}" == "--all" ]]; then
                prune_all
            else
                prune
            fi
            ;;
        *)
            echo "Error: Unknown utils action '$action'"
            echo "Usage: $0 utils {check-env|bash-completion|prune [--all]}"
            echo "Examples:"
            echo "  $0 utils check-env         - Verify environment setup"
            echo "  $0 utils bash-completion   - Install bash completion"
            echo "  $0 utils prune             - Remove volumes and state, keep images"
            echo "  $0 utils prune --all       - Remove everything including images"
            return 1
            ;;
    esac
}
