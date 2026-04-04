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

function utils_cmd() {
    if [[ $# -lt 1 ]]; then
        echo "Error: Utils action is required"
        echo "Usage: $0 utils {check-env|bash-completion}"
        echo "Examples:"
        echo "  $0 utils check-env         - Verify environment setup"
        echo "  $0 utils bash-completion   - Install bash completion"
        return 1
    fi

    local action="$1"
    shift

    # Check for extra arguments
    if [ $# -gt 0 ]; then
        echo "Error: Unknown argument '$1'"
        echo "Usage: $0 utils {check-env|bash-completion}"
        return 1
    fi

    case "$action" in
        check-env)
            check_env
            ;;
        bash-completion)
            install_completion
            ;;
        *)
            echo "Error: Unknown utils action '$action'"
            echo "Usage: $0 utils {check-env|bash-completion}"
            echo "Examples:"
            echo "  $0 utils check-env         - Verify environment setup"
            echo "  $0 utils bash-completion   - Install bash completion"
            return 1
            ;;
    esac
}
