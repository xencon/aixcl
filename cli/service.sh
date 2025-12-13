#!/usr/bin/env bash
# Service control commands (start, stop, restart individual services)

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_utils.sh"
source "${SCRIPT_DIR}/lib/color.sh"
source "${SCRIPT_DIR}/lib/pgadmin_utils.sh"

# Service start command
service_start() {
    if [ -z "$1" ]; then
        print_error "Service name is required"
        echo "Usage: aixcl service start <service-name>"
        echo "Available services: ${ALL_SERVICES[*]}"
        return 1
    fi
    
    local service="$1"
    
    # Validate service name
    if ! is_valid_service "$service"; then
        print_error "Unknown service '$service'"
        echo "Available services: ${ALL_SERVICES[*]}"
        return 1
    fi
    
    local container_name=$(get_container_name "$service")
    
    # Check if service is already running
    if is_container_running "$container_name"; then
        echo "Service '$service' is already running."
        return 0
    fi
    
    # Set up compose command with GPU detection
    set_compose_cmd
    
    echo "Starting service: $service..."
    
    # For services that may use registry images, we need to remove any existing
    # container (running or stopped) to avoid docker-compose ContainerConfig KeyError bug.
    # This happens with older docker-compose versions when containers were created from
    # pulled registry images rather than locally built ones.
    # Docker-compose may create containers with hash prefixes (e.g., 87e4f34ade77_llm-council),
    # so we need to check for both exact name and prefixed versions.
    
    # Remove via docker-compose first (this handles prefixed containers that compose knows about)
    "${COMPOSE_CMD[@]}" rm -f "$service" 2>/dev/null || true
    
    # Also explicitly remove containers with hash prefixes by finding all containers
    # that end with the container name (to catch prefixed versions like 87e4f34ade77_llm-council)
    # Use a more permissive pattern to catch any container containing the service name
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            container_id=$(echo "$line" | awk '{print $1}')
            container_name_found=$(echo "$line" | awk '{print $2}')
            # Match containers that end with the container name (exact or with prefix)
            if [[ "$container_name_found" == *"${container_name}" ]] || [[ "$container_name_found" == "${container_name}" ]]; then
                echo "Removing container: $container_name_found ($container_id)"
                docker rm -f "$container_id" 2>/dev/null || true
            fi
        fi
    done < <(docker ps -a --format "{{.ID}} {{.Names}}" 2>/dev/null | grep -i "${container_name}" || true)
    
    # Remove by exact name as a final fallback
    docker rm -f "$container_name" 2>/dev/null || true
    
    # Check for .env file if needed (for services that require it)
    if [ ! -f "${SCRIPT_DIR}/.env" ] && [[ "$service" == "open-webui" || "$service" == "postgres" || "$service" == "pgadmin" ]]; then
        if [ -f "${SCRIPT_DIR}/.env.example" ]; then
            print_warning ".env file not found. Copying from .env.example..."
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
            load_env_file "${SCRIPT_DIR}/.env"
        else
            print_error ".env file required for service '$service'"
            return 1
        fi
    fi
    
    # Generate pgAdmin configuration if starting pgadmin
    if [ "$service" = "pgadmin" ]; then
        generate_pgadmin_config
    fi
    
    # Start the specific service
    if "${COMPOSE_CMD[@]}" up -d "$service"; then
        print_success "Successfully started service: $service"
        
        # Wait a moment for the service to initialize
        sleep 2
        
        # Check if the container is actually running
        if is_container_running "$container_name"; then
            echo "Service '$service' is now running."
        else
            print_warning "Service '$service' may not have started correctly. Check logs with: aixcl stack logs $service"
        fi
        return 0
    else
        print_error "Failed to start service: $service"
        return 1
    fi
}

# Service stop command
service_stop() {
    if [ -z "$1" ]; then
        print_error "Service name is required"
        echo "Usage: aixcl service stop <service-name>"
        echo "Available services: ${ALL_SERVICES[*]}"
        return 1
    fi
    
    local service="$1"
    
    # Validate service name
    if ! is_valid_service "$service"; then
        print_error "Unknown service '$service'"
        echo "Available services: ${ALL_SERVICES[*]}"
        return 1
    fi
    
    local container_name=$(get_container_name "$service")
    
    # Check if service is running
    if ! is_container_running "$container_name"; then
        echo "Service '$service' is not running."
        return 0
    fi
    
    # Set up compose command with GPU detection
    set_compose_cmd
    
    echo "Stopping service: $service..."
    
    # Stop the specific service
    if "${COMPOSE_CMD[@]}" stop "$service"; then
        print_success "Successfully stopped service: $service"
        
        # Clean up pgAdmin configuration if stopping pgadmin
        if [ "$service" = "pgadmin" ] && [ -f "${SCRIPT_DIR}/pgadmin-servers.json" ]; then
            rm -f "${SCRIPT_DIR}/pgadmin-servers.json"
            print_clean "Cleaned up pgAdmin configuration file"
        fi
        return 0
    else
        print_error "Failed to stop service: $service"
        return 1
    fi
}

# Service restart command
service_restart() {
    if [ -z "$1" ]; then
        print_error "Service name is required"
        echo "Usage: aixcl service restart <service-name>"
        echo "Available services: ${ALL_SERVICES[*]}"
        return 1
    fi
    
    local service="$1"
    service_stop "$service"
    sleep 2
    service_start "$service"
}
