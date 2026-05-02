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

function clean() {
    # Use DOCKER_BIN from environment (set by .env or docker_utils.sh), default to 'docker'
    local docker_cmd="${DOCKER_BIN:-docker}"
    
    echo "SCORCHED EARTH: Removing ALL container resources..."
    echo "Using container engine: $docker_cmd"
    echo ""
    
    # Stop and remove ALL containers (running and stopped)
    echo "Stopping all containers..."
    $docker_cmd stop -a 2>/dev/null || true
    echo "Removing all containers..."
    $docker_cmd rm -f -a 2>/dev/null || true
    echo ""
    
    # Remove ALL images (force)
    echo "Removing all images..."
    $docker_cmd rmi -f -a 2>/dev/null || true
    echo ""
    
    # Remove ALL volumes by name (not just prune)
    echo "Removing all volumes..."
    local all_volumes
    all_volumes=$($docker_cmd volume ls -q 2>/dev/null || true)
    if [ -n "$all_volumes" ]; then
        echo "$all_volumes" | xargs -r $docker_cmd volume rm -f 2>/dev/null || true
    fi
    echo ""
    
    # Remove custom networks (not system networks)
    echo "Removing custom networks..."
    local networks
    networks=$($docker_cmd network ls -q 2>/dev/null | grep -v "^podman$" || true)
    if [ -n "$networks" ]; then
        echo "$networks" | xargs -r $docker_cmd network rm 2>/dev/null || true
    fi
    echo ""
    
    # System prune for anything left
    echo "System prune..."
    $docker_cmd system prune -f --all --volumes 2>/dev/null || true
    echo ""
    
    # Clean up pgAdmin configuration file for security
    if [ -f "pgadmin-servers.json" ]; then
        rm -f pgadmin-servers.json
        echo "Cleaned up pgAdmin configuration file"
    fi
    
    echo ""
    echo "✅ SCORCHED EARTH CLEAN COMPLETE"
    echo ""
    echo "Container engine should now be empty:"
    $docker_cmd system df 2>/dev/null || echo "No resources found (good!)"
}

function utils_cmd() {
    if [[ $# -lt 1 ]]; then
        echo "Error: Utils action is required"
        echo "Usage: $0 utils {check-env|bash-completion|clean}"
        echo "Examples:"
        echo "  $0 utils check-env         - Verify environment setup"
        echo "  $0 utils bash-completion   - Install bash completion"
        echo "  $0 utils clean              - Clean up unused Docker resources"
        return 1
    fi

    local action="$1"
    shift

    # Check for extra arguments for actions that don't take them
    if [ $# -gt 0 ] && [ "$action" != "clean" ]; then
        echo "Error: Unknown argument '$1'"
        echo "Usage: $0 utils {check-env|bash-completion|clean}"
        return 1
    fi

    case "$action" in
        check-env)
            check_env
            ;;
        bash-completion)
            install_completion
            ;;
        clean)
            clean
            ;;
        *)
            echo "Error: Unknown utils action '$action'"
            echo "Usage: $0 utils {check-env|bash-completion|clean}"
            echo "Examples:"
            echo "  $0 utils check-env         - Verify environment setup"
            echo "  $0 utils bash-completion   - Install bash completion"
            echo "  $0 utils clean              - Clean up unused Docker resources"
            return 1
            ;;
    esac
}
