#!/usr/bin/env bash
# Shared container lifecycle utilities
# Used by: stack, service, vault commands
# Provides: container_start, container_stop, container_restart
# Dependencies: common.sh, docker_utils.sh (must be sourced first)

# Start a single container by service name
# Usage: container_start <service> [force_recreate]
container_start() {
    local service="$1"
    local force_recreate="${2:-false}"
    
    # Resolve 'engine' alias
    local actual_service="$service"
    if [[ "$service" == "engine" ]]; then
        actual_service=$(get_container_name "engine")
    fi
    
    local container_name
    container_name=$(get_container_name "$service")
    
    # Set up compose command with GPU detection
    set_compose_cmd
    
    # Check if already running
    if "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -qE "^${container_name}$|_[0-9a-f]+_${container_name}$|^[0-9a-f]+_${container_name}$"; then
        log_info "Service '$service' is already running."
        return 0
    fi
    
    # Remove existing containers (running or stopped)
    log_info "Cleaning up existing containers for $actual_service..."
    run_compose rm -f "$actual_service" 2>/dev/null || true
    
    # Remove hash-prefixed containers directly
    local hash_prefixed
    hash_prefixed=$("${DOCKER_BIN:-docker}" ps -a --format "{{.ID}} {{.Names}}" 2>/dev/null | grep -E "_${container_name}$|^[0-9a-f]+_${container_name}$" | awk '{print $1}') || true
    if [ -n "$hash_prefixed" ]; then
        echo "$hash_prefixed" | while read -r container_id; do
            "${DOCKER_BIN:-docker}" rm -f "$container_id" 2>/dev/null || true
        done
    fi
    
    # Remove exact match
    "${DOCKER_BIN:-docker}" rm -f "$container_name" 2>/dev/null || true
    
    log_info "Starting service: $service..."
    
    # Ensure .env exists for services that need it
    if [ ! -f "${SCRIPT_DIR}/.env" ] && { [ "$service" = "open-webui" ] || [ "$service" = "postgres" ] || [ "$service" = "pgadmin" ]; }; then
        if [ -f "${SCRIPT_DIR}/config/.env.example" ]; then
            log_warning ".env file not found. Copying from config/.env.example..."
            cp "${SCRIPT_DIR}/config/.env.example" "${SCRIPT_DIR}/.env"
            load_env_file "${SCRIPT_DIR}/.env"
        else
            log_error ".env file required for service '$service'"
            return 1
        fi
    fi
    
    # Generate pgAdmin config if needed
    if [ "$service" = "pgadmin" ]; then
        generate_pgadmin_config
    fi
    
    # Start the container
    if [ "$force_recreate" = "true" ]; then
        if run_compose up -d --force-recreate --no-deps "$actual_service"; then
            log_success "Successfully started service: $service (recreated)"
        else
            log_error "Failed to start service: $service"
            return 1
        fi
    else
        if run_compose up -d "$actual_service"; then
            log_success "Successfully started service: $service"
        else
            log_error "Failed to start service: $service"
            return 1
        fi
    fi
    
    # Wait briefly for initialization
    sleep 2
    
    # Verify it's running
    if "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -qE "^${container_name}$|_[0-9a-f]+_${container_name}$|^[0-9a-f]+_${container_name}$"; then
        log_info "Service '$service' is now running."
    else
        log_warning "Service '$service' may not have started correctly. Check logs with: $0 stack logs $service"
    fi
    return 0
}

# Stop a single container by service name
# Usage: container_stop <service>
container_stop() {
    local service="$1"
    
    # Resolve 'engine' alias
    local actual_service="$service"
    if [[ "$service" == "engine" ]]; then
        actual_service=$(get_container_name "engine")
    fi
    
    local container_name
    container_name=$(get_container_name "$service")
    
    # Check if running
    if ! "${DOCKER_BIN:-docker}" ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        log_info "Service '$service' is not running."
        return 0
    fi
    
    set_compose_cmd
    
    log_info "Stopping service: $service..."
    
    if run_compose stop "$actual_service"; then
        log_success "Successfully stopped service: $service"
        
        # Clean up pgAdmin config if stopping pgadmin
        if [ "$service" = "pgadmin" ] && [ -f "pgadmin-servers.json" ]; then
            rm -f pgadmin-servers.json
            log_info "Cleaned up pgAdmin configuration file"
        fi
        return 0
    else
        log_error "Failed to stop service: $service"
        return 1
    fi
}

# Restart a single container by service name
# Usage: container_restart <service> [force_recreate]
container_restart() {
    local service="$1"
    local force_recreate="${2:-false}"
    
    log_info "Restarting service: $service..."
    
    if container_stop "$service"; then
        if container_start "$service" "$force_recreate"; then
            log_success "Successfully restarted service: $service"
            return 0
        else
            log_error "Failed to start service during restart: $service"
            return 1
        fi
    else
        log_error "Failed to stop service during restart: $service"
        return 1
    fi
}

# Export functions for use in other modules
export -f container_start container_stop container_restart
