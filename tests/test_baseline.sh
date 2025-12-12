#!/usr/bin/env bash
# Baseline test suite for AIXCL refactoring
# Tests all commands and functionality to establish a working baseline

set -e
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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIXCL="${SCRIPT_DIR}/aixcl.sh"

# Test result tracking
test_results=()

# Helper functions
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
    test_results+=("PASS: $1")
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    test_results+=("FAIL: $1")
}

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
    test_results+=("SKIP: $1")
}

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    print_test "$test_name"
    # Use a subshell to prevent variable leakage and ensure clean execution
    if (eval "$test_command" >/dev/null 2>&1); then
        print_pass "$test_name"
        return 0
    else
        print_fail "$test_name"
        return 1
    fi
}

# Check if command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Check if file exists
check_file() {
    [ -f "$1" ]
}

# Check if directory exists
check_dir() {
    [ -d "$1" ]
}

echo "=========================================="
echo "AIXCL Baseline Test Suite"
echo "=========================================="
echo ""

# ============================================
# Phase 1: Structure and File Checks
# ============================================
echo "Phase 1: Structure and File Checks"
echo "-----------------------------------"

run_test "Main entry point exists" "test -f '${AIXCL}'"
run_test "Main entry point is executable" "test -x '${AIXCL}'"

# Check library files
for lib in common.sh docker_utils.sh color.sh logging.sh env_check.sh; do
    run_test "Library file exists: lib/$lib" "check_file ${SCRIPT_DIR}/lib/$lib"
    run_test "Library file is executable: lib/$lib" "[ -x ${SCRIPT_DIR}/lib/$lib ]"
done

# Check CLI modules
for cli in stack.sh service.sh models.sh dashboard.sh utils.sh; do
    run_test "CLI module exists: cli/$cli" "check_file ${SCRIPT_DIR}/cli/$cli"
    run_test "CLI module is executable: cli/$cli" "[ -x ${SCRIPT_DIR}/cli/$cli ]"
done

# Check docker compose files
for compose in docker-compose.yml docker-compose.arm.yml docker-compose.gpu.yml; do
    run_test "Docker compose file exists: services/$compose" "check_file ${SCRIPT_DIR}/services/$compose"
done

run_test "Completion script exists" "check_file ${SCRIPT_DIR}/completion/aixcl.bash"

echo ""

# ============================================
# Phase 2: Command Help and Validation
# ============================================
echo "Phase 2: Command Help and Validation"
echo "-----------------------------------"

run_test "Main help command works" "${AIXCL} help"
run_test "Stack help shows usage" "${AIXCL} stack" 2>&1 | grep -q "subcommand"
run_test "Service help shows usage" "${AIXCL} service" 2>&1 | grep -q "required"
run_test "Models help shows usage" "${AIXCL} models" 2>&1 | grep -q "required"
run_test "Dashboard help shows usage" "${AIXCL} dashboard" 2>&1 | grep -q "required"
run_test "Utils help shows usage" "${AIXCL} utils" 2>&1 | grep -q "required"

echo ""

# ============================================
# Phase 3: Environment Check
# ============================================
echo "Phase 3: Environment Check"
echo "-----------------------------------"

if check_command docker; then
    run_test "Docker is installed" "check_command docker"
    run_test "Docker daemon is accessible" "docker info >/dev/null 2>&1"
else
    print_skip "Docker checks (Docker not installed)"
fi

if check_command docker-compose; then
    run_test "Docker Compose is installed" "check_command docker-compose"
else
    print_skip "Docker Compose checks (not installed)"
fi

run_test "Environment check command works" "${AIXCL} utils check-env" 2>&1 | head -5 | grep -q "Checking"

echo ""

# ============================================
# Phase 4: Stack Status (No Services Running)
# ============================================
echo "Phase 4: Stack Status (No Services)"
echo "-----------------------------------"

run_test "Stack status command works" "${AIXCL} stack status" 2>&1 | grep -q "Checking services status"

echo ""

# ============================================
# Phase 5: Service Validation
# ============================================
echo "Phase 5: Service Validation"
echo "-----------------------------------"

# Test service command with invalid service
run_test "Service command validates service names" "${AIXCL} service start invalid-service" 2>&1 | grep -q "Unknown service"

# Test service command with missing arguments
run_test "Service command requires action" "${AIXCL} service" 2>&1 | grep -q "required"

echo ""

# ============================================
# Phase 6: Models Command (No Ollama Running)
# ============================================
echo "Phase 6: Models Command (No Ollama)"
echo "-----------------------------------"

run_test "Models list handles no Ollama gracefully" "${AIXCL} models list" 2>&1 | grep -q "not running"

echo ""

# ============================================
# Phase 7: Dashboard Commands
# ============================================
echo "Phase 7: Dashboard Commands"
echo "-----------------------------------"

run_test "Dashboard grafana handles no service" "${AIXCL} dashboard grafana" 2>&1 | grep -q "not running"
run_test "Dashboard openwebui handles no service" "${AIXCL} dashboard openwebui" 2>&1 | grep -q "not running"
run_test "Dashboard pgadmin handles no service" "${AIXCL} dashboard pgadmin" 2>&1 | grep -q "not running"

echo ""

# ============================================
# Phase 8: Library Function Tests
# ============================================
echo "Phase 8: Library Function Tests"
echo "-----------------------------------"

# Test that libraries can be sourced
run_test "Common library can be sourced" "source ${SCRIPT_DIR}/lib/common.sh && is_valid_service ollama"
run_test "Docker utils library can be sourced" "source ${SCRIPT_DIR}/lib/docker_utils.sh && set_compose_cmd"
run_test "Color library can be sourced" "source ${SCRIPT_DIR}/lib/color.sh && print_success 'test'"

echo ""

# ============================================
# Phase 9: Docker Compose File Validation
# ============================================
echo "Phase 9: Docker Compose File Validation"
echo "-----------------------------------"

if check_command docker-compose; then
    run_test "Main compose file is valid" "cd ${SCRIPT_DIR}/services && docker-compose -f docker-compose.yml config >/dev/null 2>&1"
    run_test "ARM compose file is valid" "cd ${SCRIPT_DIR}/services && docker-compose -f docker-compose.yml -f docker-compose.arm.yml config >/dev/null 2>&1"
    run_test "GPU compose file is valid" "cd ${SCRIPT_DIR}/services && docker-compose -f docker-compose.yml -f docker-compose.gpu.yml config >/dev/null 2>&1"
else
    print_skip "Docker Compose validation (docker-compose not available)"
fi

echo ""

# ============================================
# Phase 10: Error Handling
# ============================================
echo "Phase 10: Error Handling"
echo "-----------------------------------"

run_test "Invalid command shows error" "${AIXCL} invalid-command" 2>&1 | grep -q "Unknown command"
run_test "Invalid stack subcommand shows error" "${AIXCL} stack invalid" 2>&1 | grep -q "Unknown"
run_test "Invalid service action shows error" "${AIXCL} service invalid postgres" 2>&1 | grep -q "Unknown"

echo ""

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Review output above.${NC}"
    echo ""
    echo "Failed tests:"
    for result in "${test_results[@]}"; do
        if [[ "$result" == FAIL:* ]]; then
            echo "  - $result"
        fi
    done
    exit 1
fi
