#!/usr/bin/env bash
# AIXCL - AI & Infrastructure Stack Control CLI
# Main entry point for the modular CLI structure

set -e  # Exit on error
set -u  # Treat unset variables as an error
set -o pipefail  # Catch errors in pipelines

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library files
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_utils.sh"
source "${SCRIPT_DIR}/lib/color.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/pgadmin_utils.sh"
source "${SCRIPT_DIR}/lib/council_utils.sh"

# Load environment variables from .env file
load_env_file "${SCRIPT_DIR}/.env"

# Source CLI modules (with error handling)
for module in stack.sh service.sh models.sh dashboard.sh utils.sh; do
    if [ -f "${SCRIPT_DIR}/cli/${module}" ]; then
        source "${SCRIPT_DIR}/cli/${module}"
    else
        echo "Warning: CLI module ${module} not found" >&2
    fi
done

# Council module
source "${SCRIPT_DIR}/cli/council.sh"

# Help function
show_help() {
    echo "Usage: $0 <command> <subcommand> [options]"
    echo ""
    echo "Stack Management:"
    echo "  stack start                Start all services"
    echo "  stack stop                 Stop all services"
    echo "  stack restart              Restart the entire stack"
    echo "  stack status               Show service status"
    echo "  stack logs [svc] [n]       Show logs for all or one service, optional line count"
    echo "  stack clean                Remove unused Docker resources"
    echo ""
    echo "Service Control:"
    echo "  service <start|stop|restart> <name>  Control individual service"
    echo "                           Services: ${ALL_SERVICES[*]}"
    echo ""
    echo "Models & Configuration:"
    echo "  models <add|remove|list> [name]   Manage LLM models"
    echo "  council <configure|status|list>   Configure LLM Council"
    echo ""
    echo "Utilities:"
    echo "  dashboard <name>          Open dashboard (grafana|openwebui|pgadmin)"
    echo "  utils check-env           Verify environment setup"
    echo "  utils bash-completion     Install bash completion"
    echo "  help                      Show this help"
    exit 0
}

# Main command router
main() {
    if [[ $# -lt 1 ]]; then
        show_help
    fi

    local command="$1"
    shift

    case "$command" in
        stack)
            if [[ $# -lt 1 ]]; then
                print_error "Stack subcommand required"
                echo "Usage: $0 stack <start|stop|restart|status|logs|clean>"
                exit 1
            fi
            local subcommand="$1"
            shift
            case "$subcommand" in
                start)
                    stack_start
                    ;;
                stop)
                    stack_stop
                    ;;
                restart)
                    stack_restart
                    ;;
                status)
                    stack_status
                    ;;
                logs)
                    stack_logs "$@"
                    ;;
                clean)
                    stack_clean
                    ;;
                *)
                    print_error "Unknown stack subcommand: $subcommand"
                    echo "Usage: $0 stack <start|stop|restart|status|logs|clean>"
                    exit 1
                    ;;
            esac
            ;;
        service)
            if [[ $# -lt 2 ]]; then
                print_error "Service action and name are required"
                echo "Usage: $0 service <start|stop|restart> <service-name>"
                exit 1
            fi
            local action="$1"
            local service_name="$2"
            case "$action" in
                start)
                    service_start "$service_name"
                    ;;
                stop)
                    service_stop "$service_name"
                    ;;
                restart)
                    service_restart "$service_name"
                    ;;
                *)
                    print_error "Unknown service action: $action"
                    echo "Usage: $0 service <start|stop|restart> <service-name>"
                    exit 1
                    ;;
            esac
            ;;
        models)
            if [[ $# -lt 1 ]]; then
                print_error "Models action is required"
                echo "Usage: $0 models <add|remove|list> [<model-name> ...]"
                exit 1
            fi
            local action="$1"
            shift
            case "$action" in
                add)
                    models_add "$@"
                    ;;
                remove)
                    models_remove "$@"
                    ;;
                list)
                    models_list
                    ;;
                *)
                    print_error "Unknown models action: $action"
                    echo "Usage: $0 models <add|remove|list> [<model-name> ...]"
                    exit 1
                    ;;
            esac
            ;;
        dashboard)
            if [[ $# -lt 1 ]]; then
                print_error "Dashboard target is required"
                echo "Usage: $0 dashboard <grafana|openwebui|pgadmin>"
                exit 1
            fi
            local target="$1"
            case "$target" in
                grafana)
                    dashboard_grafana
                    ;;
                openwebui|open-webui|open_webui)
                    dashboard_openwebui
                    ;;
                pgadmin)
                    dashboard_pgadmin
                    ;;
                *)
                    print_error "Unknown dashboard target: $target"
                    echo "Usage: $0 dashboard <grafana|openwebui|pgadmin>"
                    exit 1
                    ;;
            esac
            ;;
        utils)
            if [[ $# -lt 1 ]]; then
                print_error "Utils subcommand is required"
                echo "Usage: $0 utils <check-env|bash-completion>"
                exit 1
            fi
            local subcommand="$1"
            shift
            case "$subcommand" in
                check-env)
                    utils_check_env
                    ;;
                bash-completion)
                    utils_bash_completion
                    ;;
                *)
                    print_error "Unknown utils subcommand: $subcommand"
                    echo "Usage: $0 utils <check-env|bash-completion>"
                    exit 1
                    ;;
            esac
            ;;
        council)
            if [[ $# -lt 1 ]]; then
                council_status
                exit 0
            fi
            local subcommand="$1"
            shift
            case "$subcommand" in
                configure)
                    council_configure
                    ;;
                status)
                    council_status
                    ;;
                list)
                    council_list
                    ;;
                *)
                    print_error "Unknown council subcommand: $subcommand"
                    echo "Usage: $0 council <configure|status|list>"
                    exit 1
                    ;;
            esac
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            ;;
    esac
}

main "$@"
