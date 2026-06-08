#!/usr/bin/env bash
# Command dispatcher for AIXCL - routes commands to appropriate handlers

function main() {
    if [[ $# -lt 1 ]]; then
        help_menu
    fi

    case "$1" in
        service)
            shift
            service "$@"
            ;;
        models)
            shift
            models "$@"
            ;;

        help)
            help_menu
            ;;

        config)
            echo "Error: The 'config' command has been deprecated."
            echo "Use './aixcl engine' instead of './aixcl config engine'."
            echo ""
            echo "Examples:"
            echo "  ./aixcl engine set ollama"
            echo "  ./aixcl engine auto"
            return 1
            ;;
        engine)
            shift
            engine "$@"
            ;;
        utils)
            shift
            utils_cmd "$@"
            ;;
        stack)
            shift
            stack_cmd "$@"
            ;;
        vault)
            shift
            cmd_vault "$@"
            ;;
        app)
            shift
            app_cmd "$@"
            ;;
        restart)
            shift
            restart "$@"
            ;;

        *)
            echo "Error: Unknown command '$1'" >&2
            help_menu
            ;;
    esac
}
