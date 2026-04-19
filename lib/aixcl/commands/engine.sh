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
        # Configure Open WebUI Ollama API setting based on engine
        # When using Ollama: ENABLE_OLLAMA_API=true (for full Ollama feature support)
        # When using llamacpp or vLLM: ENABLE_OLLAMA_API=false (use OpenAI-compatible API)
        if [ "$engine" = "ollama" ]; then
            local enable_ollama="true"
            echo "[x] Open WebUI Ollama API enabled (for full Ollama feature support)"
        else
            local enable_ollama="false"
            echo "[x] Open WebUI Ollama API disabled (using OpenAI-compatible API)"
        fi
        
        if grep -qE "^[[:space:]]*#?ENABLE_OLLAMA_API=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
            sed -i "s/^[[:space:]]*#*ENABLE_OLLAMA_API=.*/ENABLE_OLLAMA_API=$enable_ollama/" "${SCRIPT_DIR}/.env"
        else
            echo "ENABLE_OLLAMA_API=$enable_ollama" >> "${SCRIPT_DIR}/.env"
        fi
        
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

            # Set OpenCode token limit to prevent vLLM token limit errors
            local opencode_token_limit="8192"
            if grep -qE "^[[:space:]]*#?OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                sed -i "s/^[[:space:]]*#*OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=.*/OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=$opencode_token_limit/" "${SCRIPT_DIR}/.env"
            else
                echo "OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=$opencode_token_limit" >> "${SCRIPT_DIR}/.env"
            fi
            echo "[x] OpenCode output token limit set to: $opencode_token_limit"
            echo "   This prevents OpenCode from exceeding vLLM token limits."
            
            # Export for current session
            export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX="$opencode_token_limit"
            
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
        
        echo "Note: Stop and start the stack for the change to take effect:"
        echo "  ./aixcl stack stop && ./aixcl stack start"
    elif [ "$action" = "auto" ]; then
        # Check if .env exists, if not use .env.example
        if [ ! -f "${SCRIPT_DIR}/.env" ] && [ -f "${SCRIPT_DIR}/.env.example" ]; then
            cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
        fi
        
        # Determine engine based on hardware
        if has_nvidia_container_toolkit; then
            local engine="vllm"
        elif is_arm64; then
            local engine="llamacpp"
        else
            local engine="ollama"
        fi
        
        echo "Auto-detected engine: $engine"
        
        # Configure Open WebUI Ollama API setting based on auto-detected engine
        if [ "$engine" = "ollama" ]; then
            local enable_ollama="true"
        else
            local enable_ollama="false"
        fi
        
        if grep -qE "^[[:space:]]*#?ENABLE_OLLAMA_API=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
            sed -i "s/^[[:space:]]*#*ENABLE_OLLAMA_API=.*/ENABLE_OLLAMA_API=$enable_ollama/" "${SCRIPT_DIR}/.env"
        else
            echo "ENABLE_OLLAMA_API=$enable_ollama" >> "${SCRIPT_DIR}/.env"
        fi
        
        if [ "$engine" = "ollama" ]; then
            echo "[x] Open WebUI Ollama API enabled (for full Ollama feature support)"
        else
            echo "[x] Open WebUI Ollama API disabled (using OpenAI-compatible API)"
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
        
        echo "Note: Stop and start the stack for the change to take effect:"
        echo "  ./aixcl stack stop \u0026\u0026 ./aixcl stack start"
    else
        echo "Usage: ./aixcl engine {set <engine>|auto}"
        echo "  set   - Manually set engine (ollama, vllm, llamacpp)"
        echo "  auto  - Auto-detect optimal engine based on hardware"
        return 1
    fi
}
