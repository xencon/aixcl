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
    docker rm -f $(docker ps -a -q) 2>/dev/null
}

# Function to delete all Docker images
delete_images() {
    print_message "Deleting all Docker images..." "yellow"
    docker rmi -f $(docker images -q) 2>/dev/null
}

# Function to delete all Docker networks
delete_networks() {
    print_message "Deleting all Docker networks..." "yellow"
    docker network prune -f
}

# Function to delete all Docker volumes
delete_volumes() {
    print_message "Deleting all Docker volumes..." "yellow"
    docker volume prune -f
}

# Execute deletion functions
delete_containers
delete_images
delete_networks
delete_volumes

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
