#!/usr/bin/env bash
# Main Test Runner for AIXCL Platform Tests
# Runs all tests sequentially, stops on first failure

set -u

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SCRIPT_DIR

# Source utilities
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"
source "${SCRIPT_DIR}/tests/lib/state-capture.sh"
source "${SCRIPT_DIR}/tests/lib/cleanup.sh"

# Configuration
TEST_DIR="${SCRIPT_DIR}/tests"
REPORT_FILE="${TEST_DIR}/test-results.md"
RUN_START_TIME=$(date +%s)

# Command line options
CATEGORY=""
SPECIFIC_TEST=""
DRY_RUN=false
QUICK_MODE=false
SHOW_HELP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --test)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Show help
if [[ "$SHOW_HELP" == true ]]; then
    cat << 'EOF'
AIXCL Platform Test Runner

Usage: ./tests/run-tests.sh [OPTIONS]

Options:
    --category <category>   Run only tests from category (command|workflow)
    --test <test-file>      Run specific test file
    --dry-run                Show what would run without executing
    --quick                  Skip slow tests (model downloads)
    --help, -h               Show this help

Examples:
    ./tests/run-tests.sh                     # Run all tests
    ./tests/run-tests.sh --category command  # Run only command tests
    ./tests/run-tests.sh --test test-03-engine-set-ollama.sh  # Run specific test
    ./tests/run-tests.sh --dry-run           # Preview test execution

Categories:
    command      - CLI command validation tests
    workflow     - README Quick Start workflow test

Notes:
    - Tests run sequentially and stop on first failure
    - Each test cleans up after itself
    - Results are written to tests/test-results.md (overwritten each run)
    - vLLM tests auto-skip if no GPU detected
EOF
    exit 0
fi

# Discover tests
discover_tests() {
    local tests=()
    
    if [[ -n "$SPECIFIC_TEST" ]]; then
        # Run specific test
        if [[ -f "${TEST_DIR}/command-tests/${SPECIFIC_TEST}" ]]; then
            tests+=("${TEST_DIR}/command-tests/${SPECIFIC_TEST}")
        elif [[ -f "${TEST_DIR}/workflow-tests/${SPECIFIC_TEST}" ]]; then
            tests+=("${TEST_DIR}/workflow-tests/${SPECIFIC_TEST}")
        else
            log_error "Test not found: $SPECIFIC_TEST"
            exit 1
        fi
    else
        # Discover by category
        if [[ -z "$CATEGORY" ]] || [[ "$CATEGORY" == "command" ]]; then
            for test in "${TEST_DIR}/command-tests"/test-*.sh; do
                if [[ -f "$test" ]]; then
                    if [[ "$QUICK_MODE" == true ]] && [[ "$test" == *"models-add"* ]]; then
                        echo "Skipping slow test: $(basename "$test") (--quick mode)" >&2
                        continue
                    fi
                    tests+=("$test")
                fi
            done
        fi
        
        if [[ -z "$CATEGORY" ]] || [[ "$CATEGORY" == "workflow" ]]; then
            for test in "${TEST_DIR}/workflow-tests"/test-*.sh; do
                [[ -f "$test" ]] && tests+=("$test")
            done
        fi
    fi
    
    echo "${tests[@]}"
}

# Run a single test
run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)
    
    log_test_start "$test_name"
    
    # Execute the test
    if bash "$test_file" 2>&1; then
        log_test_pass "All assertions passed"
        return 0
    else
        local exit_code=$?
        log_test_fail "Test exited with code $exit_code"
        return $exit_code
    fi
}

# Main execution
echo "=========================================="
echo "AIXCL Platform Test Suite"
echo "=========================================="
echo ""

# Clean up old backup files before starting
log_info "Cleaning up old test backup files..."
if [[ -d "${SCRIPT_DIR}/tests/.backup" ]]; then
    # Remove backup directories older than 1 day (to preserve recent runs but clean up cruft)
    find "${SCRIPT_DIR}/tests/.backup" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
    # Count remaining backups
    backup_count=$(find "${SCRIPT_DIR}/tests/.backup" -type d | wc -l)
    log_info "Backup directory cleaned. Current backups: $((backup_count - 1))"
fi

# Pre-flight check
echo "Running pre-flight check..."
if [[ "$DRY_RUN" == false ]]; then
    if ! "$AIXCL_BIN" utils check-env > /dev/null 2>&1; then
        log_error "Pre-flight check failed. Run './aixcl utils check-env' for details."
        exit 1
    fi
    log_success "Pre-flight check passed"
else
    log_info "[DRY RUN] Would run: ./aixcl utils check-env"
fi

echo ""

# Discover tests
# shellcheck disable=SC2207
TESTS=($(discover_tests))

if [[ ${#TESTS[@]} -eq 0 ]]; then
    log_error "No tests found"
    exit 1
fi

# Show what will run
echo "Discovered ${#TESTS[@]} test(s):"
for test in "${TESTS[@]}"; do
    echo "  - $(basename "$test")"
done
echo ""

# Dry run exit
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run complete. No tests executed."
    exit 0
fi

# Run tests sequentially
FAILED=false
for test in "${TESTS[@]}"; do
    if ! run_test "$test"; then
        FAILED=true
        break
    fi
    
    # Cleanup between tests
    cleanup_old_backups 20
done

# Generate report
generate_report "$REPORT_FILE" "$RUN_START_TIME"

# Print summary
echo ""
print_summary

# Show report location
echo ""
echo "Full report written to: $REPORT_FILE"

# Exit with appropriate code
if [[ "$FAILED" == true ]]; then
    exit 1
else
    exit 0
fi
