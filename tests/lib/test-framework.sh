#!/usr/bin/env bash
# Test Framework for AIXCL Platform Tests
# Provides assertions, logging, and reporting utilities

set -u

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=""
TEST_START_TIME=""
TEST_RESULTS=()

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AIXCL_BIN="${SCRIPT_DIR}/aixcl"

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_test_start() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    TEST_START_TIME=$(date +%s.%N)
    echo ""
    echo "=========================================="
    echo "Running: $test_name"
    echo "=========================================="
}

log_test_pass() {
    local message="${1:-}"
    local duration
    duration=$(get_test_duration)
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TEST_RESULTS+=("PASS|$CURRENT_TEST|$message|$duration")
    log_success "Test passed ($duration)"
    if [[ -n "$message" ]]; then
        echo "  $message"
    fi
}

log_test_fail() {
    local message="$1"
    local duration
    duration=$(get_test_duration)
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TEST_RESULTS+=("FAIL|$CURRENT_TEST|$message|$duration")
    log_error "Test failed ($duration)"
    echo "  $message"
}

log_test_skip() {
    local reason="$1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    TEST_RESULTS+=("SKIP|$CURRENT_TEST|$reason|0")
    log_warn "Test skipped: $reason"
}

get_test_duration() {
    if [[ -n "$TEST_START_TIME" ]]; then
        local end_time
        end_time=$(date +%s.%N)
        printf "%.1fs" "$(echo "$end_time - $TEST_START_TIME" | bc)"
    else
        echo "N/A"
    fi
}

# ============================================================================
# Assertion Functions
# ============================================================================

assert_command_success() {
    local cmd="$1"
    local description="${2:-Command: $cmd}"
    
    log_info "Executing: $cmd"
    if eval "$cmd" > /tmp/test_output.log 2>&1; then
        log_success "$description"
        return 0
    else
        log_error "$description"
        if [[ -s /tmp/test_output.log ]]; then
            echo "  Output:"
            head -5 /tmp/test_output.log | sed 's/^/    /'
        fi
        return 1
    fi
}

assert_command_fail() {
    local cmd="$1"
    local description="${2:-Command should fail: $cmd}"
    
    log_info "Executing (expecting failure): $cmd"
    if eval "$cmd" > /tmp/test_output.log 2>&1; then
        log_error "$description"
        return 1
    else
        log_success "$description"
        return 0
    fi
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log_success "File exists: $file"
        return 0
    else
        log_error "File not found: $file"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
        log_success "File $file contains: $pattern"
        return 0
    else
        log_error "File $file does not contain: $pattern"
        return 1
    fi
}

assert_env_equals() {
    local var="$1"
    local expected="$2"
    local file="${SCRIPT_DIR}/.env"
    
    if [[ -f "$file" ]]; then
        local actual
        actual=$(grep "^${var}=" "$file" | cut -d'=' -f2- || echo "")
        if [[ "$actual" == "$expected" ]]; then
            log_success "Environment $var=$expected"
            return 0
        else
            log_error "Environment $var: expected '$expected', got '$actual'"
            return 1
        fi
    else
        log_error ".env file not found"
        return 1
    fi
}

assert_container_running() {
    local container="$1"
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log_success "Container running: $container"
        return 0
    else
        log_error "Container not running: $container"
        return 1
    fi
}

assert_container_healthy() {
    local container="$1"
    local status
    status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
    
    if [[ "$status" == "healthy" ]]; then
        log_success "Container healthy: $container"
        return 0
    else
        log_error "Container not healthy: $container (status: $status)"
        return 1
    fi
}

assert_api_responds() {
    local url="$1"
    local timeout="${2:-30}"
    
    log_info "Checking API: $url (timeout: ${timeout}s)"
    if curl -sf "$url" --max-time "$timeout" > /dev/null 2>&1; then
        log_success "API responds: $url"
        return 0
    else
        log_error "API not responding: $url"
        return 1
    fi
}

assert_port_listening() {
    local port="$1"
    if ss -tuln | grep -q ":$port "; then
        log_success "Port listening: $port"
        return 0
    else
        log_error "Port not listening: $port"
        return 1
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

has_nvidia_gpu() {
    if command -v nvidia-smi > /dev/null 2>&1 && nvidia-smi > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

get_engine_container() {
    local engine="$1"
    case "$engine" in
        ollama) echo "ollama" ;;
        vllm) echo "vllm" ;;
        llamacpp) echo "llamacpp" ;;
        *) echo "" ;;
    esac
}

wait_for_container() {
    local container="$1"
    local max_wait="${2:-60}"
    local waited=0
    
    log_info "Waiting for container: $container (max ${max_wait}s)"
    while [[ $waited -lt $max_wait ]]; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            log_success "Container ready: $container"
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
        echo -n "."
    done
    echo ""
    log_error "Timeout waiting for container: $container"
    return 1
}

wait_for_api() {
    local url="$1"
    local max_wait="${2:-60}"
    local waited=0
    
    log_info "Waiting for API: $url (max ${max_wait}s)"
    while [[ $waited -lt $max_wait ]]; do
        if curl -sf "$url" --max-time 5 > /dev/null 2>&1; then
            log_success "API ready: $url"
            return 0
        fi
        sleep 2
        waited=$((waited + 2))
        echo -n "."
    done
    echo ""
    log_error "Timeout waiting for API: $url"
    return 1
}

# ============================================================================
# Summary Functions
# ============================================================================

print_summary() {
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo ""
    echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:  $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

generate_report() {
    local report_file="$1"
    local start_time="$2"
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    cat > "$report_file" << EOF
# AIXCL Platform Test Results

**Generated**: $(date -Iseconds)  
**Total Duration**: ${total_duration}s  
**Status**: $(if [[ $TESTS_FAILED -eq 0 ]]; then echo "✅ PASSED"; else echo "❌ FAILED"; fi)

## Summary

| Metric | Count |
|--------|-------|
| Passed | $TESTS_PASSED |
| Failed | $TESTS_FAILED |
| Skipped | $TESTS_SKIPPED |
| **Total** | **$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))** |

## Detailed Results

| Status | Test | Message | Duration |
|--------|------|---------|----------|
EOF

    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r status test message duration <<< "$result"
        echo "| $status | $test | $message | $duration |" >> "$report_file"
    done
    
    {
        echo ""
        echo "---"
        echo ""
        echo "*Report generated by AIXCL Test Suite*"
    } >> "$report_file"
}

export -f log_info log_success log_error log_warn
export -f log_test_start log_test_pass log_test_fail log_test_skip
export -f assert_command_success assert_command_fail
export -f assert_file_exists assert_file_contains
export -f assert_env_equals assert_container_running
export -f assert_container_healthy assert_api_responds assert_port_listening
export -f has_nvidia_gpu get_engine_container wait_for_container wait_for_api
export -f print_summary generate_report

export SCRIPT_DIR AIXCL_BIN
export RED GREEN YELLOW BLUE NC
export TESTS_PASSED TESTS_FAILED TESTS_SKIPPED
