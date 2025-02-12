#!/usr/bin/env bash

#!/bin/bash

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

# Function to delete all Docker containers
delete_containers() {
    print_message "Deleting all Docker containers..." "yellow"
    docker ps -aq | xargs -r docker rm -f 2>/dev/null
}

# Function to delete all Docker images
delete_images() {
    print_message "Deleting all Docker images..." "yellow"
    docker images -q | xargs -r docker rmi -f 2>/dev/null
}

# Function to delete all Docker networks
delete_networks() {
    print_message "Deleting all Docker networks..." "yellow"
    docker network ls -q | xargs -r docker network rm 2>/dev/null
}

# Function to delete all Docker volumes
delete_volumes() {
    print_message "Deleting all Docker volumes..." "yellow"
    # Stop all containers first to release volume locks
    docker ps -aq | xargs -r docker stop 2>/dev/null
    # Remove containers again to ensure all are gone
    docker ps -aq | xargs -r docker rm -f 2>/dev/null
    # Remove all volumes forcefully
    docker volume ls -q | xargs -r docker volume rm -f 2>/dev/null
    # Final cleanup with system prune
    docker system prune -a --volumes -f >/dev/null 2>&1
}

# Execute deletion functions in the correct order
delete_containers
delete_networks
delete_volumes
delete_images

# Verification
print_message "Verifying deletion of Docker artifacts..." "blue"

# Check for Docker containers
if [ -z "$(docker ps -a -q)" ]; then
    print_message "No Docker containers found." "green"
else
    print_message "Docker containers still exist." "red"
fi

# Check for Docker images
if [ -z "$(docker images -q)" ]; then
    print_message "No Docker images found." "green"
else
    print_message "Docker images still exist." "red"
fi

# Check for user-defined Docker networks
user_defined_networks=$(docker network ls --filter "type=custom" -q)
if [ -z "$user_defined_networks" ]; then
    print_message "No user-defined Docker networks found." "green"
else
    print_message "User-defined Docker networks still exist." "red"
fi

# Check for Docker volumes
if [ -z "$(docker volume ls -q)" ]; then
    print_message "No Docker volumes found." "green"
else
    print_message "Docker volumes still exist." "red"
fi
