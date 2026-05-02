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
    
    echo "Cleaning up unused container resources..."
    echo "Using container engine: $docker_cmd"
    echo ""
    
    # Show current disk usage
    echo "Current container engine disk usage:"
    $docker_cmd system df
    echo ""
    
    # Remove dangling images (untagged, not referenced)
    echo "Removing dangling images..."
    $docker_cmd image prune -f
    echo ""
    
    # Remove unused images (not referenced by running containers)
    echo "Removing unused images (not referenced by running containers)..."
    $docker_cmd image prune -a -f
    echo ""
    
    # Remove stopped containers
    echo "Removing stopped containers..."
    $docker_cmd container prune -f
    echo ""
    
    # Remove unused volumes
    echo "Removing unused volumes..."
    $docker_cmd volume prune -f
    echo ""
    
    # Remove AIXCL-specific external volumes (scorched earth)
    echo "Removing AIXCL volumes..."
    local volumes
    volumes=$($docker_cmd volume ls -q 2>/dev/null | grep "^aixcl-" || true)
    if [ -n "$volumes" ]; then
        echo "$volumes" | xargs -r $docker_cmd volume rm 2>/dev/null || true
    fi
    echo ""
    
    # Clean up pgAdmin configuration file for security
    if [ -f "pgadmin-servers.json" ]; then
        rm -f pgadmin-servers.json
        echo "Cleaned up pgAdmin configuration file"
    fi
    
    echo ""
    echo "[x] Cleanup complete."
    echo ""
    echo "Updated container engine disk usage:"
    $docker_cmd system df
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
