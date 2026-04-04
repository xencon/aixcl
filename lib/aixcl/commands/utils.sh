#!/usr/bin/env bash
# Utility commands for AIXCL

# shellcheck disable=SC2034
function needs_rebuild() {
    local service="$1"
    # Currently no local-build services remain in the stack.
    return 1
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
