#!/usr/bin/env bash
# Model management commands (add, remove, list)

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_utils.sh"
source "${SCRIPT_DIR}/lib/color.sh"

# Models add command
models_add() {
    if [ -z "$1" ]; then
        print_error "Model name is required"
        echo "Usage: aixcl models add <model-name> [<model-name> ...]"
        echo "Example: aixcl models add starcoder2:latest"
        echo "Example: aixcl models add starcoder2:latest nomic-embed-text:latest"
        return 1
    fi

    local status=0
    for model in "$@"; do
        # Validate model name format
        if [[ ! "$model" =~ ^[A-Za-z0-9._-]+(:[A-Za-z0-9._-]+)?$ ]]; then
            print_error "Invalid model name format: '$model'"
            echo "   Model names should contain only alphanumeric characters, dots, underscores, dashes"
            echo "   Optional tag format: model:tag (e.g., starcoder2:latest)"
            status=1
            continue
        fi

        echo "Adding model: $model"
        
        if ! is_container_running "ollama"; then
            print_error "Ollama container is not running. Please start the services first."
            return 1
        fi

        if docker exec ollama ollama pull "$model"; then
            print_success "Successfully added model: $model"
        else
            print_error "Failed to add model: $model"
            echo "Debug: Check if the model name is correct and the Ollama container is running."
            status=1
        fi
    done

    return $status
}

# Models remove command
models_remove() {
    if [ -z "$1" ]; then
        print_error "Model name is required"
        echo "Usage: aixcl models remove <model-name> [<model-name> ...]"
        echo "Example: aixcl models remove starcoder2:latest"
        echo "Example: aixcl models remove starcoder2:latest nomic-embed-text:latest"
        return 1
    fi

    local status=0
    for model in "$@"; do
        # Validate model name format
        if [[ ! "$model" =~ ^[A-Za-z0-9._-]+(:[A-Za-z0-9._-]+)?$ ]]; then
            print_error "Invalid model name format: '$model'"
            echo "   Model names should contain only alphanumeric characters, dots, underscores, dashes"
            echo "   Optional tag format: model:tag (e.g., starcoder2:latest)"
            status=1
            continue
        fi

        echo "Removing model: $model"
        
        if ! is_container_running "ollama"; then
            print_error "Ollama container is not running. Please start the services first."
            return 1
        fi

        if docker exec ollama ollama rm "$model"; then
            print_success "Successfully removed model: $model"
        else
            print_error "Failed to remove model: $model"
            echo "Debug: Check if the model name is correct and the Ollama container is running."
            status=1
        fi
    done

    return $status
}

# Models list command
models_list() {
    echo "Listing installed models..."
    
    if ! is_container_running "ollama"; then
        print_error "Ollama container is not running. Please start the services first."
        return 1
    fi

    docker exec ollama ollama list
}
