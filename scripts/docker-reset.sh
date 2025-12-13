#!/usr/bin/env bash

# ⚠️  DESTRUCTIVE SCRIPT WARNING ⚠️
# This script will DELETE ALL Docker containers, images, networks, and volumes.
# This includes Ollama models stored in volumes!
# Use with extreme caution!
#
# Usage: ./scripts/docker-reset.sh
# For testing: This ensures a completely clean Docker environment

# Function to print messages in color
print_message() {
    local message="$1"
    local color="$2"
    case $color in
        "green") echo -e "\e[32m$message\e[0m" ;;
        "red") echo -e "\e[31m$message\e[0m" ;;
        "yellow") echo -e "\e[33m$message\e[0m" ;;
        "blue") echo -e "\e[34m$message\e[0m" ;;
        *) echo "$message" ;;
    esac
}

# Show warning and require confirmation
echo "=" | head -c 80; echo
print_message "⚠️  DESTRUCTIVE OPERATION WARNING ⚠️" "red"
echo "=" | head -c 80; echo
echo ""
print_message "This script will DELETE:" "yellow"
echo "  - ALL Docker containers (including running ones)"
echo "  - ALL Docker images"
echo "  - ALL Docker networks"
echo "  - ALL Docker volumes (including Ollama models!)"
echo ""
print_message "This action CANNOT be undone!" "red"
echo ""
print_message "Your Ollama models will be permanently deleted!" "red"
echo ""
read -p "Type 'DELETE EVERYTHING' to confirm: " confirm

if [ "$confirm" != "DELETE EVERYTHING" ]; then
    print_message "Operation cancelled." "green"
    exit 0
fi

# Get script directory to find services
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES_DIR="${SCRIPT_DIR}/services"

# Function to bring down Docker Compose stack gracefully
bring_down_stack() {
    print_message "Bringing down Docker Compose stack..." "yellow"
    
    if [ ! -f "${SERVICES_DIR}/docker-compose.yml" ]; then
        print_message "  ℹ️  docker-compose.yml not found, skipping stack shutdown" "blue"
        return 0
    fi
    
    cd "${SERVICES_DIR}" || return 1
    
    # Try to bring down the stack gracefully
    if command -v docker-compose >/dev/null 2>&1; then
        print_message "  Stopping services with docker-compose..." "blue"
        docker-compose down --remove-orphans 2>/dev/null || true
        
        # Also try with volumes flag to ensure volumes are released
        docker-compose down --remove-orphans -v 2>/dev/null || true
    fi
    
    # Also try docker compose (newer syntax)
    if docker compose version >/dev/null 2>&1; then
        print_message "  Stopping services with docker compose..." "blue"
        docker compose down --remove-orphans 2>/dev/null || true
        docker compose down --remove-orphans -v 2>/dev/null || true
    fi
    
    cd "${SCRIPT_DIR}" || true
    
    print_message "  ✅ Stack shutdown completed" "green"
}

# Function to delete all Docker containers
delete_containers() {
    print_message "Deleting all Docker containers..." "yellow"
    local containers=$(docker ps -aq 2>/dev/null)
    if [ -n "$containers" ]; then
        echo "$containers" | xargs -r docker stop 2>/dev/null || true
        echo "$containers" | xargs -r docker rm -f 2>/dev/null || true
        print_message "  ✅ Stopped and removed all containers" "green"
    else
        print_message "  ℹ️  No containers to remove" "blue"
    fi
}

# Function to delete all Docker images
delete_images() {
    print_message "Deleting all Docker images..." "yellow"
    local images=$(docker images -q 2>/dev/null)
    if [ -n "$images" ]; then
        echo "$images" | xargs -r docker rmi -f 2>/dev/null || true
        print_message "  ✅ Removed all images" "green"
    else
        print_message "  ℹ️  No images to remove" "blue"
    fi
}

# Function to delete all Docker networks (except default ones)
delete_networks() {
    print_message "Deleting all user-defined Docker networks..." "yellow"
    # Get all networks except default ones (bridge, host, none)
    local networks=$(docker network ls -q --filter "type=custom" 2>/dev/null)
    if [ -n "$networks" ]; then
        echo "$networks" | xargs -r docker network rm 2>/dev/null || true
        print_message "  ✅ Removed user-defined networks" "green"
    else
        print_message "  ℹ️  No user-defined networks to remove" "blue"
    fi
}

# Function to delete all Docker volumes
delete_volumes() {
    print_message "Deleting all Docker volumes..." "yellow"
    
    # First, ensure all containers are stopped and removed
    local containers=$(docker ps -aq 2>/dev/null)
    if [ -n "$containers" ]; then
        print_message "  Stopping containers to release volume locks..." "blue"
        echo "$containers" | xargs -r docker stop 2>/dev/null || true
        echo "$containers" | xargs -r docker rm -f 2>/dev/null || true
    fi
    
    # Remove all volumes
    local volumes=$(docker volume ls -q 2>/dev/null)
    if [ -n "$volumes" ]; then
        print_message "  Removing volumes..." "blue"
        echo "$volumes" | xargs -r docker volume rm -f 2>/dev/null || true
        print_message "  ✅ Removed volumes" "green"
    else
        print_message "  ℹ️  No volumes to remove" "blue"
    fi
    
    # Final cleanup with system prune (removes any remaining unused resources)
    print_message "  Running final system prune..." "blue"
    docker system prune -a --volumes -f >/dev/null 2>&1 || true
    print_message "  ✅ System prune completed" "green"
}

# Execute deletion functions in the correct order
print_message "Starting reset process..." "yellow"
echo ""

# First, gracefully bring down the Docker Compose stack
bring_down_stack
echo ""

delete_containers
echo ""

delete_networks
echo ""

delete_volumes
echo ""

delete_images
echo ""

# Verification
print_message "Verifying deletion of Docker artifacts..." "blue"
echo ""

# Check for Docker containers
containers_remaining=$(docker ps -a -q 2>/dev/null)
if [ -z "$containers_remaining" ]; then
    print_message "✅ No Docker containers found." "green"
else
    print_message "⚠️  Docker containers still exist:" "red"
    docker ps -a --format "  - {{.Names}} ({{.Status}})" 2>/dev/null || true
fi

# Check for Docker images
images_remaining=$(docker images -q 2>/dev/null)
if [ -z "$images_remaining" ]; then
    print_message "✅ No Docker images found." "green"
else
    print_message "⚠️  Docker images still exist:" "red"
    docker images --format "  - {{.Repository}}:{{.Tag}}" 2>/dev/null | head -10 || true
    local count=$(docker images -q | wc -l)
    if [ "$count" -gt 10 ]; then
        print_message "  ... and $((count - 10)) more" "yellow"
    fi
fi

# Check for user-defined Docker networks
user_defined_networks=$(docker network ls --filter "type=custom" -q 2>/dev/null)
if [ -z "$user_defined_networks" ]; then
    print_message "✅ No user-defined Docker networks found." "green"
else
    print_message "⚠️  User-defined Docker networks still exist:" "red"
    docker network ls --filter "type=custom" --format "  - {{.Name}}" 2>/dev/null || true
fi

# Check for Docker volumes
volumes_remaining=$(docker volume ls -q 2>/dev/null)
if [ -z "$volumes_remaining" ]; then
    print_message "✅ No Docker volumes found." "green"
else
    print_message "⚠️  Docker volumes still exist:" "red"
    docker volume ls --format "  - {{.Name}}" 2>/dev/null || true
fi

echo ""
print_message "=" "blue" | head -c 80; echo
if [ -z "$containers_remaining" ] && [ -z "$images_remaining" ] && [ -z "$user_defined_networks" ] && [ -z "$volumes_remaining" ]; then
    print_message "✅ Docker environment completely cleaned!" "green"
else
    print_message "⚠️  Some Docker resources may still exist (see above)" "yellow"
    print_message "   You may need to manually remove them or restart Docker daemon" "yellow"
fi
print_message "=" "blue" | head -c 80; echo
