#!/usr/bin/env bash
# Configuration commands for AIXCL

function open_url_in_browser() {
    local url="$1"

    if command -v xdg-open &> /dev/null; then
        xdg-open "$url" 2>/dev/null &
    elif command -v open &> /dev/null; then
        open "$url" 2>/dev/null &
    else
        echo "   Could not detect default browser. Please open $url manually."
    fi
}

function config_cmd() {
    local action="${1:-}"
    case "$action" in
        engine)
            shift
            local subaction="${1:-}"
            if [ "$subaction" = "set" ]; then
                local engine="${2:-}"
                if [[ "$engine" != "ollama" && "$engine" != "vllm" && "$engine" != "llamacpp" ]]; then
                    echo "[ ] Error: Invalid engine '$engine'"
                    echo "Valid options: ollama, vllm, llamacpp"
                    return 1
                fi
                
                # Check if .env exists, if not use .env.example
                if [ ! -f "${SCRIPT_DIR}/.env" ] && [ -f "${SCRIPT_DIR}/.env.example" ]; then
                    cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
                fi
                
                if grep -q "^INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                    sed -i "s/^INFERENCE_ENGINE=.*/INFERENCE_ENGINE=$engine/" "${SCRIPT_DIR}/.env"
                else
                    echo "INFERENCE_ENGINE=$engine" >> "${SCRIPT_DIR}/.env"
                fi
                echo "[x] Inference engine set to: $engine"
                echo "Note: Stop and start the stack for the change to take effect."
            elif [ "$subaction" = "auto" ]; then
                # Check if .env exists, if not use .env.example
                if [ ! -f "${SCRIPT_DIR}/.env" ] && [ -f "${SCRIPT_DIR}/.env.example" ]; then
                    cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
                fi
                
                if has_nvidia_container_toolkit; then
                    echo "NVIDIA GPU and Container Toolkit detected. Setting engine to vLLM for optimized performance."
                    if grep -q "^INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                        sed -i "s/^INFERENCE_ENGINE=.*/INFERENCE_ENGINE=vllm/" "${SCRIPT_DIR}/.env"
                    else
                        echo "INFERENCE_ENGINE=vllm" >> "${SCRIPT_DIR}/.env"
                    fi
                elif is_arm64; then
                    echo "Apple Silicon / ARM64 detected. Setting engine to llama.cpp for optimized performance."
                    if grep -q "^INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                        sed -i "s/^INFERENCE_ENGINE=.*/INFERENCE_ENGINE=llamacpp/" "${SCRIPT_DIR}/.env"
                    else
                        echo "INFERENCE_ENGINE=llamacpp" >> "${SCRIPT_DIR}/.env"
                    fi
                else
                    echo "No dedicated GPU detected. Setting engine to Ollama."
                    if grep -q "^INFERENCE_ENGINE=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
                        sed -i "s/^INFERENCE_ENGINE=.*/INFERENCE_ENGINE=ollama/" "${SCRIPT_DIR}/.env"
                    else
                        echo "INFERENCE_ENGINE=ollama" >> "${SCRIPT_DIR}/.env"
                    fi
                fi
                echo "Note: Stop and start the stack for the change to take effect."
            else
                echo "Usage: ./aixcl config engine {set <engine>|auto}"
                echo "  set   - Manually set engine (ollama, vllm, llamacpp)"
                echo "  auto  - Auto-detect optimal engine based on hardware"
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown config action '$action'"
            echo "Usage: ./aixcl config {engine}"
            return 1
            ;;
    esac
}
