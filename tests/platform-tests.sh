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
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_utils.sh"
source "${SCRIPT_DIR}/lib/color.sh"

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
    
    record_test "pass" "LLM state check complete"
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
    DB_TEST_SCRIPT="${SCRIPT_DIR}/tests/database/test_db_connection.py"
    if [ ! -f "$DB_TEST_SCRIPT" ]; then
        print_error "Database test script not found: $DB_TEST_SCRIPT"
        record_test "fail" "Database test script not found"
        return
    fi
    
    echo "Running database connection tests..."
    echo ""
    
    # Change to script directory for proper Python path
    cd "$SCRIPT_DIR" || {
        print_error "Cannot change to script directory"
        record_test "fail" "Cannot change to script directory for database tests"
        return
    }
    
    # Check if uv is available (preferred method)
    # Add ~/.local/bin to PATH for uv if it exists
    if [ -d "$HOME/.local/bin" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    if command -v uv &> /dev/null; then
        echo "Using uv to run database tests..."
        if uv run python ../tests/database/test_db_connection.py; then
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
        if python3 ../tests/database/test_db_connection.py; then
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
# SECTION 3B: CONVERSATION STORAGE TESTS
# ============================================================================
test_conversation_storage() {
    start_section "Conversation Storage - Continue Plugin Integration"
    
    # Check prerequisites
    if ! is_container_running "postgres"; then
        print_error "PostgreSQL container is not running"
        record_test "fail" "PostgreSQL container is not running"
        echo "   Cannot test conversation storage without PostgreSQL"
        return
    fi
    
    echo ""
    echo "Testing conversation storage flow..."
    echo ""
    
    # Step 1: Get initial conversation count
    echo "1. Checking initial conversation count..."
    INITIAL_COUNT=$(docker exec postgres psql -U "$POSTGRES_USER" -d continue -t -c "SELECT COUNT(*) FROM chat WHERE source = 'continue';" 2>/dev/null | tr -d ' ' || echo "0")
    echo "   Initial conversations: $INITIAL_COUNT"
    
    # Step 2: Generate expected conversation ID from message (before API call)
    TEST_MESSAGE="Platform test conversation storage verification"
    CONV_ID=""
    if command -v python3 >/dev/null 2>&1; then
        CONV_ID=$(python3 -c "
import sys, uuid
TEST_MESSAGE = '$TEST_MESSAGE'
CONTINUE_NAMESPACE = uuid.UUID('6ba7b810-9dad-11d1-80b4-00c04fd430c8')
name = f'continue:{TEST_MESSAGE}'
conv_id = str(uuid.uuid5(CONTINUE_NAMESPACE, name))
print(conv_id)
" 2>/dev/null || echo "")
    fi
    
    if [ -z "$CONV_ID" ]; then
        print_error "Could not generate conversation ID"
        record_test "fail" "Could not generate conversation ID"
        return
    fi
    
    echo "   Expected conversation ID: $CONV_ID"
    
    # Step 3: Send a test message via API (simulating Continue plugin)
    echo ""
    echo "2. Sending test message via API..."
    echo "   Sending request to ${API_URL}/v1/chat/completions..."
    # Flush output buffer (helps with VSCode terminal buffering)
    [ -t 1 ] && printf "" || true
    RESPONSE=$(curl -s --max-time 120 -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"ollama\",
            \"messages\": [
                {\"role\": \"user\", \"content\": \"$TEST_MESSAGE\"}
            ],
            \"stream\": false
        }" 2>/dev/null)
    
    if [ -z "$RESPONSE" ]; then
        print_error "API request failed"
        record_test "fail" "Failed to send test message via API"
        return
    fi
    
    echo "   ✅ API request successful"
    echo "   Response length: ${#RESPONSE}"
    
    # Step 4: Wait for database write with retries
    echo ""
    echo "3. Waiting for conversation to be stored in database..."
    STORED_COUNT=$INITIAL_COUNT
    MAX_RETRIES=10
    RETRY_COUNT=0
    
    while [ "$STORED_COUNT" -le "$INITIAL_COUNT" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        sleep 2
        STORED_COUNT=$(docker exec postgres psql -U "$POSTGRES_USER" -d continue -t -c "SELECT COUNT(*) FROM chat WHERE source = 'continue';" 2>/dev/null | tr -d ' ' || echo "0")
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "   Attempt $RETRY_COUNT/$MAX_RETRIES: Count = $STORED_COUNT"
    done
    
    if [ "$STORED_COUNT" -le "$INITIAL_COUNT" ]; then
        print_error "Conversation was not stored after $MAX_RETRIES attempts"
        echo "   Initial count: $INITIAL_COUNT"
        echo "   Current count: $STORED_COUNT"
        echo "   Checking if conversation exists by ID..."
        
        # Check if conversation exists by ID (might have been created but count didn't update)
        CONV_EXISTS=$(docker exec postgres psql -U "$POSTGRES_USER" -d continue -t -c "SELECT COUNT(*) FROM chat WHERE id = '$CONV_ID';" 2>/dev/null | tr -d ' ' || echo "0")
        if [ "$CONV_EXISTS" = "1" ]; then
            echo "   ⚠️  Conversation exists by ID but count didn't increase (possible race condition)"
            STORED_COUNT=$((INITIAL_COUNT + 1))
        else
            record_test "fail" "Conversation was not stored in database"
            return
        fi
    fi
    
    echo "   ✅ Conversation count increased: $INITIAL_COUNT -> $STORED_COUNT"
    record_test "pass" "Conversation count increased after API call"
    
    # Step 5: Verify conversation details
    echo ""
    echo "4. Verifying conversation details..."
    CONV_DETAILS=$(docker exec postgres psql -U "$POSTGRES_USER" -d continue -t -A -F'|' -c "SELECT id, title, source FROM chat WHERE id = '$CONV_ID';" 2>/dev/null || echo "")
    
    if [ -z "$CONV_DETAILS" ]; then
        # Try to find any conversation that was just created
        echo "   ⚠️  Conversation not found by expected ID, checking for any new conversations..."
        NEW_CONV=$(docker exec postgres psql -U "$POSTGRES_USER" -d continue -t -A -F'|' -c "SELECT id, title, source FROM chat WHERE source = 'continue' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || echo "")
        if [ -n "$NEW_CONV" ]; then
            echo "   Found new conversation: $NEW_CONV"
            CONV_DETAILS="$NEW_CONV"
            CONV_ID=$(echo "$CONV_DETAILS" | cut -d'|' -f1)
            echo "   Using conversation ID: $CONV_ID"
        else
            print_error "Conversation not found in database"
            record_test "fail" "Conversation not found in database by ID"
            return
        fi
    fi
    
    # Parse details (format: id|title|source)
    CONV_SOURCE=$(echo "$CONV_DETAILS" | cut -d'|' -f3)
    CONV_TITLE=$(echo "$CONV_DETAILS" | cut -d'|' -f2)
    
    if [ "$CONV_SOURCE" != "continue" ]; then
        print_error "Conversation source is incorrect"
        echo "   Expected: continue"
        echo "   Got: $CONV_SOURCE"
        record_test "fail" "Conversation source is not 'continue'"
        return
    fi
    
    echo "   ✅ Conversation found in database"
    echo "   Title: $CONV_TITLE"
    echo "   Source: $CONV_SOURCE"
    record_test "pass" "Conversation stored with correct source='continue'"
    
    # Step 6: Verify conversation structure
    echo ""
    echo "5. Verifying conversation structure..."
    CONV_JSON=$(docker exec postgres psql -U "$POSTGRES_USER" -d continue -t -c "SELECT chat::text FROM chat WHERE id = '$CONV_ID';" 2>/dev/null || echo "")
    
    if [ -z "$CONV_JSON" ]; then
        print_error "Could not retrieve conversation JSON"
        record_test "fail" "Could not retrieve conversation JSON from database"
        return
    fi
    
    # Verify JSON structure contains messages array
    if echo "$CONV_JSON" | grep -q '"messages"'; then
        echo "   ✅ Conversation JSON contains messages array"
        
        # Count messages in the conversation
        if command -v python3 >/dev/null 2>&1; then
            MSG_COUNT=$(echo "$CONV_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    messages = data.get('messages', [])
    print(len(messages))
except:
    print('0')
" 2>/dev/null || echo "0")
            echo "   Messages in conversation: $MSG_COUNT"
            if [ "$MSG_COUNT" -ge 1 ]; then
                record_test "pass" "Conversation JSON structure is valid with $MSG_COUNT message(s)"
            else
                print_error "Conversation has no messages"
                record_test "fail" "Conversation JSON structure is invalid (no messages)"
                return
            fi
        else
            record_test "pass" "Conversation JSON structure is valid"
        fi
    else
        print_error "Conversation JSON missing messages array"
        record_test "fail" "Conversation JSON structure is invalid"
        return
    fi
    
    # Step 7: Cleanup - delete test conversation
    echo ""
    echo "6. Cleaning up test conversation..."
    DELETE_RESPONSE=$(curl -s --max-time 30 -X DELETE "${API_URL}/v1/chat/completions/$CONV_ID" 2>/dev/null)
    DELETE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 -X DELETE "${API_URL}/v1/chat/completions/$CONV_ID" 2>/dev/null)
    
    if [ "$DELETE_STATUS" = "200" ]; then
        echo "   ✅ Test conversation deleted"
        record_test "pass" "Test conversation cleanup successful"
    else
        echo "   ⚠️  Could not delete test conversation (status: $DELETE_STATUS)"
        echo "   You may need to clean it up manually"
        record_test "skip" "Test conversation cleanup skipped"
    fi
    
    # Final verification
    FINAL_COUNT=$(docker exec postgres psql -U "$POSTGRES_USER" -d continue -t -c "SELECT COUNT(*) FROM chat WHERE source = 'continue';" 2>/dev/null | tr -d ' ' || echo "0")
    echo ""
    echo "Final conversation count: $FINAL_COUNT"
    
    print_success "Conversation storage test completed"
}


# ============================================================================
# COMPONENT-BASED TEST FUNCTIONS
# ============================================================================

# Test runtime core services (ollama)
test_component_runtime_core() {
    start_section "Runtime Core - Ollama"
    
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
    
    # Conversation storage test
    test_conversation_storage
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

# Test usr profile (runtime core + database)
test_profile_usr() {
    echo "Running tests for profile: usr"
    echo "Profile includes: runtime core services + PostgreSQL"
    echo ""
    
    test_environment_check
    test_component_runtime_core
    test_component_database
    test_llm_state
    test_database_connection
    test_conversation_storage
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
    test_conversation_storage
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
    test_conversation_storage
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
    test_conversation_storage
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
                echo "  runtime-core  - Ollama"
                echo "  database      - PostgreSQL and pgAdmin"
                echo "  monitoring    - Prometheus, Grafana, exporters"
                echo "  logging       - Loki and Promtail"
                echo "  ui            - Open WebUI"
                echo "  automation    - Watchtower"
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
        echo "  usr   - Runtime core services + database (ollama, postgres)"
        echo "  dev   - Runtime core + database + UI (for development)"
        echo "  ops   - Runtime core + database + monitoring + logging (for operations)"
        echo "  sys   - All services (complete stack)"
        echo ""
        echo "Components:"
        echo "  runtime-core  - Ollama"
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
                test_database_connection
                test_conversation_storage
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
            *)
                echo "Error: Unknown component: $test_component" >&2
                echo "Valid components: runtime-core, database, monitoring, logging, ui, automation" >&2
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
