#!/usr/bin/env bash
# Stack management commands (start, stop, restart, status, logs, clean)

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_utils.sh"
source "${SCRIPT_DIR}/lib/color.sh"
source "${SCRIPT_DIR}/lib/pgadmin_utils.sh"

CONTAINER_NAME="open-webui"

# Stack start command
stack_start() {
    echo "Starting Docker Compose deployment..."
    
    # Check for .env file and create from .env.example if missing
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        if [ -f "${SCRIPT_DIR}/.env.example" ]; then
            print_warning ".env file not found. Copying from .env.example..."
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
            print_success "Created .env file from .env.example"
            # Reload environment variables after creating .env file
            load_env_file "${SCRIPT_DIR}/.env"
        else
            print_error "Neither .env nor .env.example file found"
            echo "   Please create a .env file with the required configuration"
            exit 1
        fi
    else
        # Load .env file to get PROFILE if set
        load_env_file "${SCRIPT_DIR}/.env"
    fi
    
    # Generate pgAdmin configuration with populated values
    generate_pgadmin_config
    
    # Set up compose command with GPU detection
    set_compose_cmd
    
    if is_container_running "$CONTAINER_NAME"; then
        print_warning "Services are already running. Use 'stop' first if you want to restart."
        exit 1
    fi
    
    echo "Pulling latest images..."
    "${COMPOSE_CMD[@]}" pull
    
    echo "Building LLM-Council service..."
    "${COMPOSE_CMD[@]}" build llm-council
    
    echo "Starting services..."
    "${COMPOSE_CMD[@]}" up -d
    
    echo "Waiting for services to be ready..."
    for i in {1..30}; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/version 2>/dev/null | grep -q "200" && \
           curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null | grep -q "200" && \
           curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null | grep -q "200" && \
           docker exec postgres pg_isready -U webui >/dev/null 2>&1; then
            echo "All services are up and running!"
            stack_status
            return 0
        fi
        echo "Waiting for services to become available... ($i/30)"
        sleep 2
    done
    
    print_error "Services did not start properly within timeout period"
    stack_status
    exit 1
}

# Stack stop command
stack_stop() {
    echo "Stopping Docker Compose deployment..."
    
    # Set up compose command with GPU detection
    set_compose_cmd
    
    if ! are_services_running "$CONTAINER_NAME|ollama|postgres|pgadmin|llm-council|watchtower|prometheus|grafana|cadvisor|node-exporter|postgres-exporter|nvidia-gpu-exporter"; then
        echo "Services are not running."
        return 0
    fi
    
    echo "Stopping services gracefully..."
    "${COMPOSE_CMD[@]}" down --remove-orphans
    
    echo "Waiting for containers to stop..."
    for i in {1..15}; do
        if ! are_services_running "$CONTAINER_NAME|ollama|postgres|pgadmin|llm-council|watchtower|prometheus|grafana|cadvisor|node-exporter|postgres-exporter|nvidia-gpu-exporter"; then
            echo "All services stopped successfully."
            return 0
        fi
        echo "Waiting for services to stop... ($i/15)"
        sleep 2
    done
    
    print_warning "Services did not stop gracefully. Forcing shutdown..."
    "${COMPOSE_CMD[@]}" down --remove-orphans -v
    docker ps -q | xargs -r docker stop 2>/dev/null || true
    
    echo "All services have been stopped."
    
    # Clean up pgAdmin configuration file for security
    if [ -f "${SCRIPT_DIR}/pgadmin-servers.json" ]; then
        rm -f "${SCRIPT_DIR}/pgadmin-servers.json"
        print_clean "Cleaned up pgAdmin configuration file"
    fi
}

# Stack restart command
stack_restart() {
    # Load .env file to check for PROFILE variable
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        load_env_file "${SCRIPT_DIR}/.env"
        
        # Check if PROFILE is set in .env
        if [ -n "${PROFILE:-}" ]; then
            echo "ℹ️  Using profile from .env file: $PROFILE"
            echo "Restarting services..."
            stack_stop
            sleep 5
            stack_start
            return 0
        fi
    fi
    
    echo "❌ Error: Profile is required for restart command"
    echo ""
    echo "Usage: aixcl stack restart [--profile <profile>]"
    echo "       aixcl stack restart -p <profile>"
    echo ""
    echo "Note: You can set PROFILE=<profile> in .env file to use a default profile"
    echo ""
    echo "Available profiles: usr, dev, ops, sys"
    echo ""
    echo "Examples:"
    echo "  aixcl stack restart --profile sys"
    echo "  aixcl stack restart -p dev"
    echo ""
    echo "Note: Use 'aixcl stack start --profile <profile>' for initial startup"
    exit 1
}

# Stack logs command
stack_logs() {
    # Set up compose command with GPU detection
    set_compose_cmd
    
    if [ $# -eq 0 ]; then
        echo "Fetching logs for all services..."
        "${COMPOSE_CMD[@]}" logs --tail=0 --follow
    else
        local container="$1"
        local tail_count="${2:-50}"  # Default to 50 lines if not specified
        
        # Validate tail_count
        if [[ ! "$tail_count" =~ ^[0-9]+$ ]] || [[ "$tail_count" -lt 1 ]] || [[ "$tail_count" -gt 10000 ]]; then
            print_error "tail count must be a number between 1 and 10000"
            return 1
        fi
        
        # Validate container name
        if is_valid_service "$container"; then
            local container_name=$(get_container_name "$container")
            echo "Fetching logs for $container_name..."
            docker logs "$container_name" --tail="$tail_count" --follow
        else
            print_error "Unknown container '$container'"
            echo "Available containers: ${ALL_SERVICES[*]}"
            return 1
        fi
    fi
}

# Stack clean command
stack_clean() {
    echo "Cleaning up Docker resources..."
    echo ""
    print_warning "⚠️  WARNING: This will remove unused Docker resources."
    echo "   This includes stopped containers, unused images, and unused volumes."
    echo "   IMPORTANT: Ollama models are stored in Docker volumes."
    echo "   If Ollama container is not running, its volume may be considered 'unused' and deleted!"
    echo ""
    
    # Check if Ollama volume exists and container is not running
    if docker volume ls --format "{{.Name}}" | grep -q "^ollama$"; then
        if ! docker ps --format "{{.Names}}" | grep -q "^ollama$"; then
            print_error "⚠️  WARNING: Ollama container is not running but volume exists!"
            echo "   The Ollama volume contains your downloaded models."
            echo "   Running 'docker volume prune' may delete it and all your models!"
            echo ""
            read -p "Do you want to continue? This may delete your Ollama models! (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                echo "Cleanup cancelled."
                return 0
            fi
        fi
    fi
    
    # Set up compose command with GPU detection
    set_compose_cmd
    
    echo "Stopping all containers..."
    "${COMPOSE_CMD[@]}" down
    
    # Remove postgres container and associated volumes specifically
    if docker ps -a --format "{{.Names}}" | grep -q "^postgres$"; then
        echo "Removing PostgreSQL container..."
        docker rm -f postgres 2>/dev/null || true
    fi
    
    # Remove postgres-related volumes
    echo "Removing PostgreSQL volumes..."
    docker volume ls --format "{{.Name}}" | grep -i postgres | while read -r volume; do
        if [ -n "$volume" ]; then
            echo "  Removing volume: $volume"
            docker volume rm "$volume" 2>/dev/null || true
        fi
    done
    
    echo "Removing stopped containers..."
    docker container prune -f
    
    echo "Removing unused images..."
    docker image prune -a -f
    
    # Protect Ollama volume from being pruned
    echo "Removing unused volumes (protecting Ollama volume)..."
    # List volumes before prune
    local volumes_before=$(docker volume ls -q)
    
    # Run prune
    docker volume prune -f
    
    # Check if Ollama volume was deleted
    if echo "$volumes_before" | grep -q "^ollama$"; then
        if ! docker volume ls -q | grep -q "^ollama$"; then
            print_error "⚠️  WARNING: Ollama volume was deleted! All models are lost."
            echo "   You will need to re-download models with: ./aixcl models add <model-name>"
        else
            echo "✅ Ollama volume preserved"
        fi
    fi
    
    # Clean up pgAdmin configuration file for security
    if [ -f "${SCRIPT_DIR}/pgadmin-servers.json" ]; then
        rm -f "${SCRIPT_DIR}/pgadmin-servers.json"
        print_clean "Cleaned up pgAdmin configuration file"
    fi
    
    echo "Clean up complete."
}

# Stack status command
stack_status() {
    echo "Checking services status..."
    echo ""
    
    # Core Application Services
    echo "Core"
    if is_container_running "ollama"; then
        print_success "Ollama"
    else
        print_error "Ollama"
    fi
    
    if is_container_running "$CONTAINER_NAME"; then
        print_success "Open WebUI"
    else
        print_error "Open WebUI"
    fi

    if is_container_running "llm-council"; then
        print_success "LLM-Council"
    else
        print_error "LLM-Council"
    fi

    # Database Services
    echo ""
    echo "Data"
    if is_container_running "postgres"; then
        print_success "PostgreSQL"
    else
        print_error "PostgreSQL"
    fi

    if is_container_running "pgadmin"; then
        print_success "pgAdmin"
    else
        print_error "pgAdmin"
    fi

    # Monitoring Services
    echo ""
    echo "Monitoring"
    if is_container_running "prometheus"; then
        print_success "Prometheus"
    else
        print_error "Prometheus"
    fi

    if is_container_running "grafana"; then
        print_success "Grafana"
    else
        print_error "Grafana"
    fi

    if is_container_running "cadvisor"; then
        print_success "cAdvisor"
    else
        print_error "cAdvisor"
    fi

    if is_container_running "node-exporter"; then
        print_success "Node Exporter"
    else
        print_error "Node Exporter"
    fi

    if is_container_running "postgres-exporter"; then
        print_success "Postgres Exporter"
    else
        print_error "Postgres Exporter"
    fi

    if is_container_running "nvidia-gpu-exporter"; then
        print_success "NVIDIA GPU Exporter"
    else
        print_warning "NVIDIA GPU Exporter (expected on non-GPU systems)"
    fi

    # Logging Services
    echo ""
    echo "Logging"
    if is_container_running "loki"; then
        print_success "Loki"
    else
        print_error "Loki"
    fi

    if is_container_running "promtail"; then
        print_success "Promtail"
    else
        print_error "Promtail"
    fi

    # Utility Services
    echo ""
    echo "Utility"
    if is_container_running "watchtower"; then
        print_success "Watchtower"
    else
        print_error "Watchtower"
    fi
    
    echo ""
    echo "Service Health"
    echo ""
    
    # Core Application Services
    echo "Core"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/version 2>/dev/null | grep -q "200"; then
        print_success "Ollama"
    else
        print_error "Ollama"
    fi
    
    WEBUI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
    if [ "$WEBUI_STATUS" = "200" ]; then
        print_success "Open WebUI"
    else
        print_error "Open WebUI"
        echo "    Checking container logs (last 3 lines):"
        timeout 2 docker logs "$CONTAINER_NAME" --tail 3 2>/dev/null || echo "    (Logs unavailable or timeout)"
    fi

    COUNCIL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "000")
    if [ "$COUNCIL_STATUS" = "200" ]; then
        print_success "LLM-Council"
    else
        print_error "LLM-Council"
        echo "    Checking LLM-Council logs (last 3 lines):"
        timeout 2 docker logs llm-council --tail 3 2>/dev/null || echo "    (Logs unavailable or container may not be running)"
    fi

    # Database Services
    echo ""
    echo "Data"
    if timeout 2 docker exec postgres pg_isready -U "${POSTGRES_USER:-webui}" >/dev/null 2>&1; then
        print_success "PostgreSQL"
    else
        print_error "PostgreSQL"
        echo "    Checking PostgreSQL logs (last 3 lines):"
        timeout 2 docker logs postgres --tail 3 2>/dev/null || echo "    (Logs unavailable or timeout)"
    fi

    PGADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5050 2>/dev/null || echo "000")
    if [ "$PGADMIN_STATUS" = "200" ] || [ "$PGADMIN_STATUS" = "302" ]; then
        print_success "pgAdmin"
    else
        print_error "pgAdmin"
        echo "    Checking pgAdmin logs (last 3 lines):"
        timeout 2 docker logs pgadmin --tail 3 2>/dev/null || echo "    (Logs unavailable or timeout)"
    fi

    # Monitoring Services
    echo ""
    echo "Monitoring"
    PROMETHEUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy 2>/dev/null || echo "000")
    if [ "$PROMETHEUS_STATUS" = "200" ]; then
        print_success "Prometheus"
    else
        print_error "Prometheus"
    fi

    GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null || echo "000")
    if [ "$GRAFANA_STATUS" = "200" ]; then
        print_success "Grafana"
    else
        print_error "Grafana"
    fi

    CADVISOR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/metrics 2>/dev/null)
    if [ "$CADVISOR_STATUS" = "200" ]; then
        print_success "cAdvisor"
    else
        print_error "cAdvisor"
    fi

    NODE_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9100/metrics 2>/dev/null)
    if [ "$NODE_EXPORTER_STATUS" = "200" ]; then
        print_success "Node Exporter"
    else
        print_error "Node Exporter"
    fi

    POSTGRES_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9187/metrics 2>/dev/null)
    if [ "$POSTGRES_EXPORTER_STATUS" = "200" ]; then
        print_success "Postgres Exporter"
    else
        print_error "Postgres Exporter"
    fi

    if is_container_running "nvidia-gpu-exporter"; then
        NVIDIA_GPU_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9400/metrics 2>/dev/null)
        if [ "$NVIDIA_GPU_EXPORTER_STATUS" = "200" ]; then
            print_success "NVIDIA GPU Exporter"
        else
            print_error "NVIDIA GPU Exporter"
        fi
    else
        print_warning "NVIDIA GPU Exporter (expected on non-GPU systems)"
    fi

    # Logging Services
    echo ""
    echo "Logging"
    if is_container_running "loki"; then
        LOKI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready 2>/dev/null || echo "000")
        if [ "$LOKI_STATUS" = "200" ]; then
            print_success "Loki"
        elif [ "$LOKI_STATUS" = "503" ]; then
            print_warning "Loki (starting up)"
        elif [ "$LOKI_STATUS" = "000" ]; then
            print_error "Loki"
            echo "    Checking Loki logs (last 3 lines):"
            timeout 2 docker logs loki --tail 3 2>/dev/null || echo "    (Logs unavailable or timeout)"
        else
            print_error "Loki"
            echo "    Checking Loki logs (last 3 lines):"
            timeout 2 docker logs loki --tail 3 2>/dev/null || echo "    (Logs unavailable or timeout)"
        fi
    else
        print_error "Loki"
    fi

    if is_container_running "promtail"; then
        if docker exec promtail wget --no-verbose --tries=1 --spider http://localhost:9080/ready 2>/dev/null; then
            print_success "Promtail"
        else
            print_error "Promtail"
        fi
    else
        print_error "Promtail"
    fi

    # Utility Services
    echo ""
    echo "Utility"
    if is_container_running "watchtower"; then
        print_success "Watchtower"
    else
        print_error "Watchtower"
    fi
    echo ""
}
