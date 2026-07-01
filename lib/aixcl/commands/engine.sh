#!/usr/bin/env bash
# Engine management commands for AIXCL

_clear_opencode_model() {
    local opencode_config="${SCRIPT_DIR}/opencode.json"
    if [ -f "$opencode_config" ]; then
        if command -v jq >/dev/null 2>&1; then
            local temp_json
            temp_json=$(mktemp)
            jq '.provider."aixcl-local".models = {} | .model = "aixcl-local/"' "$opencode_config" > "$temp_json" && mv "$temp_json" "$opencode_config"
            echo "   Note: Model configuration cleared in opencode.json. Please add a model for the new engine."
        else
            echo "   Note: Install jq to auto-clear model config in opencode.json"
        fi
    fi
}

# Write the engine selection and Open WebUI API setting to .env
_write_engine_env() {
    local engine="$1"

    # Check if .env exists, if not use .env.example
    if [ ! -f "${SCRIPT_DIR}/.env" ] && [ -f "${SCRIPT_DIR}/.env.example" ]; then
        cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
    fi
    [ -f "${SCRIPT_DIR}/.env" ] && chmod 600 "${SCRIPT_DIR}/.env"

    if grep -qE "^[[:space:]]*#?INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
        sed -i "s/^[[:space:]]*#*INFERENCE_ENGINE=.*/INFERENCE_ENGINE=$engine/" "${SCRIPT_DIR}/.env"
    else
        echo "INFERENCE_ENGINE=$engine" >> "${SCRIPT_DIR}/.env"
    fi
    echo "[x] Inference engine set to: $engine"

    # Ollama is the only supported engine; enable the Ollama API in Open WebUI
    if grep -qE "^[[:space:]]*#?ENABLE_OLLAMA_API=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
        sed -i "s/^[[:space:]]*#*ENABLE_OLLAMA_API=.*/ENABLE_OLLAMA_API=true/" "${SCRIPT_DIR}/.env"
    else
        echo "ENABLE_OLLAMA_API=true" >> "${SCRIPT_DIR}/.env"
    fi
    echo "[x] Open WebUI Ollama API enabled (for full Ollama feature support)"
}

function engine() {
    local action="${1:-}"

    if [ -z "$action" ]; then
        echo "Usage: ./aixcl engine {set <engine>|auto}"
        echo "  set   - Manually set engine (ollama)"
        echo "  auto  - Auto-detect optimal engine based on hardware"
        return 1
    fi

    if [ "$action" = "set" ]; then
        shift
        local engine="${1:-}"
        if [[ "$engine" != "ollama" ]]; then
            echo "[ ] Error: Invalid engine '$engine'"
            echo "Valid options: ollama"
            return 1
        fi

        _write_engine_env "$engine"
        _clear_opencode_model

        echo "Note: Restart the stack for the change to take effect:"
        echo "  ./aixcl stack restart"
    elif [ "$action" = "auto" ]; then
        # Ollama is the only supported engine
        local engine="ollama"
        echo "Auto-detected engine: $engine"

        _write_engine_env "$engine"
        _clear_opencode_model

        echo "Note: Restart the stack for the change to take effect:"
        echo "  ./aixcl stack restart"
    else
        echo "Usage: ./aixcl engine {set <engine>|auto}"
        echo "  set   - Manually set engine (ollama)"
        echo "  auto  - Auto-detect optimal engine based on hardware"
        return 1
    fi
}
