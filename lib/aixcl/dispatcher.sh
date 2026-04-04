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
            shift
            config_cmd "$@"
            ;;
        utils)
            shift
            utils_cmd "$@"
            ;;
        stack)
            shift
            stack_cmd "$@"
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
