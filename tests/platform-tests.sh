#!/usr/bin/env bash
# Platform Test Suite for AIXCL
# This script consolidates all test files from the repository into a single comprehensive test suite.
#
# Test Categories:
# 0. Environment Check - Verify environment setup (Docker, dependencies, etc.)
# 1. Stack Status - Container status and health checks
# 2. LLM State - Model availability and operational status
# 3. Database Connection - PostgreSQL connection and schema verification
# 4. API Endpoints - LLM-Council API functionality
# 5. Continue Integration - Full Continue plugin → LLM Council → Database flow
# 6. Council Members - Council model availability and operational status
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
#   ./tests/platform-tests.sh --component api          # Test API endpoints
#   ./tests/platform-tests.sh --list                   # List available targets
#
# Exit Codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -u

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_utils.sh"
source "${SCRIPT_DIR}/lib/color.sh"
source "${SCRIPT_DIR}/lib/council_utils.sh"

# Source profile library if available
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
BACKEND_MODE=${BACKEND_MODE:-ollama}
API_URL=${LLM_COUNCIL_API_URL:-http://localhost:8000}
LLM_COUNCIL_DIR="${SCRIPT_DIR}/llm-council"

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
    
    # Core Application Services
    echo "Core"
    if is_container_running "ollama"; then
        print_success "Ollama"
        record_test "pass" "Ollama container is running"
    else
        print_error "Ollama"
        record_test "fail" "Ollama container is not running"
    fi
    
    if is_container_running "$CONTAINER_NAME"; then
        print_success "Open WebUI"
        record_test "pass" "Open WebUI container is running"
    else
        print_error "Open WebUI"
        record_test "fail" "Open WebUI container is not running"
    fi
    
    if is_container_running "llm-council"; then
        print_success "LLM-Council"
        record_test "pass" "LLM-Council container is running"
    else
        print_error "LLM-Council"
        record_test "fail" "LLM-Council container is not running"
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
    echo "Core"
    
    # Ollama health check
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/version 2>/dev/null | grep -q "200"; then
        print_success "Ollama"
        record_test "pass" "Ollama health check passed"
    else
        print_error "Ollama"
        record_test "fail" "Ollama health check failed"
    fi
    
    # Open WebUI health check (with longer timeout for migrations)
    WEBUI_STATUS="000"
    WEBUI_READY=false
    # Try multiple endpoints - /health might not exist in all versions, try root and /api/config as fallbacks
    for i in {1..15}; do
        # Try /health endpoint first (preferred)
        WEBUI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080/health 2>/dev/null || echo "000")
        if [ "$WEBUI_STATUS" = "200" ]; then
            WEBUI_READY=true
            break
        fi
        
        # If /health doesn't work, try root endpoint (some versions use this)
        if [ "$WEBUI_STATUS" = "000" ] || [ "$WEBUI_STATUS" = "404" ]; then
            ROOT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080/ 2>/dev/null || echo "000")
            if [ "$ROOT_STATUS" = "200" ] || [ "$ROOT_STATUS" = "302" ] || [ "$ROOT_STATUS" = "307" ]; then
                WEBUI_STATUS="$ROOT_STATUS"
                WEBUI_READY=true
                break
            fi
        fi
        
        # On first few attempts, wait longer to allow migrations
        if [ $i -le 8 ]; then
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
    
    # LLM-Council health check
    COUNCIL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${API_URL}/health 2>/dev/null || echo "000")
    if [ "$COUNCIL_STATUS" = "200" ]; then
        print_success "LLM-Council"
        record_test "pass" "LLM-Council health check passed"
    else
        print_error "LLM-Council"
        record_test "fail" "LLM-Council health check failed (HTTP $COUNCIL_STATUS)"
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
    PGADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5050 2>/dev/null || echo "000")
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
    PROMETHEUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy 2>/dev/null || echo "000")
    if [ "$PROMETHEUS_STATUS" = "200" ]; then
        print_success "Prometheus"
        record_test "pass" "Prometheus health check passed"
    else
        print_error "Prometheus"
        record_test "fail" "Prometheus health check failed (HTTP $PROMETHEUS_STATUS)"
    fi
    
    # Grafana health check
    GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null || echo "000")
    if [ "$GRAFANA_STATUS" = "200" ]; then
        print_success "Grafana"
        record_test "pass" "Grafana health check passed"
    else
        print_error "Grafana"
        record_test "fail" "Grafana health check failed (HTTP $GRAFANA_STATUS)"
    fi
    
    # cAdvisor health check
    CADVISOR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/metrics 2>/dev/null || echo "000")
    if [ "$CADVISOR_STATUS" = "200" ]; then
        print_success "cAdvisor"
        record_test "pass" "cAdvisor health check passed"
    else
        print_error "cAdvisor"
        record_test "fail" "cAdvisor health check failed (HTTP $CADVISOR_STATUS)"
    fi
    
    # Node Exporter health check
    NODE_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9100/metrics 2>/dev/null || echo "000")
    if [ "$NODE_EXPORTER_STATUS" = "200" ]; then
        print_success "Node Exporter"
        record_test "pass" "Node Exporter health check passed"
    else
        print_error "Node Exporter"
        record_test "fail" "Node Exporter health check failed (HTTP $NODE_EXPORTER_STATUS)"
    fi
    
    # Postgres Exporter health check
    POSTGRES_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9187/metrics 2>/dev/null || echo "000")
    if [ "$POSTGRES_EXPORTER_STATUS" = "200" ]; then
        print_success "Postgres Exporter"
        record_test "pass" "Postgres Exporter health check passed"
    else
        print_error "Postgres Exporter"
        record_test "fail" "Postgres Exporter health check failed (HTTP $POSTGRES_EXPORTER_STATUS)"
    fi
    
    # NVIDIA GPU Exporter (optional)
    if is_container_running "nvidia-gpu-exporter"; then
        NVIDIA_GPU_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9400/metrics 2>/dev/null || echo "000")
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
    LOKI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready 2>/dev/null || echo "000")
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

# ============================================================================
# SECTION 2: LLM STATE TESTS
# ============================================================================
test_llm_state() {
    start_section "LLM State - Models & Operational Status"
    
    # Test 1: Ollama Service Check
    echo "Ollama Service"
    echo "-----------------------------------"
    
    if ! is_container_running "ollama"; then
        print_error "Ollama container is not running"
        record_test "fail" "Ollama container is not running"
        echo ""
        echo "⚠️  Cannot test LLM state without Ollama running"
        echo "   Run: aixcl stack start"
        return
    fi
    
    print_success "Ollama container is running"
    record_test "pass" "Ollama container is running"
    
    # Check Ollama API health
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/version 2>/dev/null | grep -q "200"; then
        print_success "Ollama API is accessible"
        record_test "pass" "Ollama API is accessible"
    else
        print_error "Ollama API is not accessible"
        record_test "fail" "Ollama API is not accessible"
        return
    fi
    
    echo ""
    
    # Test 2: List All Available Models
    echo "All Available Models"
    echo "-----------------------------------"
    
    echo "Listing installed models..."
    
    # Get all available models from Ollama
    available_models=$(get_available_models 2>&1)
    if [ $? -ne 0 ] || [ -z "$available_models" ]; then
        print_error "No models found in Ollama"
        record_test "fail" "No models found in Ollama"
        echo ""
        echo "⚠️  No models are installed. Add models with:"
        echo "   aixcl models add <model-name>"
        echo ""
        
        all_models_array=()
    else
        # Count models
        model_count=$(echo "$available_models" | grep -v "^$" | wc -l | tr -d ' ')
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
    
    # Test 3: Council Configuration
    echo "Council Participation Report"
    echo "-----------------------------------"
    
    # Read council configuration from .env file
    council_models=""
    chairman_model=""
    env_file="${SCRIPT_DIR}/.env"
    
    if [[ ! -f "$env_file" ]]; then
        print_warning ".env file not found"
        record_test "skip" "Council configuration check skipped (.env not found)"
    else
        # Read .env file
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -z "$line" ]] && continue
            [[ "${line#\#}" != "$line" ]] && continue
            
            if [[ "$line" =~ ^BACKEND_MODE[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                BACKEND_MODE="${BASH_REMATCH[1]}"
                BACKEND_MODE=$(echo "$BACKEND_MODE" | xargs | tr -d '"' | tr -d "'")
            elif [[ "$line" =~ ^COUNCIL_MODELS[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                council_models="${BASH_REMATCH[1]}"
                council_models=$(echo "$council_models" | xargs | tr -d '"' | tr -d "'")
            elif [[ "$line" =~ ^CHAIRMAN_MODEL[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                chairman_model="${BASH_REMATCH[1]}"
                chairman_model=$(echo "$chairman_model" | xargs | tr -d '"' | tr -d "'")
            fi
        done < "$env_file"
        
        if [[ -z "$council_models" ]] && [[ -z "$chairman_model" ]]; then
            print_warning "Council is not configured"
            record_test "skip" "Council configuration check skipped (not configured)"
            echo "   Configure with: aixcl council configure"
        else
            print_success "Council is configured"
            record_test "pass" "Council configuration found"
            echo ""
            
            # Check chairman
            if [[ -n "$chairman_model" ]]; then
                echo "👑 Chairman Model: $chairman_model"
                
                # Check if chairman is available
                if [[ ${#all_models_array[@]} -gt 0 ]]; then
                    if printf '%s\n' "${all_models_array[@]}" | grep -q "^${chairman_model}$"; then
                        echo "  ✅ Available in Ollama"
                        record_test "pass" "Chairman model '$chairman_model' is available"
                    else
                        echo "  ❌ Not found in Ollama"
                        record_test "fail" "Chairman model '$chairman_model' is not available"
                    fi
                else
                    echo "  ⚠️  Cannot verify (no models in Ollama)"
                    record_test "skip" "Chairman model availability check skipped"
                fi
                echo ""
            fi
            
            # Check council members
            if [[ -n "$council_models" ]]; then
                echo "👥 Council Members:"
                
                IFS=',' read -ra MEMBERS <<< "$council_models"
                member_count=0
                available_count=0
                
                for member in "${MEMBERS[@]}"; do
                    member=$(echo "$member" | xargs)
                    if [[ -n "$member" ]]; then
                        member_count=$((member_count + 1))
                        echo "  [$member_count] $member"
                        
                        # Check if member is available
                        if [[ ${#all_models_array[@]} -gt 0 ]]; then
                            if printf '%s\n' "${all_models_array[@]}" | grep -q "^${member}$"; then
                                echo "      ✅ Available in Ollama"
                                available_count=$((available_count + 1))
                                record_test "pass" "Council member '$member' is available"
                            else
                                echo "      ❌ Not found in Ollama"
                                record_test "fail" "Council member '$member' is not available"
                            fi
                        else
                            echo "      ⚠️  Cannot verify (no models in Ollama)"
                            record_test "skip" "Council member '$member' availability check skipped"
                        fi
                        echo ""
                    fi
                done
                
                echo "Council Members Summary:"
                echo "  Total Members: $member_count"
                echo "  Available: $available_count"
                
                if [[ $available_count -eq $member_count ]]; then
                    record_test "pass" "All $member_count council members are available"
                else
                    record_test "fail" "Only $available_count of $member_count council members are available"
                fi
            fi
        fi
    fi
}

# ============================================================================
# SECTION 3: DATABASE CONNECTION TESTS
# ============================================================================
test_database_connection() {
    start_section "Database Connection - PostgreSQL"
    
    # Check if PostgreSQL container is running
    if ! is_container_running "postgres"; then
        print_error "PostgreSQL container is not running"
        record_test "fail" "PostgreSQL container is not running"
        echo "   Cannot run database tests without PostgreSQL"
        return
    fi
    
    # Check if Python test script exists
    DB_TEST_SCRIPT="${LLM_COUNCIL_DIR}/scripts/test/test_db_connection.py"
    if [ ! -f "$DB_TEST_SCRIPT" ]; then
        print_error "Database test script not found: $DB_TEST_SCRIPT"
        record_test "fail" "Database test script not found"
        return
    fi
    
    echo "Running database connection tests..."
    echo ""
    
    # Change to llm-council directory for proper Python path
    cd "$LLM_COUNCIL_DIR" || {
        print_error "Cannot change to llm-council directory"
        record_test "fail" "Cannot change to llm-council directory"
        return
    }
    
    # Check if uv is available (preferred method)
    # Add ~/.local/bin to PATH for uv if it exists
    if [ -d "$HOME/.local/bin" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    if command -v uv &> /dev/null; then
        echo "Using uv to run database tests..."
        if uv run python scripts/test/test_db_connection.py; then
            print_success "Database connection tests passed"
            record_test "pass" "Database connection tests passed"
        else
            print_error "Database connection tests failed"
            record_test "fail" "Database connection tests failed"
        fi
    elif command -v python3 &> /dev/null; then
        echo "Using python3 to run database tests..."
        # Try to install asyncpg if missing - use uv if available, otherwise try pip
        if ! python3 -c "import asyncpg" 2>/dev/null; then
            echo "⚠️  asyncpg not found. Attempting to install..."
            if command -v uv &> /dev/null; then
                uv pip install asyncpg 2>/dev/null || echo "   Could not install asyncpg with uv"
            else
                python3 -m pip install --user asyncpg 2>/dev/null || echo "   Could not install asyncpg. Please install manually: pip install asyncpg"
            fi
        fi
        if python3 scripts/test/test_db_connection.py; then
            print_success "Database connection tests passed"
            record_test "pass" "Database connection tests passed"
        else
            print_error "Database connection tests failed"
            record_test "fail" "Database connection tests failed"
        fi
    else
        print_error "Neither uv nor python3 found"
        record_test "fail" "Python not available for database tests"
    fi
    
    # Return to original directory
    cd "$SCRIPT_DIR" || true
}

# ============================================================================
# SECTION 4: API ENDPOINT TESTS
# ============================================================================
test_api_endpoints() {
    start_section "API Endpoints - LLM-Council API"
    
    # Wait for service to be ready
    echo -n "Waiting for API to be ready..."
    API_READY=false
    for i in {1..30}; do
        if curl -s -f "${API_URL}/health" > /dev/null 2>&1; then
            echo " ✅"
            API_READY=true
            break
        fi
        echo -n "."
        sleep 1
    done
    
    if [ "$API_READY" = "false" ]; then
        echo " ❌ API not ready"
        record_test "fail" "LLM-Council API not ready after 30 seconds"
        return
    fi
    
    record_test "pass" "LLM-Council API is ready"
    
    # Test 1: Health check
    echo -e "\n1. Testing health endpoint..."
    HEALTH=$(curl -s "${API_URL}/health" 2>/dev/null)
    if [ -n "$HEALTH" ]; then
        echo "   Response: $HEALTH"
        record_test "pass" "Health endpoint responded"
    else
        record_test "fail" "Health endpoint failed"
    fi
    
    # Test 2: Send a test chat completion
    echo -e "\n2. Testing chat completion (Continue conversation)..."
    RESPONSE=$(curl -s -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "council",
            "messages": [
                {"role": "user", "content": "Hello, this is a test message from Continue plugin"}
            ],
            "stream": false
        }' 2>/dev/null)
    
    if [ -n "$RESPONSE" ]; then
        echo "   Response received (length: ${#RESPONSE})"
        
        # Try multiple methods to extract the ID
        # Method 1: Standard JSON format "id":"value"
        CONV_ID=$(echo "$RESPONSE" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
        
        # Method 2: If Method 1 failed, try with Python (more reliable for JSON)
        if [ -z "$CONV_ID" ] && command -v python3 >/dev/null 2>&1; then
            CONV_ID=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('id', ''))
except:
    pass
" 2>/dev/null || echo "")
        fi
        
        # Method 3: Fallback to simple grep
        if [ -z "$CONV_ID" ]; then
            CONV_ID=$(echo "$RESPONSE" | grep -oP '"id"\s*:\s*"\K[^"]+' | head -1 || echo "")
        fi
        
        if [ -n "$CONV_ID" ]; then
            echo "   ✅ Got response ID: $CONV_ID"
            record_test "pass" "Chat completion endpoint responded with conversation ID"
        else
            echo "   ⚠️  No response ID found"
            echo "   Response preview (first 200 chars): ${RESPONSE:0:200}"
            # Check if response is valid JSON
            if command -v python3 >/dev/null 2>&1; then
                if echo "$RESPONSE" | python3 -m json.tool >/dev/null 2>&1; then
                    echo "   Response is valid JSON, but 'id' field not found"
                    # Show what fields are present
                    echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'   Available fields: {list(data.keys())}')
except:
    pass
" 2>/dev/null || true
                else
                    echo "   Response may not be valid JSON"
                fi
            fi
            record_test "fail" "Chat completion response missing conversation ID"
        fi
    else
        record_test "fail" "Chat completion endpoint failed"
    fi
    
    # Test 3: Test conversation continuity
    echo -e "\n3. Testing conversation continuity (second message)..."
    RESPONSE2=$(curl -s -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "council",
            "messages": [
                {"role": "user", "content": "Hello, this is a test message from Continue plugin"},
                {"role": "assistant", "content": "Previous response"},
                {"role": "user", "content": "This is a follow-up question"}
            ],
            "stream": false
        }' 2>/dev/null)
    
    if [ -n "$RESPONSE2" ]; then
        echo "   Response received (length: ${#RESPONSE2})"
        echo "   ✅ Second message processed"
        record_test "pass" "Conversation continuity test passed"
    else
        record_test "fail" "Conversation continuity test failed"
    fi
    
    # Test 4: Test deletion endpoint
    # Note: The response ID (chatcmpl-...) is different from conversation ID
    # We need to generate the conversation ID from the messages to delete it
    echo -e "\n4. Testing conversation deletion..."
    # Generate conversation ID from test messages (same way API does using UUID v5)
    if command -v python3 >/dev/null 2>&1; then
        TEST_CONV_ID=$(python3 -c "
import sys, uuid
# Generate conversation ID the same way the API does (UUID v5)
first_user_msg = 'Hello, this is a test message from Continue plugin'
# Use the same namespace UUID as the API (from conversation_tracker.py)
CONTINUE_NAMESPACE = uuid.UUID('6ba7b810-9dad-11d1-80b4-00c04fd430c8')
name = f'continue:{first_user_msg}'
conv_id = str(uuid.uuid5(CONTINUE_NAMESPACE, name))
print(conv_id)
" 2>/dev/null || echo "")
        
        if [ -n "$TEST_CONV_ID" ]; then
            DELETE_RESPONSE=$(curl -s -X DELETE "${API_URL}/v1/chat/completions/$TEST_CONV_ID" 2>/dev/null)
            DELETE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${API_URL}/v1/chat/completions/$TEST_CONV_ID" 2>/dev/null)
            
            if [ "$DELETE_STATUS" = "200" ] && echo "$DELETE_RESPONSE" | grep -q "success"; then
                echo "   ✅ Conversation deleted successfully"
                record_test "pass" "Conversation deletion endpoint worked"
            elif [ "$DELETE_STATUS" = "404" ] || echo "$DELETE_RESPONSE" | grep -q "not found"; then
                echo "   ⚠️  Conversation not found (may have been deleted already or never created)"
                echo "   Response: $DELETE_RESPONSE"
                record_test "skip" "Conversation deletion test skipped (conversation not found)"
            else
                echo "   ⚠️  Deletion response: $DELETE_RESPONSE (status: $DELETE_STATUS)"
                record_test "fail" "Conversation deletion endpoint failed"
            fi
        else
            echo "   ⚠️  Could not generate conversation ID for deletion test"
            record_test "skip" "Conversation deletion test skipped (could not generate conversation ID)"
        fi
    else
        echo "   ⚠️  Python3 not available, skipping conversation deletion test"
        record_test "skip" "Conversation deletion test skipped (python3 not available)"
    fi
}

# ============================================================================
# SECTION 5: CONTINUE INTEGRATION TESTS
# ============================================================================
test_continue_integration() {
    start_section "Continue Integration - Full Flow"
    
    # Check if LLM-Council container is running
    if ! is_container_running "llm-council"; then
        print_error "LLM-Council container is not running"
        record_test "fail" "LLM-Council container is not running"
        echo "   Cannot run Continue integration tests without LLM-Council"
        return
    fi
    
    # Check if Python test script exists
    CONTINUE_TEST_SCRIPT="${LLM_COUNCIL_DIR}/scripts/test/test_continue_integration.py"
    if [ ! -f "$CONTINUE_TEST_SCRIPT" ]; then
        print_error "Continue integration test script not found: $CONTINUE_TEST_SCRIPT"
        record_test "fail" "Continue integration test script not found"
        return
    fi
    
    echo "Running Continue integration tests..."
    echo ""
    
    # Change to llm-council directory for proper Python path
    cd "$LLM_COUNCIL_DIR" || {
        print_error "Cannot change to llm-council directory"
        record_test "fail" "Cannot change to llm-council directory"
        return
    }
    
    # Check if uv is available (preferred method)
    if command -v uv &> /dev/null; then
        echo "Using uv to run Continue integration tests..."
        if uv run python scripts/test/test_continue_integration.py; then
            print_success "Continue integration tests passed"
            record_test "pass" "Continue integration tests passed"
        else
            print_error "Continue integration tests failed"
            record_test "fail" "Continue integration tests failed"
        fi
    elif command -v python3 &> /dev/null; then
        echo "Using python3 to run Continue integration tests..."
        # Check if httpx is installed
        if ! python3 -c "import httpx" 2>/dev/null; then
            echo "⚠️  httpx not found. Attempting to install..."
            # Try uv first, then pip
            if command -v uv &> /dev/null; then
                uv pip install httpx 2>/dev/null || {
                    print_error "httpx not installed. Install with: uv pip install httpx"
                    record_test "fail" "httpx not available for Continue integration tests"
                    cd "$SCRIPT_DIR" || true
                    return
                }
            else
                python3 -m pip install --user httpx 2>/dev/null || {
                    print_error "httpx not installed. Install with: pip install httpx"
                    record_test "fail" "httpx not available for Continue integration tests"
                    cd "$SCRIPT_DIR" || true
                    return
                }
            fi
        fi
        if python3 scripts/test/test_continue_integration.py; then
            print_success "Continue integration tests passed"
            record_test "pass" "Continue integration tests passed"
        else
            print_error "Continue integration tests failed"
            record_test "fail" "Continue integration tests failed"
        fi
    else
        print_error "Neither uv nor python3 found"
        record_test "fail" "Python not available for Continue integration tests"
    fi
    
    # Return to original directory
    cd "$SCRIPT_DIR" || true
}

# ============================================================================
# SECTION 6: COUNCIL MEMBERS TESTS
# ============================================================================
test_council_members() {
    start_section "Council Members - Operational Status"
    
    # Check if LLM-Council container is running
    if ! is_container_running "llm-council"; then
        print_error "LLM-Council container is not running"
        record_test "fail" "LLM-Council container is not running"
        echo "   Cannot run council members tests without LLM-Council"
        return
    fi
    
    # Check if Python test script exists
    COUNCIL_TEST_SCRIPT="${LLM_COUNCIL_DIR}/scripts/test_council_members.py"
    if [ ! -f "$COUNCIL_TEST_SCRIPT" ]; then
        print_warning "Council members test script not found: $COUNCIL_TEST_SCRIPT"
        record_test "skip" "Council members test script not found"
        return
    fi
    
    echo "Running council members operational tests..."
    echo ""
    
    # Change to llm-council directory for proper Python path
    cd "$LLM_COUNCIL_DIR" || {
        print_error "Cannot change to llm-council directory"
        record_test "fail" "Cannot change to llm-council directory"
        return
    }
    
    # Check if uv is available (preferred method)
    if command -v uv &> /dev/null; then
        echo "Using uv to run council members tests..."
        if uv run python scripts/test_council_members.py; then
            print_success "Council members tests passed"
            record_test "pass" "Council members tests passed"
        else
            print_error "Council members tests failed"
            record_test "fail" "Council members tests failed"
        fi
    elif command -v python3 &> /dev/null; then
        echo "Using python3 to run council members tests..."
        # Check if httpx is installed
        if ! python3 -c "import httpx" 2>/dev/null; then
            print_warning "httpx not installed. Skipping council members tests."
            record_test "skip" "httpx not available for council members tests"
            cd "$SCRIPT_DIR" || true
            return
        fi
        if python3 scripts/test_council_members.py; then
            print_success "Council members tests passed"
            record_test "pass" "Council members tests passed"
        else
            print_error "Council members tests failed"
            record_test "fail" "Council members tests failed"
        fi
    else
        print_error "Neither uv nor python3 found"
        record_test "fail" "Python not available for council members tests"
    fi
    
    # Return to original directory
    cd "$SCRIPT_DIR" || true
}

# ============================================================================
# COMPONENT-BASED TEST FUNCTIONS
# ============================================================================

# Test runtime core services (ollama, llm-council)
test_component_runtime_core() {
    start_section "Runtime Core - Ollama & LLM-Council"
    
    # Ollama
    if is_container_running "ollama"; then
        print_success "Ollama container is running"
        record_test "pass" "Ollama container is running"
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/version 2>/dev/null | grep -q "200"; then
            print_success "Ollama health check passed"
            record_test "pass" "Ollama health check passed"
        else
            print_error "Ollama health check failed"
            record_test "fail" "Ollama health check failed"
        fi
    else
        print_error "Ollama container is not running"
        record_test "fail" "Ollama container is not running"
    fi
    
    # LLM-Council
    if is_container_running "llm-council"; then
        print_success "LLM-Council container is running"
        record_test "pass" "LLM-Council container is running"
        COUNCIL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${API_URL}/health 2>/dev/null || echo "000")
        if [ "$COUNCIL_STATUS" = "200" ]; then
            print_success "LLM-Council health check passed"
            record_test "pass" "LLM-Council health check passed"
        else
            print_error "LLM-Council health check failed (HTTP $COUNCIL_STATUS)"
            record_test "fail" "LLM-Council health check failed (HTTP $COUNCIL_STATUS)"
        fi
    else
        print_error "LLM-Council container is not running"
        record_test "fail" "LLM-Council container is not running"
    fi
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
        PGADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5050 2>/dev/null || echo "000")
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
        PROMETHEUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy 2>/dev/null || echo "000")
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
        GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null || echo "000")
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
        NVIDIA_GPU_EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9400/metrics 2>/dev/null || echo "000")
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
        LOKI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready 2>/dev/null || echo "000")
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
            WEBUI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080/health 2>/dev/null || echo "000")
            if [ "$WEBUI_STATUS" = "200" ]; then
                WEBUI_READY=true
                break
            fi
            if [ "$WEBUI_STATUS" = "000" ] || [ "$WEBUI_STATUS" = "404" ]; then
                ROOT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:8080/ 2>/dev/null || echo "000")
                if [ "$ROOT_STATUS" = "200" ] || [ "$ROOT_STATUS" = "302" ] || [ "$ROOT_STATUS" = "307" ]; then
                    WEBUI_STATUS="$ROOT_STATUS"
                    WEBUI_READY=true
                    break
                fi
            fi
            if [ $i -le 8 ]; then
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

# Test usr profile (runtime core only)
test_profile_usr() {
    echo "Running tests for profile: usr"
    echo "Profile includes: runtime core services only"
    echo ""
    
    test_environment_check
    test_component_runtime_core
    test_llm_state
    test_api_endpoints
    test_council_members
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
    test_database_connection
    test_api_endpoints
    test_continue_integration
    test_council_members
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
    test_database_connection
    test_api_endpoints
    test_council_members
}

# Test sys profile (all services)
test_profile_sys() {
    echo "Running tests for profile: sys"
    echo "Profile includes: all services"
    echo ""
    
    test_environment_check
    test_stack_status
    test_llm_state
    test_database_connection
    test_api_endpoints
    test_continue_integration
    test_council_members
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
                echo "  core  - Runtime core services only"
                echo "  dev   - Runtime core + database + UI"
                echo "  ops   - Runtime core + database + monitoring + logging"
                echo "  full  - All services"
                echo ""
                echo "Components:"
                echo "  runtime-core  - Ollama and LLM-Council"
                echo "  database      - PostgreSQL and pgAdmin"
                echo "  monitoring    - Prometheus, Grafana, exporters"
                echo "  logging       - Loki and Promtail"
                echo "  ui            - Open WebUI"
                echo "  automation    - Watchtower"
                echo "  api           - LLM-Council API endpoints"
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
        echo "  core  - Runtime core services only"
        echo "  dev   - Runtime core + database + UI"
        echo "  ops   - Runtime core + database + monitoring + logging"
        echo "  full  - All services"
        echo ""
        echo "Components:"
        echo "  runtime-core  - Ollama and LLM-Council"
        echo "  database      - PostgreSQL and pgAdmin"
        echo "  monitoring    - Prometheus, Grafana, exporters"
        echo "  logging       - Loki and Promtail"
        echo "  ui            - Open WebUI"
        echo "  automation    - Watchtower"
        echo "  api           - LLM-Council API endpoints"
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
        echo "  core  - Runtime core services only (ollama, llm-council)"
        echo "  dev   - Runtime core + database + UI (for development)"
        echo "  ops   - Runtime core + database + monitoring + logging (for operations)"
        echo "  full  - All services (complete stack)"
        echo ""
        echo "Components:"
        echo "  runtime-core  - Ollama and LLM-Council"
        echo "  database      - PostgreSQL and pgAdmin"
        echo "  monitoring    - Prometheus, Grafana, exporters"
        echo "  logging       - Loki and Promtail"
        echo "  ui            - Open WebUI"
        echo "  automation    - Watchtower"
        echo "  api           - LLM-Council API endpoints"
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
                test_api_endpoints
                test_council_members
                ;;
            database)
                test_component_database
                test_database_connection
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
            api)
                test_api_endpoints
                ;;
            *)
                echo "Error: Unknown component: $test_component" >&2
                echo "Valid components: runtime-core, database, monitoring, logging, ui, automation, api" >&2
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
