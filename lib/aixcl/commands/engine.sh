#!/usr/bin/env bash
# Engine management commands for AIXCL

function engine() {
    local action="${1:-}"
    
    if [ -z "$action" ]; then
        echo "Usage: ./aixcl engine {set <engine>|auto}"
        echo "  set   - Manually set engine (ollama, vllm, llamacpp)"
        echo "  auto  - Auto-detect optimal engine based on hardware"
        return 1
    fi
    
    if [ "$action" = "set" ]; then
        shift
        local engine="${1:-}"
        if [[ "$engine" != "ollama" && "$engine" != "vllm" && "$engine" != "llamacpp" ]]; then
            echo "[ ] Error: Invalid engine '$engine'"
            echo "Valid options: ollama, vllm, llamacpp"
            return 1
        fi
        
        # Check if .env exists, if not use .env.example
        if [ ! -f "${SCRIPT_DIR}/.env" ] && [ -f "${SCRIPT_DIR}/.env.example" ]; then
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
        fi
        
        if grep -qE "^[[:space:]]*#?INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
            sed -i "s/^[[:space:]]*#*INFERENCE_ENGINE=.*/INFERENCE_ENGINE=$engine/" "${SCRIPT_DIR}/.env"
        else
            echo "INFERENCE_ENGINE=$engine" >> "${SCRIPT_DIR}/.env"
        fi
        echo "[x] Inference engine set to: $engine"
        
        # Set vLLM-specific configuration when switching to vLLM
        if [ "$engine" = "vllm" ]; then
            # Set enforce-eager flag to true by default for vLLM (disable for better performance on bare metal)
            local enforce_eager="${VLLM_ENFORCE_EAGER:-true}"
            if grep -qE "^[[:space:]]*#?VLLM_ENFORCE_EAGER=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                sed -i "s/^[[:space:]]*#*VLLM_ENFORCE_EAGER=.*/VLLM_ENFORCE_EAGER=$enforce_eager/" "${SCRIPT_DIR}/.env"
            else
                echo "VLLM_ENFORCE_EAGER=$enforce_eager" >> "${SCRIPT_DIR}/.env"
            fi
            echo "[x] vLLM enforce-eager flag set to: $enforce_eager"
            echo "   Note: This improves compatibility with WSL2 and systems with limited GPU resources."
            
            # Set default model for vLLM to Qwen2.5-Coder-0.5B-Instruct
            local vllm_default_model="Qwen/Qwen2.5-Coder-0.5B-Instruct"
            if ! grep -qE "^[[:space:]]*#?INFERENCE_MODEL=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                echo "INFERENCE_MODEL=$vllm_default_model" >> "${SCRIPT_DIR}/.env"
                echo "[x] Default vLLM model set to: $vllm_default_model"
            fi
        fi
        
        # Clear opencode.json model when engine changes (model will need to be re-added)
        local opencode_config="${SCRIPT_DIR}/opencode.json"
        if [ -f "$opencode_config" ]; then
            if command -v jq >/dev/null 2>&1; then
                local temp_json
                temp_json=$(mktemp)
                # Clear the models dictionary - user will need to add a model for the new engine
                jq '.provider."aixcl-local".models = {} | .model = "aixcl-local/"' "$opencode_config" > "$temp_json" && mv "$temp_json" "$opencode_config"
                echo "   Note: Model configuration cleared in opencode.json. Please add a model for the new engine."
            else
                echo "   Note: Install jq to auto-clear model config in opencode.json"
            fi
        fi
        
        echo "Note: Stop and start the stack for the change to take effect."
    elif [ "$action" = "auto" ]; then
        # Check if .env exists, if not use .env.example
        if [ ! -f "${SCRIPT_DIR}/.env" ] && [ -f "${SCRIPT_DIR}/.env.example" ]; then
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
        fi
        
        if has_nvidia_container_toolkit; then
            echo "NVIDIA GPU and Container Toolkit detected. Setting engine to vLLM for optimized performance."
            if grep -qE "^[[:space:]]*#?INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                sed -i "s/^[[:space:]]*#*INFERENCE_ENGINE=.*/INFERENCE_ENGINE=vllm/" "${SCRIPT_DIR}/.env"
            else
                echo "INFERENCE_ENGINE=vllm" >> "${SCRIPT_DIR}/.env"
            fi
            
            # Set vLLM enforce-eager flag to true by default (disable for better performance on bare metal)
            local enforce_eager="${VLLM_ENFORCE_EAGER:-true}"
            if grep -qE "^[[:space:]]*#?VLLM_ENFORCE_EAGER=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                sed -i "s/^[[:space:]]*#*VLLM_ENFORCE_EAGER=.*/VLLM_ENFORCE_EAGER=$enforce_eager/" "${SCRIPT_DIR}/.env"
            else
                echo "VLLM_ENFORCE_EAGER=$enforce_eager" >> "${SCRIPT_DIR}/.env"
            fi
            echo "[x] vLLM enforce-eager flag set to: $enforce_eager"
            echo "   Note: This improves compatibility with WSL2 and systems with limited GPU resources."
        elif is_arm64; then
            echo "Apple Silicon / ARM64 detected. Setting engine to llama.cpp for optimized performance."
            if grep -qE "^[[:space:]]*#?INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                sed -i "s/^[[:space:]]*#*INFERENCE_ENGINE=.*/INFERENCE_ENGINE=llamacpp/" "${SCRIPT_DIR}/.env"
            else
                echo "INFERENCE_ENGINE=llamacpp" >> "${SCRIPT_DIR}/.env"
            fi
        else
            echo "No dedicated GPU detected. Setting engine to Ollama."
            if grep -qE "^[[:space:]]*#?INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                sed -i "s/^[[:space:]]*#*INFERENCE_ENGINE=.*/INFERENCE_ENGINE=ollama/" "${SCRIPT_DIR}/.env"
            else
                echo "INFERENCE_ENGINE=ollama" >> "${SCRIPT_DIR}/.env"
            fi
        fi
        
        # Clear opencode.json model when engine changes (model will need to be re-added)
        local opencode_config="${SCRIPT_DIR}/opencode.json"
        if [ -f "$opencode_config" ]; then
            if command -v jq >/dev/null 2>&1; then
                local temp_json
                temp_json=$(mktemp)
                # Clear the models dictionary - user will need to add a model for the new engine
                jq '.provider."aixcl-local".models = {} | .model = "aixcl-local/"' "$opencode_config" > "$temp_json" && mv "$temp_json" "$opencode_config"
                echo "   Note: Model configuration cleared in opencode.json. Please add a model for the new engine."
            else
                echo "   Note: Install jq to auto-clear model config in opencode.json"
            fi
        fi
        
        echo "Note: Stop and start the stack for the change to take effect."
    else
        echo "Usage: ./aixcl engine {set <engine>|auto}"
        echo "  set   - Manually set engine (ollama, vllm, llamacpp)"
        echo "  auto  - Auto-detect optimal engine based on hardware"
        return 1
    fi
}
