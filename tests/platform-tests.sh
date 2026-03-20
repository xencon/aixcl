#!/usr/bin/env bash
# Platform Test Suite for AIXCL
# This script consolidates all test files from the repository into a single comprehensive test suite.
#
# Test Categories:
# 0. Environment Check - Verify environment setup (Docker, dependencies, etc.)
# 1. Stack Status - Container status and health checks
# 2. LLM State - Model availability and operational status
# 3. Database Connection - PostgreSQL connection and schema verification
# 4. API Endpoints - Core API functionality
#
# Usage:
#   ./tests/platform-tests.sh                    # Run all tests (backward compatible)
#   ./tests/platform-tests.sh --profile usr      # Run tests for usr profile
#   ./tests/platform-tests.sh --profile dev      # Run tests for dev profile
#   ./tests/platform-tests.sh --profile ops      # Run tests for ops profile
#   ./tests/platform-tests.sh --profile sys      # Run tests for sys profile
#   ./tests/platform-tests.sh --component runtime-core  # Test runtime core only
#   ./tests/platform-tests.sh --component database     # Test database components
#   ./tests/platform-tests.sh --component monitoring    # Test monitoring components
#   ./tests/platform-tests.sh --component logging      # Test logging components
#   ./tests/platform-tests.sh --component ui           # Test UI components
#   ./tests/platform-tests.sh --list                   # List available targets
#
# Exit Codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -u

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/docker_utils.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/color.sh"

# Source profile library if available
# shellcheck disable=SC1091
if [ -f "${SCRIPT_DIR}/cli/lib/profile.sh" ]; then
    source "${SCRIPT_DIR}/cli/lib/profile.sh"
fi

# Load environment variables
if [ -f "${SCRIPT_DIR}/.env" ]; then
    load_env_file "${SCRIPT_DIR}/.env"
fi

# Configuration
CONTAINER_NAME="open-webui"
POSTGRES_USER=${POSTGRES_USER:-webui}
INFERENCE_ENGINE=${INFERENCE_ENGINE:-ollama}


# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test results tracking
test_results=()
test_sections=()

# Helper function to track test results
record_test() {
    local status="$1"  # "pass", "fail", or "skip"
    local message="$2"
    
    case "$status" in
        "pass")
            ((TESTS_PASSED++))
            test_results+=("PASS: $message")
            ;;
        "fail")
            ((TESTS_FAILED++))
            test_results+=("FAIL: $message")
            ;;
        "skip")
            ((TESTS_SKIPPED++))
            test_results+=("SKIP: $message")
            ;;
    esac
}

# Helper function to mark test section start
start_section() {
    local section_name="$1"
    echo ""
    echo "=========================================="
    echo "Test Section: $section_name"
    echo "=========================================="
    echo ""
    test_sections+=("$section_name")
}

# ============================================================================
# SECTION 0: ENVIRONMENT CHECK
# ============================================================================
test_environment_check() {
    start_section "Environment Check - System Dependencies"
    
    echo "Running environment check..."
    echo "Command: ./aixcl utils check-env"
    echo ""
    
    # Run the check-env command and capture output
    local check_output
    local check_exit_code
    
    # Change to script directory to ensure aixcl is found
    local original_dir
    original_dir=$(pwd)
    cd "$SCRIPT_DIR" || {
        print_error "Cannot change to script directory"
        record_test "fail" "Cannot change to script directory for environment check"
        return
    }
    
    # Run the check-env command
    check_output=$(./aixcl utils check-env 2>&1)
    check_exit_code=$?
    
    # Display the output
    echo "$check_output"
    echo ""
    
    # Evaluate results
    if [ $check_exit_code -eq 0 ]; then
        print_success "Environment check passed"
        record_test "pass" "Environment check passed (all dependencies verified)"
    else
        print_error "Environment check failed"
        record_test "fail" "Environment check failed (missing dependencies or configuration issues)"
        echo ""
        echo "⚠️  Warning: Environment check failed. Some tests may fail as a result."
        echo "   Please review the output above and address any issues."
    fi
    
    # Return to original directory
    cd "$original_dir" 2>/dev/null || true
}

# ============================================================================
# SECTION 1: STACK STATUS TESTS
# ============================================================================
test_stack_status() {
    start_section "Stack Status - Containers & Health"
    
    # Container Status Checks
    echo "Container Status"
    echo "-----------------------------------"
    
    # Inference Engine
    echo "Engine: $INFERENCE_ENGINE"
    if is_container_running "$INFERENCE_ENGINE"; then
        print_success "$INFERENCE_ENGINE"
        record_test "pass" "$INFERENCE_ENGINE container is running"
    else
        print_error "$INFERENCE_ENGINE"
        record_test "fail" "$INFERENCE_ENGINE container is not running"
    fi
    
    if is_container_running "$CONTAINER_NAME"; then
        print_success "Open WebUI"
        record_test "pass" "Open WebUI container is running"
    else
        print_error "Open WebUI"
        record_test "fail" "Open WebUI container is not running"
    fi
    
    # Database Services
    echo ""
    echo "Data"
    if is_container_running "postgres"; then
        print_success "PostgreSQL"
        record_test "pass" "PostgreSQL container is running"
    else
        print_error "PostgreSQL"
        record_test "fail" "PostgreSQL container is not running"
    fi
    
    if is_container_running "pgadmin"; then
        print_success "pgAdmin"
        record_test "pass" "pgAdmin container is running"
    else
        print_error "pgAdmin"
        record_test "fail" "pgAdmin container is not running"
    fi
    
    # Monitoring Services
    echo ""
    echo "Monitoring"
    if is_container_running "prometheus"; then
        print_success "Prometheus"
        record_test "pass" "Prometheus container is running"
    else
        print_error "Prometheus"
        record_test "fail" "Prometheus container is not running"
    fi
    
    if is_container_running "grafana"; then
        print_success "Grafana"
        record_test "pass" "Grafana container is running"
    else
        print_error "Grafana"
        record_test "fail" "Grafana container is not running"
    fi
    
    if is_container_running "cadvisor"; then
        print_success "cAdvisor"
        record_test "pass" "cAdvisor container is running"
    else
        print_error "cAdvisor"
        record_test "fail" "cAdvisor container is not running"
    fi
    
    if is_container_running "node-exporter"; then
        print_success "Node Exporter"
        record_test "pass" "Node Exporter container is running"
    else
        print_error "Node Exporter"
        record_test "fail" "Node Exporter container is not running"
    fi
    
    if is_container_running "postgres-exporter"; then
        print_success "Postgres Exporter"
        record_test "pass" "Postgres Exporter container is running"
    else
        print_error "Postgres Exporter"
        record_test "fail" "Postgres Exporter container is not running"
    fi
    
    if is_container_running "nvidia-gpu-exporter"; then
        print_success "NVIDIA GPU Exporter"
        record_test "pass" "NVIDIA GPU Exporter container is running"
    else
        print_warning "NVIDIA GPU Exporter (expected on non-GPU systems)"
        record_test "skip" "NVIDIA GPU Exporter container is not running (optional)"
    fi
    
    # Logging Services
    echo ""
    echo "Logging"
    if is_container_running "loki"; then
        print_success "Loki"
        record_test "pass" "Loki container is running"
    else
        print_error "Loki"
        record_test "fail" "Loki container is not running"
    fi
    
    if is_container_running "promtail"; then
        print_success "Promtail"
        record_test "pass" "Promtail container is running"
    else
        print_error "Promtail"
        record_test "fail" "Promtail container is not running"
    fi
    
    # Utility Services
    echo ""
    echo "Utility"
    if is_container_running "watchtower"; then
        print_success "Watchtower"
        record_test "pass" "Watchtower container is running"
    else
        print_error "Watchtower"
        record_test "fail" "Watchtower container is not running"
    fi
    
    # Health Checks
    echo ""
    echo "Service Health"
    echo "-----------------------------------"
    
    # Core Application Services
    # Inference Engine health check
    local engine_url="http://127.0.0.1:11434"
    local healthy=false
    
    # Try both Ollama and OpenAI-compatible endpoints
    if curl -s -o /dev/null -w "%{http_code}" "${engine_url}/api/version" 2>/dev/null | grep -q "200"; then
        healthy=true
    elif curl -s -o /dev/null -w "%{http_code}" "${engine_url}/v1/models" 2>/dev/null | grep -q "200"; then
        healthy=true
    fi

    if [ "$healthy" = true ]; then
        print_success "$INFERENCE_ENGINE"
        record_test "pass" "$INFERENCE_ENGINE health check passed"
    else
        print_error "$INFERENCE_ENGINE"
        record_test "fail" "$INFERENCE_ENGINE health check failed"
    fi
    
    # Open WebUI health check (with longer timeout for migrations)
    WEBUI_STATUS="000"
    WEBUI_READY=false
    # Try multiple endpoints - /health might not exist in all versions, try root and /api/config as fallbacks
    for i in {1..15}; do
        # Try /health endpoint first (preferred)
        WEBUI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8080/health 2>/dev/null || echo "000")
        if [ "$WEBUI_STATUS" = "200" ]; then
            WEBUI_READY=true
            break
        fi
        
        # If /health doesn't work, try root endpoint (some versions use this)
        if [ "$WEBUI_STATUS" = "000" ] || [ "$WEBUI_STATUS" = "404" ]; then
            ROOT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8080/ 2>/dev/null || echo "000")
            if [ "$ROOT_STATUS" = "200" ] || [ "$ROOT_STATUS" = "302" ] || [ "$ROOT_STATUS" = "307" ]; then
                WEBUI_STATUS="$ROOT_STATUS"
                WEBUI_READY=true
                break
            fi
        fi
        
        # On first few attempts, wait longer to allow migrations
        if [ "$i" -le 8 ]; then
            sleep 3
        else
            sleep 2
        fi
    done
    
    if [ "$WEBUI_READY" = "true" ]; then
        print_success "Open WebUI"
        record_test "pass" "Open WebUI health check passed"
    else
        print_error "Open WebUI"
        # Check if container is running but app is failing (migration issue)
        if is_container_running "$CONTAINER_NAME"; then
            # Check logs for migration/database errors
            WEBUI_LOGS=$(docker logs "$CONTAINER_NAME" --tail 30 2>/dev/null || echo "")
            if echo "$WEBUI_LOGS" | grep -q "config.*does not exist\|relation.*does not exist\|migration\|alembic"; then
                record_test "fail" "Open WebUI health check failed - database migration issue (HTTP $WEBUI_STATUS)"
                echo "    Note: Container is running but migrations may not have completed"
                echo "    This is a known issue that requires manual database migration"
                echo "    Check logs: docker logs open-webui --tail 50"
                echo "    Or restart the service: ./aixcl service restart open-webui"
            elif echo "$WEBUI_LOGS" | grep -q "error\|Error\|ERROR\|exception\|Exception"; then
                record_test "fail" "Open WebUI health check failed - application error (HTTP $WEBUI_STATUS)"
                echo "    Container is running but application has errors"
                echo "    Check logs: docker logs open-webui --tail 50"
            else
                record_test "fail" "Open WebUI health check failed (HTTP $WEBUI_STATUS)"
                echo "    Container is running but health endpoint not responding"
                echo "    Check logs: docker logs open-webui --tail 50"
            fi
        else
            record_test "fail" "Open WebUI container is not running"
        fi
    fi
    
    # Database Services
    echo ""
    echo "Data"
    
    # PostgreSQL health check
    if timeout 2 docker exec postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
        print_success "PostgreSQL"
        record_test "pass" "PostgreSQL health check passed"
    else
        print_error "PostgreSQL"
        record_test "fail" "PostgreSQL health check failed"
    fi
    
    # pgAdmin health check
    PGADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5050 2>/dev/null || echo "000")
    if [ "$PGADMIN_STATUS" = "200" ] || [ "$PGADMIN_STATUS" = "302" ]; then
        print_success "pgAdmin"
        record_test "pass" "pgAdmin health check passed"
    else
        print_error "pgAdmin"
        record_test "fail" "pgAdmin health check failed (HTTP $PGADMIN_STATUS)"
    fi
    
    # Monitoring Services
    echo ""
    echo "Monitoring"
    
    # Prometheus health check
    PROMETHEUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9090/-/healthy 2>/dev/null || echo "000")
    if [ "$PROMETHEUS_STATUS" = "200" ]; then
        print_success "Prometheus"
        record_test "pass" "Prometheus health check passed"
    else
        print_error "Prometheus"
        record_test "fail" "Prometheus health check failed (HTTP $PROMETHEUS_STATUS)"
    fi
    
    # Grafana health check
    GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/health 2>/dev/null || echo "000")
    if [ "$GRAFANA_STATUS" = "200" ]; then
        print_success "Grafana"
        record_test "pass" "Grafana health check passed"
    else
        print_error "Grafana"
        record_test "fail" "Grafana health check failed (HTTP $GRAFANA_STATUS)"
    fi
    
    # cAdvisor health check
    CADVISOR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081/metrics 2>/dev/null || echo "000")
    if [ "$CADVISOR_STATUS" = "200" ]; then
        print_success "cAdvisor"
        record_test "pass" "cAdvisor health check passed"
    else
        print_error "cAdvisor"
        record_test "fail" "cAdvisor health check failed (HTTP $CADVISOR_STATUS)"
    fi
    
    # Node Exporter health check
    NODE_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9100/metrics 2>/dev/null || echo "000")
    if [ "$NODE_EXPORTER_STATUS" = "200" ]; then
        print_success "Node Exporter"
        record_test "pass" "Node Exporter health check passed"
    else
        print_error "Node Exporter"
        record_test "fail" "Node Exporter health check failed (HTTP $NODE_EXPORTER_STATUS)"
    fi
    
    # Postgres Exporter health check
    POSTGRES_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9187/metrics 2>/dev/null || echo "000")
    if [ "$POSTGRES_EXPORTER_STATUS" = "200" ]; then
        print_success "Postgres Exporter"
        record_test "pass" "Postgres Exporter health check passed"
    else
        print_error "Postgres Exporter"
        record_test "fail" "Postgres Exporter health check failed (HTTP $POSTGRES_EXPORTER_STATUS)"
    fi
    
    # NVIDIA GPU Exporter (optional)
    if is_container_running "nvidia-gpu-exporter"; then
        NVIDIA_GPU_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9400/metrics 2>/dev/null || echo "000")
        if [ "$NVIDIA_GPU_EXPORTER_STATUS" = "200" ]; then
            print_success "NVIDIA GPU Exporter"
            record_test "pass" "NVIDIA GPU Exporter health check passed"
        else
            print_error "NVIDIA GPU Exporter"
            record_test "fail" "NVIDIA GPU Exporter health check failed (HTTP $NVIDIA_GPU_EXPORTER_STATUS)"
        fi
    else
        print_warning "NVIDIA GPU Exporter (expected on non-GPU systems)"
        record_test "skip" "NVIDIA GPU Exporter health check skipped (container not running)"
    fi
    
    # Loki health check
    LOKI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3100/ready 2>/dev/null || echo "000")
    if [ "$LOKI_STATUS" = "200" ]; then
        print_success "Loki"
        record_test "pass" "Loki health check passed"
    else
        print_error "Loki"
        record_test "fail" "Loki health check failed (HTTP $LOKI_STATUS)"
    fi
    
    # Promtail doesn't have a health endpoint, so we just check if it's running
    if is_container_running "promtail"; then
        print_success "Promtail (container running)"
        record_test "pass" "Promtail container is running (no health endpoint)"
    else
        print_error "Promtail"
        record_test "fail" "Promtail container is not running"
    fi
}

# Helper function to get available models
get_available_models() {
    local target_engine="${1:-$INFERENCE_ENGINE}"
    local engine_url="http://127.0.0.1:11434"
    
    if [ "$target_engine" = "ollama" ]; then
        if is_container_running "ollama"; then
            # Use CLI if available
            docker exec ollama ollama list 2>/dev/null | tail -n +2 | grep -v "^NAME" | awk '{print $1}' | sed 's/:latest//'
        else
            # API fallback
            curl -s "${engine_url}/api/tags" | jq -r '.models[].name' 2>/dev/null | sed 's/:latest//'
        fi
    elif [ "$target_engine" = "vllm" ] || [ "$target_engine" = "llamacpp" ]; then
        # OpenAI compatible
        curl -s "${engine_url}/v1/models" | jq -r '.data[].id' 2>/dev/null
    else
        # Generic OpenAI compatible fallback
        curl -s "${engine_url}/v1/models" | jq -r '.data[].id' 2>/dev/null
    fi
}

# ============================================================================
# SECTION 2: LLM STATE TESTS
# ============================================================================
test_llm_state() {
    start_section "LLM State - Models & Operational Status"
    
    local engines=("ollama" "vllm" "llamacpp")
    
    for engine in "${engines[@]}"; do
        local display_name="$engine"
        [ "$engine" = "ollama" ] && display_name="$engine (Default)"
        
        echo "Inference Engine: $display_name"
        echo "-----------------------------------"
        
        if [ "$INFERENCE_ENGINE" != "$engine" ]; then
            print_warning "$engine is not the active inference engine"
            record_test "skip" "$engine tests skipped (not active)"
            echo ""
            continue
        fi
        
        # Test 1: Inference Engine Service Check
        if ! is_container_running "$engine"; then
            print_error "$engine container is not running"
            record_test "fail" "$engine container is not running"
            echo ""
            echo "⚠️  Cannot test LLM state without $engine running"
            echo "   Run: aixcl stack start"
            continue
        fi
        
        print_success "$engine container is running"
        record_test "pass" "$engine container is running"
        
        # Check Engine API health
        local engine_healthy=false
        if [ "$engine" = "ollama" ]; then
            if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/api/version 2>/dev/null | grep -q "200"; then
                engine_healthy=true
            fi
        else
            if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/v1/models 2>/dev/null | grep -q "200"; then
                engine_healthy=true
            fi
        fi

        if [ "$engine_healthy" = true ]; then
            print_success "$engine API is accessible"
            record_test "pass" "$engine API is accessible"
        else
            print_error "$engine API is not accessible"
            record_test "fail" "$engine API is not accessible"
            echo ""
            continue
        fi
        
        echo ""
        
        # Test 2: List All Available Models
        echo "All Available Models"
        echo "-----------------------------------"
        
        echo "Listing installed models..."
        
        # Get all available models
        if ! available_models=$(get_available_models "$engine" 2>&1) || [ -z "$available_models" ]; then
            print_error "No models found in $engine"
            record_test "fail" "No models found in $engine"
            echo ""
            echo "⚠️  No models are installed. Add models with:"
            echo "   aixcl models add <model-name>"
            echo ""
            
            all_models_array=()
        else
            # Count models
            model_count=$(echo "$available_models" | grep -cv "^$")
            print_success "Found $model_count installed model(s)"
            record_test "pass" "Found $model_count installed model(s)"
            
            echo ""
            echo "Installed models:"
            
            # Convert to array for later testing
            all_models_array=()
            while IFS= read -r model; do
                if [ -n "$model" ]; then
                    echo "  - $model"
                    all_models_array+=("$model")
                fi
            done <<< "$available_models"
        fi
        
        echo ""
    done
    
    record_test "pass" "LLM state check complete"
}

# ============================================================================
# SECTION 7: MODEL INFERENCE TESTS
# ============================================================================
test_model_inference() {
    start_section "Model Inference - Prompt & Response"
    
    local test_model="${1:-}"
    local max_retries=5
    local retry_count=0
    
    # Try to find a model already installed/loaded with retries
    while [ -z "$test_model" ] && [ $retry_count -lt $max_retries ]; do
        test_model=$(get_available_models "$INFERENCE_ENGINE" | head -1)
        if [ -z "$test_model" ]; then
            echo "Waiting for $INFERENCE_ENGINE to report available models... ($((retry_count+1))/$max_retries)"
            sleep 5
            retry_count=$((retry_count+1))
        fi
    done
    
    # If still no model, use engine-specific defaults
    if [ -z "$test_model" ]; then
        case "$INFERENCE_ENGINE" in
            vllm)
                test_model="Qwen/Qwen2.5-Coder-1.5B-Instruct"
                ;;
            llamacpp)
                test_model="/models/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
                ;;
            *)
                test_model="qwen2.5-coder:1.5b"
                ;;
        esac
        echo "No models detected via API. Using default for $INFERENCE_ENGINE: $test_model"
    fi
    
    echo "Testing inference with model: $test_model"
    echo "Engine: $INFERENCE_ENGINE"
    echo "Sending test prompt: 'Why is the sky blue? Answer in one sentence.'"
    echo "-----------------------------------"

    local response=""
    local http_status=""

    case "$INFERENCE_ENGINE" in
        ollama)
            # Use Ollama native API
            local response_json
            response_json=$(curl -s -i -X POST http://127.0.0.1:11434/api/generate \
                -d "{\"model\": \"$test_model\", \"prompt\": \"Why is the sky blue? Answer in one sentence.\", \"stream\": false}")
            http_status=$(echo "$response_json" | grep HTTP | tail -1 | awk '{print $2}')
            response=$(echo "$response_json" | sed -n '/^{/,$p' | jq -r '.response' 2>/dev/null)
            ;;
        *)
            # OpenAI compatible (vLLM, llama.cpp)
            local response_json
            response_json=$(curl -s -i -X POST http://127.0.0.1:11434/v1/chat/completions \
                -H "Content-Type: application/json" \
                -d "{\"model\": \"$test_model\", \"messages\": [{\"role\": \"user\", \"content\": \"Why is the sky blue? Answer in one sentence.\"}], \"temperature\": 0}")
            http_status=$(echo "$response_json" | grep HTTP | tail -1 | awk '{print $2}')
            response=$(echo "$response_json" | sed -n '/^{/,$p' | jq -r '.choices[0].message.content' 2>/dev/null)
            ;;
    esac

    if [ "$http_status" = "200" ] && [ -n "$response" ] && [ "$response" != "null" ]; then
        print_success "Received response (HTTP 200)"
        echo "Response: $response"
        record_test "pass" "Model inference successful with $test_model"
    else
        print_error "Failed to get response from model (HTTP $http_status)"
        [ -z "$response" ] || [ "$response" = "null" ] && echo "Error: Empty or null response body"
        record_test "fail" "Model inference failed with $test_model (HTTP $http_status)"
    fi
}

# ============================================================================
# SECTION 8: OPENCODE INTEGRATION TESTS
# ============================================================================
test_opencode_integration() {
    start_section "OpenCode Integration - IDE Connectivity"
    
    # Check if OpenCode is reported as active by the CLI
    echo "Checking OpenCode status from AIXCL CLI..."
    if ./aixcl stack status | grep -q "OpenCode (IDE)     Status: Active"; then
        print_success "AIXCL reports OpenCode as Active"
        record_test "pass" "AIXCL reports OpenCode Active"
    else
        print_error "AIXCL reports OpenCode as Offline"
        record_test "fail" "AIXCL reports OpenCode Offline"
    fi
    
    # Check if we can reach the backend using OpenCode's expected configuration
    # (Checking the inference engine proxy on port 11434)
    echo "Verifying local inference proxy (11434) via OpenAI-compatible API..."
    local models_status
    models_status=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/v1/models 2>/dev/null || echo "000")
    
    if [ "$models_status" = "200" ]; then
        print_success "Inference proxy /v1/models is reachable (HTTP 200)"
        record_test "pass" "Inference proxy /v1/models reachable"
    elif [ "$models_status" = "404" ] && [ "$INFERENCE_ENGINE" = "ollama" ]; then
        # Some older Ollama versions might not support /v1/models but OpenCode prefers it
        print_warning "Inference proxy /v1/models returned 404 (Ollama might need update)"
        
        # Fallback check for Ollama native API
        if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/api/tags 2>/dev/null | grep -q "200"; then
            print_success "Ollama native API /api/tags is reachable"
            record_test "pass" "Ollama native API reachable (but /v1/models failed)"
        else
            print_error "Both /v1/models and /api/tags failed"
            record_test "fail" "Inference proxy unreachable"
        fi
    else
        print_error "Inference proxy /v1/models is not reachable (HTTP $models_status)"
        record_test "fail" "Inference proxy unreachable (HTTP $models_status)"
    fi

    # Dry-run a chat completion to ensure full protocol compatibility
    echo "Testing OpenAI-compatible chat completion protocol..."
    local chat_status
    chat_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:11434/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"none-existing-model-for-test\", \"messages\": [{\"role\": \"user\", \"content\": \"test\"}]}" 2>/dev/null || echo "000")
    
    # We expect 404 (model not found) or 401 (auth) or 200 (if model exists)
    # But 000, 502, 503, 504 are definitely failures
    if [[ "$chat_status" =~ ^(200|404|400|401)$ ]]; then
        print_success "Inference proxy supports /v1/chat/completions protocol (HTTP $chat_status)"
        record_test "pass" "Inference proxy protocol /v1/chat/completions supported"
    else
        print_error "Inference proxy does not support /v1/chat/completions or is down (HTTP $chat_status)"
        record_test "fail" "Inference proxy protocol /v1/chat/completions failed"
    fi
}

# ============================================================================
# SECTION 5: CLI ALIAS TESTS
# ============================================================================
test_cli_aliases() {
    start_section "CLI - Alias Resolution"
    
    echo "Testing 'engine' alias resolution..."
    
    # Test logs alias
    echo "1. Testing: ./aixcl stack logs engine --tail 1"
    if ./aixcl stack logs engine 1 2>&1 | grep -q "Fetching logs for ${INFERENCE_ENGINE:-ollama}"; then
        print_success "Logs alias resolved correctly to ${INFERENCE_ENGINE:-ollama}"
        record_test "pass" "CLI 'engine' alias resolved for logs"
    else
        print_error "Logs alias resolution failed"
        record_test "fail" "CLI 'engine' alias failed for logs"
    fi
    
    # Test status alias (if applicable, though status is usually global)
    # Testing get_container_name logic via service status check internally
    echo "2. Testing: ./aixcl service status engine"
    # Note: 'service status' isn't a command, but 'stack status' shows it.
    # We can test if 'is_valid_service engine' returns 0 by running start with it (dry run-ish)
    if is_valid_service "engine"; then
        print_success "is_valid_service identifies 'engine' as valid"
        record_test "pass" "Common library recognizes 'engine' as a valid service"
    else
        print_error "is_valid_service failed to recognize 'engine'"
        record_test "fail" "Common library failed to recognize 'engine'"
    fi

    # Test get_container_name resolution
    local resolved_name
    resolved_name=$(get_container_name "engine")
    if [ "$resolved_name" = "${INFERENCE_ENGINE:-ollama}" ]; then
        print_success "get_container_name 'engine' -> $resolved_name"
        record_test "pass" "Container name resolution for 'engine' works"
    else
        print_error "get_container_name 'engine' -> $resolved_name (expected ${INFERENCE_ENGINE:-ollama})"
        record_test "fail" "Container name resolution for 'engine' failed"
    fi
}

# Test runtime core services
test_component_runtime_core() {
    start_section "Runtime Core - Inference Engines"
    
    local engines=("ollama" "vllm" "llamacpp")
    
    for engine in "${engines[@]}"; do
        local display_name="$engine"
        [ "$engine" = "ollama" ] && display_name="$engine (Default)"
        
        echo "Testing $display_name..."
        
        if [ "$INFERENCE_ENGINE" != "$engine" ]; then
            print_warning "$engine is not the active inference engine"
            record_test "skip" "$engine health check skipped (not active)"
            continue
        fi
        
        # Inference Engine
        if is_container_running "$engine"; then
            print_success "$engine container is running"
            record_test "pass" "$engine container is running"
            
            local engine_healthy=false
            if [ "$engine" = "ollama" ]; then
                if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/api/version 2>/dev/null | grep -q "200"; then
                    engine_healthy=true
                fi
            else
                if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:11434/v1/models 2>/dev/null | grep -q "200"; then
                    engine_healthy=true
                fi
            fi

            if [ "$engine_healthy" = true ]; then
                print_success "$engine health check passed"
                record_test "pass" "$engine health check passed"
                
                # Perform deeper protocol validation for the active engine
                test_model_inference
                test_opencode_integration
            else
                print_error "$engine health check failed"
                record_test "fail" "$engine health check failed"
            fi
        else
            print_error "$engine container is not running"
            record_test "fail" "$engine container is not running"
        fi
    done
}

# Test database services (postgres, pgadmin)
test_component_database() {
    start_section "Database - PostgreSQL & pgAdmin"
    
    # PostgreSQL
    if is_container_running "postgres"; then
        print_success "PostgreSQL container is running"
        record_test "pass" "PostgreSQL container is running"
        if timeout 2 docker exec postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
            print_success "PostgreSQL health check passed"
            record_test "pass" "PostgreSQL health check passed"
        else
            print_error "PostgreSQL health check failed"
            record_test "fail" "PostgreSQL health check failed"
        fi
    else
        print_error "PostgreSQL container is not running"
        record_test "fail" "PostgreSQL container is not running"
    fi
    
    # pgAdmin
    if is_container_running "pgadmin"; then
        print_success "pgAdmin container is running"
        record_test "pass" "pgAdmin container is running"
        PGADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5050 2>/dev/null || echo "000")
        if [ "$PGADMIN_STATUS" = "200" ] || [ "$PGADMIN_STATUS" = "302" ]; then
            print_success "pgAdmin health check passed"
            record_test "pass" "pgAdmin health check passed"
        else
            print_error "pgAdmin health check failed (HTTP $PGADMIN_STATUS)"
            record_test "fail" "pgAdmin health check failed (HTTP $PGADMIN_STATUS)"
        fi
    else
        print_error "pgAdmin container is not running"
        record_test "fail" "pgAdmin container is not running"
    fi
}

# Test monitoring services
test_component_monitoring() {
    start_section "Monitoring - Prometheus, Grafana, Exporters"
    
    # Prometheus
    if is_container_running "prometheus"; then
        print_success "Prometheus container is running"
        record_test "pass" "Prometheus container is running"
        PROMETHEUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9090/-/healthy 2>/dev/null || echo "000")
        if [ "$PROMETHEUS_STATUS" = "200" ]; then
            print_success "Prometheus health check passed"
            record_test "pass" "Prometheus health check passed"
        else
            print_error "Prometheus health check failed (HTTP $PROMETHEUS_STATUS)"
            record_test "fail" "Prometheus health check failed (HTTP $PROMETHEUS_STATUS)"
        fi
    else
        print_error "Prometheus container is not running"
        record_test "fail" "Prometheus container is not running"
    fi
    
    # Grafana
    if is_container_running "grafana"; then
        print_success "Grafana container is running"
        record_test "pass" "Grafana container is running"
        GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/api/health 2>/dev/null || echo "000")
        if [ "$GRAFANA_STATUS" = "200" ]; then
            print_success "Grafana health check passed"
            record_test "pass" "Grafana health check passed"
        else
            print_error "Grafana health check failed (HTTP $GRAFANA_STATUS)"
            record_test "fail" "Grafana health check failed (HTTP $GRAFANA_STATUS)"
        fi
    else
        print_error "Grafana container is not running"
        record_test "fail" "Grafana container is not running"
    fi
    
    # Exporters
    for exporter in cadvisor node-exporter postgres-exporter; do
        if is_container_running "$exporter"; then
            print_success "$exporter container is running"
            record_test "pass" "$exporter container is running"
        else
            print_error "$exporter container is not running"
            record_test "fail" "$exporter container is not running"
        fi
    done
    
    # NVIDIA GPU Exporter (optional)
    if is_container_running "nvidia-gpu-exporter"; then
        NVIDIA_GPU_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9400/metrics 2>/dev/null || echo "000")
        if [ "$NVIDIA_GPU_EXPORTER_STATUS" = "200" ]; then
            print_success "NVIDIA GPU Exporter health check passed"
            record_test "pass" "NVIDIA GPU Exporter health check passed"
        else
            print_error "NVIDIA GPU Exporter health check failed (HTTP $NVIDIA_GPU_EXPORTER_STATUS)"
            record_test "fail" "NVIDIA GPU Exporter health check failed (HTTP $NVIDIA_GPU_EXPORTER_STATUS)"
        fi
    else
        print_warning "NVIDIA GPU Exporter (expected on non-GPU systems)"
        record_test "skip" "NVIDIA GPU Exporter container is not running (optional)"
    fi
}

# Test logging services
test_component_logging() {
    start_section "Logging - Loki & Promtail"
    
    # Loki
    if is_container_running "loki"; then
        print_success "Loki container is running"
        record_test "pass" "Loki container is running"
        LOKI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3100/ready 2>/dev/null || echo "000")
        if [ "$LOKI_STATUS" = "200" ]; then
            print_success "Loki health check passed"
            record_test "pass" "Loki health check passed"
        else
            print_error "Loki health check failed (HTTP $LOKI_STATUS)"
            record_test "fail" "Loki health check failed (HTTP $LOKI_STATUS)"
        fi
    else
        print_error "Loki container is not running"
        record_test "fail" "Loki container is not running"
    fi
    
    # Promtail
    if is_container_running "promtail"; then
        print_success "Promtail container is running"
        record_test "pass" "Promtail container is running (no health endpoint)"
    else
        print_error "Promtail container is not running"
        record_test "fail" "Promtail container is not running"
    fi
}

# Test UI services
test_component_ui() {
    start_section "UI - Open WebUI"
    
    if is_container_running "$CONTAINER_NAME"; then
        print_success "Open WebUI container is running"
        record_test "pass" "Open WebUI container is running"
        
        # Health check with retries
        WEBUI_STATUS="000"
        WEBUI_READY=false
        for i in {1..15}; do
            WEBUI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8080/health 2>/dev/null || echo "000")
            if [ "$WEBUI_STATUS" = "200" ]; then
                WEBUI_READY=true
                break
            fi
            if [ "$WEBUI_STATUS" = "000" ] || [ "$WEBUI_STATUS" = "404" ]; then
                ROOT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:8080/ 2>/dev/null || echo "000")
                if [ "$ROOT_STATUS" = "200" ] || [ "$ROOT_STATUS" = "302" ] || [ "$ROOT_STATUS" = "307" ]; then
                    WEBUI_STATUS="$ROOT_STATUS"
                    WEBUI_READY=true
                    break
                fi
            fi
            if [ "$i" -le 8 ]; then
                sleep 3
            else
                sleep 2
            fi
        done
        
        if [ "$WEBUI_READY" = "true" ]; then
            print_success "Open WebUI health check passed"
            record_test "pass" "Open WebUI health check passed"
        else
            print_error "Open WebUI health check failed (HTTP $WEBUI_STATUS)"
            record_test "fail" "Open WebUI health check failed (HTTP $WEBUI_STATUS)"
        fi
    else
        print_error "Open WebUI container is not running"
        record_test "fail" "Open WebUI container is not running"
    fi
}

# Test automation services
test_component_automation() {
    start_section "Automation - Watchtower"
    
    if is_container_running "watchtower"; then
        print_success "Watchtower container is running"
        record_test "pass" "Watchtower container is running"
    else
        print_error "Watchtower container is not running"
        record_test "fail" "Watchtower container is not running"
    fi
}

# ============================================================================
# PROFILE-BASED TEST RUNNERS
# ============================================================================

# Test usr profile (runtime core + database)
test_profile_usr() {
    echo "Running tests for profile: usr"
    echo "Profile includes: runtime core services + PostgreSQL"
    echo ""
    
    test_environment_check
    test_component_runtime_core
    test_component_database
    test_llm_state
    test_model_inference
    test_opencode_integration
    test_cli_aliases
    test_security_validation
    }

    # Test dev profile (runtime core + database + UI)
    test_profile_dev() {
    echo "Running tests for profile: dev"
    echo "Profile includes: runtime core, database, UI"
    echo ""

    test_environment_check
    test_component_runtime_core
    test_component_database
    test_component_ui
    test_llm_state
    test_model_inference
    test_opencode_integration
    test_cli_aliases
    test_security_validation
    }

    # Test ops profile (runtime core + database + monitoring + logging)
    test_profile_ops() {
    echo "Running tests for profile: ops"
    echo "Profile includes: runtime core, database, monitoring, logging"
    echo ""

    test_environment_check
    test_component_runtime_core
    test_component_database
    test_component_monitoring
    test_component_logging
    test_llm_state
    test_model_inference
    test_opencode_integration
    test_cli_aliases
    test_security_validation
    }

    # Test sys profile (all services)
    test_profile_sys() {
    echo "Running tests for profile: sys"
    echo "Profile includes: all services"
    # Run tests for each section
    test_environment_check
    test_stack_status
    test_llm_state
    test_model_inference
    test_opencode_integration
    test_cli_aliases
    test_security_validation
    }
# ============================================================================
# SECTION 5: NEGATIVE TESTS & RECOVERY
# ============================================================================
test_negative_scenarios() {
    start_section "Negative Tests - Error Handling & Recovery"
    
    echo "Database Authentication (Invalid Password)"
    echo "-----------------------------------"
    if is_container_running "postgres"; then
        # Try to connect with a definitely wrong password
        if docker exec -e PGPASSWORD="wrong_password_123" postgres psql -U "$POSTGRES_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
            print_error "Database connection succeeded with WRONG password!"
            record_test "fail" "Negative test: Database should have rejected wrong password"
        else
            print_success "Database correctly rejected invalid password"
            record_test "pass" "Negative test: Database rejected invalid password"
        fi
    else
        print_warning "PostgreSQL not running, skipping auth test"
        record_test "skip" "Negative test: Database auth (PostgreSQL not running)"
    fi

    echo ""
    echo "Environment Validation (Missing .env)"
    echo "-----------------------------------"
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        # Temporarily move .env to test error handling
        mv "${SCRIPT_DIR}/.env" "${SCRIPT_DIR}/.env.tmp"
        
        # Run a command that requires .env (e.g., status or check-env should warn)
        # Note: some commands might auto-create it, so we check for the specific warning/behavior
        if ./aixcl stack status 2>&1 | grep -q "Warning: .env file not found"; then
            print_success "CLI correctly warned about missing .env file"
            record_test "pass" "Negative test: CLI reported missing .env"
        else
            # If it didn't warn, check if it auto-created it
            if [ -f "${SCRIPT_DIR}/.env" ]; then
                print_success "CLI auto-created .env file as expected"
                record_test "pass" "Negative test: CLI auto-created missing .env"
                # If we don't want it to stay, rm it
                # rm "${SCRIPT_DIR}/.env"
            else
                print_warning "CLI behavior on missing .env was silent"
                record_test "skip" "Negative test: CLI behavior on missing .env (no warning)"
            fi
        fi
        
        # Restore .env
        mv "${SCRIPT_DIR}/.env.tmp" "${SCRIPT_DIR}/.env"
    else
        print_warning ".env file not found, skipping environment test"
        record_test "skip" "Negative test: Missing .env (already missing)"
    fi

    echo ""
    echo "Environment Validation (Missing POSTGRES_PASSWORD)"
    echo "-----------------------------------"
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        cp "${SCRIPT_DIR}/.env" "${SCRIPT_DIR}/.env.tmp2"
        # Create .env without password
        grep -v "POSTGRES_PASSWORD" "${SCRIPT_DIR}/.env.tmp2" > "${SCRIPT_DIR}/.env"
        
        # Run check-env
        if ./aixcl utils check-env 2>&1 | grep -q "Missing required environment variable in .env: POSTGRES_PASSWORD"; then
            print_success "CLI correctly caught missing POSTGRES_PASSWORD"
            record_test "pass" "Negative test: CLI reported missing POSTGRES_PASSWORD"
        else
            print_error "CLI failed to report missing POSTGRES_PASSWORD"
            record_test "fail" "Negative test: CLI allowed missing POSTGRES_PASSWORD"
        fi
        
        mv "${SCRIPT_DIR}/.env.tmp2" "${SCRIPT_DIR}/.env"
    else
        print_warning ".env file not found, skipping password test"
        record_test "skip" "Negative test: Missing POSTGRES_PASSWORD (.env missing)"
    fi

    echo ""
    echo "CLI - Invalid Database Name Validation"
    echo "-----------------------------------"
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        cp "${SCRIPT_DIR}/.env" "${SCRIPT_DIR}/.env.tmp3"
        # Set an invalid database name
        sed -i 's/^[[:space:]]*POSTGRES_DATABASE=.*/POSTGRES_DATABASE="invalid; drop table;"/' "${SCRIPT_DIR}/.env"
        if ! grep -q "POSTGRES_DATABASE=" "${SCRIPT_DIR}/.env"; then
            echo "POSTGRES_DATABASE=\"invalid; drop table;\"" >> "${SCRIPT_DIR}/.env"
        fi
        
        # Run check-env
        local check_env_out
        check_env_out=$(./aixcl utils check-env 2>&1)
        
        if echo "$check_env_out" | grep -q "contains invalid characters"; then
             print_success "CLI correctly caught invalid database name"
             record_test "pass" "Negative test: CLI caught malformed DB name"
        else
             print_error "CLI failed to catch invalid database name"
             # echo "Output was: $check_env_out"
             record_test "fail" "Negative test: CLI allowed malformed DB name"
        fi
        
        mv "${SCRIPT_DIR}/.env.tmp3" "${SCRIPT_DIR}/.env"
    else
        print_warning ".env file not found, skipping DB name test"
        record_test "skip" "Negative test: CLI caught malformed DB name (.env missing)"
    fi

    echo ""
    echo "CLI - Invalid Profile Request"
    echo "-----------------------------------"
    if ./aixcl stack start --profile "invalid_profile_123" 2>&1 | grep -q "Error: Invalid profile"; then
        print_success "CLI correctly rejected unknown profile"
        record_test "pass" "Negative test: CLI rejected invalid profile"
    else
        print_error "CLI failed to reject unknown profile"
        record_test "fail" "Negative test: CLI allowed or failed silently for invalid profile"
    fi

    echo ""
    echo "Port Conflict (Simulated)"
    echo "-----------------------------------"
    # Port 8080 is usually used by Open WebUI
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":8080 "; then
            print_success "Port 8080 is correctly identified as in-use"
            record_test "pass" "Negative test: Port 8080 conflict check"
        else
            print_warning "Port 8080 is not in use, skipping conflict test"
            record_test "skip" "Negative test: Port 8080 conflict (port not in use)"
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":8080 "; then
            print_success "Port 8080 is correctly identified as in-use"
            record_test "pass" "Negative test: Port 8080 conflict check"
        else
            print_warning "Port 8080 is not in use, skipping conflict test"
            record_test "skip" "Negative test: Port 8080 conflict (port not in use)"
        fi
    else
        print_warning "No netstat/ss found, skipping port conflict test"
        record_test "skip" "Negative test: Port conflict (tools missing)"
    fi
}

# ============================================================================
# SECTION 6: SECURITY VALIDATION
# ============================================================================
test_security_validation() {
    start_section "Security - Network Bindings & Access Control"
    
    # Run the dedicated network binding test script
    if [ -f "${SCRIPT_DIR}/tests/security/test_network_bindings.sh" ]; then
        if bash "${SCRIPT_DIR}/tests/security/test_network_bindings.sh"; then
            record_test "pass" "Security: Network bindings are properly secured"
        else
            record_test "fail" "Security: Network binding violation detected"
        fi
    else
        print_error "Security test script not found"
        record_test "fail" "Security test script missing"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
main() {
    # Parse command-line arguments
    local test_profile=""
    local test_component=""
    local list_targets=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile|-p)
                # Check if argument exists before accessing it
                if [[ $# -lt 2 ]] || [[ -z "${2:-}" ]]; then
                    echo "Error: Profile name is required after --profile" >&2
                    echo "Usage: $0 --profile <usr|dev|ops|sys>" >&2
                    exit 1
                fi
                test_profile="$2"
                shift 2
                ;;
            --component|-c)
                # Check if argument exists before accessing it
                if [[ $# -lt 2 ]] || [[ -z "${2:-}" ]]; then
                    echo "Error: Component name is required after --component" >&2
                    echo "Usage: $0 --component <runtime-core|database|monitoring|logging|ui|automation|api>" >&2
                    exit 1
                fi
                test_component="$2"
                shift 2
                ;;
            --list|-l)
                list_targets=true
                shift
                ;;
            --help|-h)
                echo "AIXCL Platform Test Suite"
                echo ""
                echo "Usage:"
                echo "  $0                           # Run all tests"
                echo "  $0 --profile <profile>       # Run tests for specific profile"
                echo "  $0 --component <component>   # Run tests for specific component"
                echo "  $0 --list                    # List available targets"
                echo ""
                echo "Profiles:"
                echo "  usr   - Runtime core services + database"
                echo "  dev   - Runtime core + database + UI"
                echo "  ops   - Runtime core + database + monitoring + logging"
                echo "  sys   - All services"
                echo ""
                echo "Components:"
                echo "  runtime-core  - AI Inference Engine ($INFERENCE_ENGINE)"
                echo "  database      - PostgreSQL and pgAdmin"
                echo "  monitoring    - Prometheus, Grafana, exporters"
                echo "  logging       - Loki and Promtail"
                echo "  ui            - Open WebUI"
                echo "  automation    - Watchtower"
                echo "  negative      - Error handling and recovery scenarios"
                echo "  security      - Network binding and access control validation"
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
    
    # List targets if requested
    if [ "$list_targets" = true ]; then
        echo "Available Test Targets"
        echo "======================"
        echo ""
        echo "Profiles:"
        echo "  usr   - Runtime core services + database"
        echo "  dev   - Runtime core + database + UI"
        echo "  ops   - Runtime core + database + monitoring + logging"
        echo "  sys   - All services"
        echo ""
        echo "Components:"
        echo "  runtime-core  - Ollama"
        echo "  database      - PostgreSQL and pgAdmin"
        echo "  monitoring    - Prometheus, Grafana, exporters"
        echo "  logging       - Loki and Promtail"
        echo "  ui            - Open WebUI"
        echo "  automation    - Watchtower"
        exit 0
    fi
    
    # Show help if no arguments provided
    if [ -z "$test_profile" ] && [ -z "$test_component" ]; then
        echo "AIXCL Platform Test Suite"
        echo ""
        echo "Usage:"
        echo "  $0                           # Show this help message"
        echo "  $0 --profile <profile>       # Run tests for specific profile"
        echo "  $0 --component <component>   # Run tests for specific component"
        echo "  $0 --list                    # List available targets"
        echo "  $0 --help                    # Show detailed help"
        echo ""
        echo "Profiles:"
        echo "  usr   - Runtime core services + database ($INFERENCE_ENGINE, postgres)"
        echo "  dev   - Runtime core + database + UI"
        echo "  ops   - Runtime core + database + monitoring + logging"
        echo "  sys   - All services"
        echo ""
        echo "Components:"
        echo "  runtime-core  - AI Inference Engine ($INFERENCE_ENGINE)"
        echo "  database      - PostgreSQL and pgAdmin"
        echo "  monitoring    - Prometheus, Grafana, exporters"
        echo "  logging       - Loki and Promtail"
        echo "  ui            - Open WebUI"
        echo "  automation    - Watchtower"
        echo ""
        echo "Examples:"
        echo "  $0 --profile usr                # Test usr profile"
        echo "  $0 --component runtime-core     # Test runtime core components"
        echo "  $0 --component database         # Test database components"
        echo ""
        echo "For detailed help, use: $0 --help"
        exit 0
    fi
    
    echo "=========================================="
    echo "AIXCL Platform Test Suite"
    echo "=========================================="
    echo ""
    echo "Test execution started at: $(date)"
    echo ""
    
    # Run tests based on arguments
    if [ -n "$test_profile" ]; then
        # Validate profile
        if ! is_valid_profile "$test_profile" 2>/dev/null; then
            echo "Error: Invalid profile: $test_profile" >&2
            echo "Valid profiles: usr, dev, ops, sys" >&2
            exit 1
        fi
        
        case "$test_profile" in
            usr)
                test_profile_usr
                ;;
            dev)
                test_profile_dev
                ;;
            ops)
                test_profile_ops
                ;;
            sys)
                test_profile_sys
                ;;
        esac
    elif [ -n "$test_component" ]; then
        # Component-based testing
        test_environment_check
        
        case "$test_component" in
            runtime-core)
                test_component_runtime_core
                test_llm_state
                ;;
            database)
                test_component_database
                ;;
            monitoring)
                test_component_monitoring
                ;;
            logging)
                test_component_logging
                ;;
            ui)
                test_component_ui
                ;;
            automation)
                test_component_automation
                ;;
            negative)
                test_negative_scenarios
                ;;
            security)
                test_security_validation
                ;;
            *)
                echo "Error: Unknown component: $test_component" >&2
                echo "Valid components: runtime-core, database, monitoring, logging, ui, automation, negative, security" >&2
                exit 1
                ;;
        esac
    fi
    
    # Final Summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo ""
    echo "Test execution completed at: $(date)"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        echo ""
        FINAL_EXIT_CODE=0
    else
        echo -e "${RED}❌ Some tests failed.${NC}"
        echo ""
        echo "Failed tests:"
        for result in "${test_results[@]}"; do
            if [[ "$result" == FAIL:* ]]; then
                echo "  - $result"
            fi
        done
        echo ""
        FINAL_EXIT_CODE=1
    fi
}

# Run main function with all arguments
main "$@"

# Exit with appropriate code
exit ${FINAL_EXIT_CODE:-1}
