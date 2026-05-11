#!/usr/bin/env bash
# Model management commands for AIXCL

# Check if a model is already installed/downloaded for the current engine
is_model_installed() {
    local model="$1"
    local engine="$2"
    local container="$3"

    case "$engine" in
        ollama)
            # Ollama list shows models. We need to match the name exactly, or with :latest if missing tag
            local model_with_tag="$model"
            [[ ! "$model" =~ : ]] && model_with_tag="${model}:latest"
            "${DOCKER_BIN:-docker}" exec "$container" ollama list 2>/dev/null | awk '{print $1}' | grep -qE "^${model_with_tag}$"
            return $?
            ;;
        vllm)
            # vLLM uses HF cache. Check for models--org--repo directory
            local hf_path
            hf_path="models--$(echo "$model" | sed 's/\//--/g')"
            "${DOCKER_BIN:-docker}" exec "$container" ls "/root/.cache/huggingface/hub/$hf_path" >/dev/null 2>&1
            return $?
            ;;
        llamacpp)
            # llama.cpp uses a flat models directory. Check if file exists in volume on host
            local llamacpp_volume="services_llamacpp-data"
            local volume_path
            volume_path=$(${DOCKER_BIN:-docker} volume inspect -f '{{ .Mountpoint }}' "$llamacpp_volume" 2>/dev/null || echo "")
            if [ -n "$volume_path" ] && [ -d "$volume_path" ]; then
                local model_filename="$model"
                [[ "$model" =~ /([^/]+)$ ]] && model_filename="${BASH_REMATCH[1]}"
                [ -f "${volume_path}/${model_filename}" ] && return 0
            fi
            # Fallback: check via container if volume path not available
            if [ -n "$container" ]; then
                local model_filename="$model"
                [[ "$model" =~ /([^/]+)$ ]] && model_filename="${BASH_REMATCH[1]}"
                "${DOCKER_BIN:-docker}" exec "$container" ls "/models/${model_filename}" >/dev/null 2>&1
                return $?
            fi
            return 1
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
        
        # Still update config for vLLM/llama.cpp as they are single-model engines
        if [[ "$engine" == "vllm" || "$engine" == "llamacpp" ]]; then
            echo "   Updating configuration to use existing model..."
        fi
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
        elif [ "$engine" = "vllm" ]; then
            if [ -z "$container" ]; then
                echo "Error: $engine container is not running. Please start the services first."
                return 1
            fi
            echo "   Downloading model from Hugging Face for vLLM..."
            # vLLM container doesn't have hf CLI, download on host instead
            # Host cache is shared with container via ~/.cache/huggingface
            if command -v hf >/dev/null 2>&1; then
                # Download to host cache (vLLM container will pick it up)
                if hf download "$model"; then
                    echo "[x] Successfully downloaded model: $model"
                    echo "   vLLM will load the model on next restart"
                else
                    echo "[ ] Failed to download model: $model"
                    return 1
                fi
            else
                echo "[ ] 'hf' command not found on host"
                echo "   Install huggingface-hub: pip install huggingface-hub[cli]"
                return 1
            fi
        elif [ "$engine" = "llamacpp" ]; then
            # For llama.cpp, download to volume first, then the container will pick it up
            # Format: org/repo/model.gguf
            if [[ "$model" =~ ^([^/]+/[^/]+)/(.+\.gguf)$ ]]; then
                local repo="${BASH_REMATCH[1]}"
                local filename="${BASH_REMATCH[2]}"
                echo "   Downloading $filename from $repo..."
                
                # For llama.cpp, we need to download the GGUF file to the Docker volume
                # Since Docker volumes may not be directly accessible on the host filesystem,
                # we download to a temp location and use docker run to copy to the volume
                local llamacpp_volume="services_llamacpp-data"
                local temp_dir="/tmp/aixcl-downloads-$$"
                local downloaded_file="${temp_dir}/${filename}"
                
                # Create temp directory
                mkdir -p "$temp_dir"
                
                echo "   Downloading to temporary location..."
                
                # Download using available method
                local download_success=false
                
                # Try hf first
                if command -v hf >/dev/null 2>&1; then
                    if hf download "$repo" "$filename" --local-dir "$temp_dir"; then
                        download_success=true
                    fi
                fi
                
                # Fall back to Python script
                if [ "$download_success" = false ] && [ -f "${SCRIPT_DIR}/scripts/download-hf-model.py" ] && python3 -c "import huggingface_hub" 2>/dev/null; then
                    echo "   Attempting download with Python fallback..."
                    if python3 "${SCRIPT_DIR}/scripts/download-hf-model.py" "$repo" "$filename" --local-dir "$temp_dir" > /dev/null 2>&1; then
                        download_success=true
                        echo "   [x] Python download successful"
                    else
                        echo "   [ ] Python download failed"
                    fi
                fi
                
                # Last resort: curl
                if [ "$download_success" = false ]; then
                    echo "   Using curl to download..."
                    if curl -L "https://huggingface.co/$repo/resolve/main/$filename" -o "$downloaded_file" --progress-bar 2>/dev/null; then
                        download_success=true
                    fi
                fi
                
                if [ "$download_success" = false ]; then
                    rm -rf "$temp_dir"
                    echo "[ ] Failed to download model: $model"
                    echo "   Install huggingface-hub: pip install huggingface-hub"
                    return 1
                fi
                
                # Now copy to Docker volume using docker run
                echo "   Copying to Docker volume..."
                if ${DOCKER_BIN:-docker} run --rm \
                    -v "${llamacpp_volume}:/models" \
                    -v "${temp_dir}:/source:ro" \
                    alpine:latest \
                    cp "/source/${filename}" "/models/"; then
                    
                    echo "[x] Successfully downloaded and copied model: $filename"
                    rm -rf "$temp_dir"
                else
                    echo "[ ] Failed to copy model to Docker volume"
                    rm -rf "$temp_dir"
                    return 1
                fi
            else
                echo "[ ] Invalid model format for llama.cpp. Expected: username/repo/model.gguf"
                echo "   Example: bartowski/Qwen2.5-Coder-0.5B-Instruct-GGUF/Qwen2.5-Coder-0.5B-Instruct-Q4_K_M.gguf"
                return 1
            fi
        fi
    fi

    # Update configuration for vLLM and llama.cpp
    if [[ "$engine" == "vllm" || "$engine" == "llamacpp" ]]; then
        local compose_file="${SERVICES_DIR:-services}/docker-compose.yml"
        if [ ! -f "$compose_file" ]; then
             echo "[ ] Error: $compose_file not found."
             return 1
        fi
        
        echo "   Updating $engine configuration in $compose_file to use model: $model"
        if [[ "$engine" == "vllm" ]]; then
            # Build vLLM command with optional enforce-eager flag
            # Update VLLM_MODEL in .env file
            local env_file="${SCRIPT_DIR}/.env"
            if [ -f "$env_file" ]; then
                if grep -qE "^[[:space:]]*#?VLLM_MODEL=" "$env_file"; then
                    sed -i "s/^[[:space:]]*#*VLLM_MODEL=.*/VLLM_MODEL=$model/" "$env_file"
                else
                    echo "VLLM_MODEL=$model" >> "$env_file"
                fi
            fi
            echo "   Updated VLLM_MODEL in .env to: $model"
        elif [[ "$engine" == "llamacpp" ]]; then
            # Update llamacpp model via environment variable
            local model_filename="$model"
            [[ "$model" =~ /([^/]+)$ ]] && model_filename="${BASH_REMATCH[1]}"
            
            # Update the environment variable in .env file
            local env_file="${SCRIPT_DIR}/.env"
            if [ -f "$env_file" ]; then
                if grep -qE "^[[:space:]]*#?INFERENCE_MODEL=" "$env_file"; then
                    # Update existing variable (including commented ones)
                    sed -i "s/^[[:space:]]*#*INFERENCE_MODEL=.*/INFERENCE_MODEL=$model_filename/" "$env_file"
                else
                    # Add new variable
                    echo "INFERENCE_MODEL=$model_filename" >> "$env_file"
                fi
                echo "[x] Configuration updated in .env. Restarting llamacpp container..."
                # Restart the container to pick up the new model
                ${DOCKER_BIN:-docker} restart llamacpp 2>/dev/null || true
            else
                echo "   .env file not found. Please set INFERENCE_MODEL=$model_filename manually."
            fi
        fi
        echo "[x] Configuration updated. Please restart the stack to apply changes: $0 stack restart"
    fi

    # Sync opencode.json if it exists
    local opencode_config="${SCRIPT_DIR}/opencode.json"
    if [ -f "$opencode_config" ]; then
        # For llama.cpp, extract just the filename for the model key
        local opencode_model_key="$model"
        if [[ "$engine" == "llamacpp" ]]; then
            [[ "$model" =~ /([^/]+)$ ]] && opencode_model_key="${BASH_REMATCH[1]}"
        fi
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
    elif [[ "$engine" == "vllm" ]]; then
        if [ -z "$container" ]; then
            echo "Error: $engine container is not running. Please start the services first."
            return 1
        fi
        # vLLM cache is usually in /root/.cache/huggingface/hub/models--USER--REPO
        local cache_dir
        cache_dir="models--${model//\//--}"
        echo "   Attempting to remove model from vLLM cache..."
        if "${DOCKER_BIN:-docker}" exec "$container" rm -rf "/root/.cache/huggingface/hub/$cache_dir"; then
            echo "[x] Successfully removed model files for: $model"
        else
            echo "[ ] Failed to remove model files for: $model"
            return 1
        fi
    elif [[ "$engine" == "llamacpp" ]]; then
        if [ -z "$container" ]; then
            echo "Error: $engine container is not running. Please start the services first."
            return 1
        fi
        local model_filename="$model"
        [[ "$model" =~ /([^/]+)$ ]] && model_filename="${BASH_REMATCH[1]}"
        if "${DOCKER_BIN:-docker}" exec "$container" rm -f "/models/$model_filename"; then
            echo "[x] Successfully removed model file: $model_filename"
        else
            echo "[ ] Failed to remove model file: $model_filename"
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
    elif [ "$engine" = "vllm" ]; then
        # Show currently loaded model via API
        local url
        url="http://127.0.0.1:11434/v1/models"
        echo "Currently loaded model (API):"
        curl -s "$url" | grep -oP '"id":\s*"\K[^"]+' | sort -u || echo "   Could not retrieve loaded model via API."
        
        # Show cached models on disk
        echo ""
        echo "Cached models on disk:"
        "${DOCKER_BIN:-docker}" exec "$container" find /root/.cache/huggingface/hub -maxdepth 1 -name "models--*" 2>/dev/null | sed 's|.*/models--||;s|--|/|g' | sort -u || echo "   No cached models found."
    elif [ "$engine" = "llamacpp" ]; then
        # Show currently loaded model via API (if container is running)
        if [ -n "$container" ]; then
            local url
            url="http://127.0.0.1:11434/v1/models"
            echo "Currently loaded model (API):"
            curl -s "$url" | grep -oP '"id":\s*"\K[^"]+' | sort -u || echo "   Could not retrieve loaded model via API."
            echo ""
        fi
        
        # Show files in /models volume (check directly via volume mount)
        echo "Available GGUF files in volume:"
        local llamacpp_volume="services_llamacpp-data"
        local volume_path
        volume_path=$(${DOCKER_BIN:-docker} volume inspect -f '{{ .Mountpoint }}' "$llamacpp_volume" 2>/dev/null || echo "")
        if [ -n "$volume_path" ] && [ -d "$volume_path" ]; then
            find "$volume_path" -name "*.gguf" -exec basename {} \; 2>/dev/null | sort -u || echo "   No GGUF files found in volume."
        elif [ -n "$container" ]; then
            "${DOCKER_BIN:-docker}" exec "$container" find /models -name "*.gguf" -printf "%f\n" 2>/dev/null | sort -u || echo "   No GGUF files found in volume."
        else
            echo "   Cannot access volume. Start llamacpp service to view available models."
        fi
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
