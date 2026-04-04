#!/usr/bin/env bash
# Unit tests for lib/core/color.sh

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the library under test
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/core/color.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
assert_true() {
    local condition="$1"
    local message="$2"
    
    if eval "$condition"; then
        echo "✓ PASS: $message"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: $message"
        ((TESTS_FAILED++))
    fi
}

# Test: Colors are defined
test_colors_defined() {
    assert_true '[ -n "$RED" ]' "RED color is defined"
    assert_true '[ -n "$GREEN" ]' "GREEN color is defined"
    assert_true '[ -n "$YELLOW" ]' "YELLOW color is defined"
    assert_true '[ -n "$BLUE" ]' "BLUE color is defined"
    assert_true '[ -n "$NC" ]' "NC (no color) is defined"
}

# Test: Icons are defined
test_icons_defined() {
    assert_true '[ -n "$ICON_SUCCESS" ]' "ICON_SUCCESS is defined"
    assert_true '[ -n "$ICON_ERROR" ]' "ICON_ERROR is defined"
    assert_true '[ -n "$ICON_WARNING" ]' "ICON_WARNING is defined"
    assert_true '[ -n "$ICON_INFO" ]' "ICON_INFO is defined"
}

# Test: Print functions exist
test_print_functions_exist() {
    assert_true 'type -t print_success | grep -q function' "print_success function exists"
    assert_true 'type -t print_error | grep -q function' "print_error function exists"
    assert_true 'type -t print_warning | grep -q function' "print_warning function exists"
    assert_true 'type -t print_info | grep -q function' "print_info function exists"
}

# Run tests
echo "=========================================="
echo "Unit Tests: lib/core/color.sh"
echo "=========================================="
echo ""

test_colors_defined
test_icons_defined
test_print_functions_exist

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "=========================================="

exit $TESTS_FAILED
