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
    local docker_cmd="${DOCKER_BIN:-docker}"

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
    local docker_cmd="${DOCKER_BIN:-docker}"

    echo "SCORCHED EARTH: Removing ALL container resources including images..."
    echo "Using container engine: $docker_cmd"
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

    if [ -f "pgadmin-servers.json" ]; then
        rm -f pgadmin-servers.json
        echo "Cleaned up pgAdmin configuration file"
    fi
    rm -f .aixcl.initialized .env
    echo ""

    echo "Purge complete. All container resources removed."
    $docker_cmd system df 2>/dev/null || echo "No resources found (good!)"
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
