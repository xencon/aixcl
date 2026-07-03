#!/usr/bin/env bash
# Model management commands for AIXCL

# Check if a model is already installed/downloaded for the current engine
is_model_installed() {
    local model="$1"
    local engine="$2"
    local container="$3"

    case "$engine" in
        ollama)
            # Ollama list shows models. Match the name exactly, or with the
            # default tag appended when the name carries none.
            # (pin-waiver: ollama MODEL tags are not container images)
            local model_with_tag="$model"
            [[ ! "$model" =~ : ]] && model_with_tag="${model}:latest"  # pin-waiver: ollama model tag
            "${DOCKER_BIN:-docker}" exec "$container" ollama list 2>/dev/null | awk '{print $1}' | grep -qE "^${model_with_tag}$"
            return $?
            ;;
    esac
    return 1
}

function add() {
    if [ -z "$1" ]; then
        echo "Error: Model name is required"
        echo "Usage: $0 models add <model-name> [<model-name> ...]"
        return 1
    fi

    local input_model="$1"
    local model="$input_model"
    local engine="${INFERENCE_ENGINE:-ollama}"
    local container
    container=$(get_engine_container "$engine")

    # Parse Hugging Face URI if present
    local is_hf=false
    if [[ "$input_model" =~ ^hf\.co/ ]] || [[ "$input_model" =~ ^huggingface\.co/ ]]; then
        is_hf=true
        # Strip the prefix
        model=$(echo "$input_model" | sed -E 's|^(hf\.co/\|huggingface\.co/)||')
    fi

    # Validate model name format (allowing slashes for HF models)
    if [[ ! "$model" =~ ^[A-Za-z0-9._/-]+(:[A-Za-z0-9._-]+)?$ ]]; then
        echo -e "\xe2\x9d\x8c Invalid model name format: '$model'"
        echo "   Model names should contain only alphanumeric characters, dots, underscores, dashes, and slashes"
        return 1
    fi

    # Check if model already exists
    if is_model_installed "$model" "$engine" "$container"; then
        echo "[x] Model '$model' is already installed for $engine."
    else
        echo "Adding model: $model (Engine: $engine)"

        # Download logic based on engine
        if [ "$engine" = "ollama" ]; then
            if [ -z "$container" ]; then
                echo "Error: $engine container is not running. Please start the services first."
                return 1
            fi
            if [ "$is_hf" = true ]; then
                # Handle explicit HF pull for Ollama
                echo "   Pulling Hugging Face model into Ollama..."
                if "${DOCKER_BIN:-docker}" exec "$container" ollama pull "$input_model"; then
                    echo "[x] Successfully added HF model to Ollama: $model"
                else
                    echo "   Direct HF pull failed. Attempting run fallback..."
                    if "${DOCKER_BIN:-docker}" exec "$container" ollama run "$input_model" "/exit" >/dev/null 2>&1; then
                        echo "[x] Successfully added HF model to Ollama: $model"
                    else
                        echo "[ ] Failed to add HF model to Ollama: $model"
                        return 1
                    fi
                fi
            else
                # Standard Ollama pull
                if "${DOCKER_BIN:-docker}" exec "$container" ollama pull "$model"; then
                    echo "[x] Successfully added model: $model"
                else
                    echo "[ ] Failed to add model: $model"
                    return 1
                fi
            fi
        fi
    fi

    # Sync opencode.json if it exists
    local opencode_config="${SCRIPT_DIR}/opencode.json"
    if [ -f "$opencode_config" ]; then
        local opencode_model_key="$model"
        echo "   Synchronizing $opencode_config with model: $opencode_model_key"
        if command -v jq >/dev/null 2>&1; then
            local temp_json
            temp_json=$(mktemp)
            # 1. Clear the models dictionary and add only the current model
            # 2. Update the active model pointer
            jq --arg model "$opencode_model_key" '.provider."aixcl-local".models = {($model): {"name": $model}} | .model = "aixcl-local/\($model)"' "$opencode_config" > "$temp_json" && mv "$temp_json" "$opencode_config"
            echo "[x] Successfully updated opencode.json"
        else
            # Simple sed fallback if jq is missing (only updates active model pointer)
            sed -i "s|\"model\": \"aixcl-local/.*\"|\"model\": \"aixcl-local/$opencode_model_key\"|" "$opencode_config"
            echo "[x] Successfully updated opencode.json (via sed - model pointer only)"
            echo "   Note: Install jq to fully sync model dictionary"
        fi
    fi

    return 0
}

function remove() {
    if [ -z "$1" ]; then
        echo "Error: Model name is required"
        echo "Usage: $0 models remove <model-name> [<model-name> ...]"
        return 1
    fi

    local input_model="$1"
    local model="$input_model"

    # Parse Hugging Face URI if present (strip prefix for remove)
    if [[ "$input_model" =~ ^hf\.co/ ]] || [[ "$input_model" =~ ^huggingface\.co/ ]]; then
        model="$input_model"
    fi

    # Validate model name format
    if [[ ! "$model" =~ ^[A-Za-z0-9._/-]+(:[A-Za-z0-9._-]+)?$ ]]; then
        echo -e "\xe2\x9d\x8c Invalid model name format: '$model'"
        return 1
    fi

    echo "Removing model: $model"

    local engine="${INFERENCE_ENGINE:-ollama}"
    local container
    container=$(get_engine_container "$engine")

    if [ "$engine" = "ollama" ]; then
        if [ -z "$container" ]; then
            echo "Error: $engine container is not running. Please start the services first."
            return 1
        fi
        if "${DOCKER_BIN:-docker}" exec "$container" ollama rm "$model"; then
            echo "[x] Successfully removed model: $model"
        else
            echo "[ ] Failed to remove model: $model"
            return 1
        fi
    else
        echo "   Model management for $engine is not fully automated yet."
    fi
}

function list() {
    local engine="${INFERENCE_ENGINE:-ollama}"
    echo "Listing installed models for $engine..."

    local container
    container=$(get_engine_container "$engine")

    if [ -z "$container" ]; then
        echo "Error: $engine container is not running. Please start the services first."
        return 1
    fi

    if [ "$engine" = "ollama" ]; then
        "${DOCKER_BIN:-docker}" exec "$container" ollama list
    else
        echo "   Model listing for $engine is not fully supported yet."
    fi
}

function models() {
    if [[ $# -lt 1 ]]; then
        echo "Error: Models action is required"
        echo "Usage: $0 models {add|remove|list} [<model-name> ...]"
        echo "Examples:"
        echo "  $0 models add qwen2.5-coder:0.5b"
        echo "  $0 models remove qwen2.5-coder:0.5b qwen2.5-coder:1.5b"
        echo "  $0 models list"
        return 1
    fi

    local action="$1"
    shift

    local status=0

    case "$action" in
        add)
            if [[ $# -lt 1 ]]; then
                echo "Error: At least one model name is required for add"
                echo "Usage: $0 models add <model-name> [<model-name> ...]"
                return 1
            fi
            for model in "$@"; do
                if ! add "$model"; then
                    status=1
                fi
            done
            ;;
        remove)
            if [[ $# -lt 1 ]]; then
                echo "Error: At least one model name is required for remove"
                echo "Usage: $0 models remove <model-name> [<model-name> ...]"
                return 1
            fi
            for model in "$@"; do
                if ! remove "$model"; then
                    status=1
                fi
            done
            ;;
        list)
            if [[ $# -gt 0 ]]; then
                echo "Error: Unknown argument '$1'"
                echo "Usage: $0 models {add|remove|list} [<model-name> ...]"
                return 1
            fi
            list
            ;;
        *)
            echo "Error: Unknown models action '$action'"
            echo "Usage: $0 models {add|remove|list} [<model-name> ...]"
            return 1
            ;;
    esac

    return $status
}
