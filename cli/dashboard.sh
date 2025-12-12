#!/usr/bin/env bash
# Dashboard commands (open web interfaces)

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_utils.sh"
source "${SCRIPT_DIR}/lib/color.sh"

CONTAINER_NAME="open-webui"

# Open URL in browser
open_url_in_browser() {
    local url="$1"

    if command -v xdg-open &> /dev/null; then
        xdg-open "$url" 2>/dev/null &
    elif command -v open &> /dev/null; then
        open "$url" 2>/dev/null &
    else
        print_warning "Could not detect default browser. Please open $url manually."
    fi
}

# Dashboard grafana command
dashboard_grafana() {
    echo "Opening Grafana monitoring dashboard..."

    if ! is_container_running "grafana"; then
        print_error "Grafana container is not running. Please start the services first."
        return 1
    fi

    # Check if Grafana is responding
    if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null | grep -q "200"; then
        print_error "Grafana is not responding yet. Please wait for it to start."
        return 1
    fi

    local url="http://localhost:3000"
    echo "Grafana is available at: $url"
    echo "Default credentials: admin / admin (change on first login)"
    echo "Opening in default browser..."
    open_url_in_browser "$url"
}

# Dashboard openwebui command
dashboard_openwebui() {
    echo "Opening Open WebUI dashboard..."

    if ! is_container_running "$CONTAINER_NAME"; then
        print_error "Open WebUI container is not running. Please start the services first."
        return 1
    fi

    local health_status
    health_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")

    if [ "$health_status" != "200" ]; then
        print_error "Open WebUI is not responding yet (HTTP $health_status). Please wait for it to start."
        return 1
    fi

    local url="http://localhost:8080"
    echo "Open WebUI is available at: $url"
    echo "Opening in default browser..."
    open_url_in_browser "$url"
}

# Dashboard pgadmin command
dashboard_pgadmin() {
    echo "Opening pgAdmin dashboard..."

    if ! is_container_running "pgadmin"; then
        print_error "pgAdmin container is not running. Please start the services first."
        return 1
    fi

    local pgadmin_status
    pgadmin_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5050 2>/dev/null || echo "000")

    case "$pgadmin_status" in
        200|302)
            ;;
        *)
            print_error "pgAdmin is not responding yet (HTTP $pgadmin_status). Please wait for it to start."
            return 1
            ;;
    esac

    local url="http://localhost:5050"
    echo "pgAdmin is available at: $url"
    echo "Opening in default browser..."
    open_url_in_browser "$url"
}
