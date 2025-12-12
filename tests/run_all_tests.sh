#!/usr/bin/env bash
# Run all test suites

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Running All AIXCL Tests"
echo "=========================================="
echo ""

# Run baseline tests
echo "1. Running Baseline Tests..."
echo "-----------------------------------"
bash "${SCRIPT_DIR}/test_baseline.sh"
BASELINE_RESULT=$?

echo ""
echo ""

# Run API endpoint tests (only if services might be running)
echo "2. Running API Endpoint Tests..."
echo "-----------------------------------"
bash "${SCRIPT_DIR}/test_api_endpoints.sh"
API_RESULT=$?

echo ""
echo ""

# Summary
echo "=========================================="
echo "Overall Test Summary"
echo "=========================================="

if [ $BASELINE_RESULT -eq 0 ] && [ $API_RESULT -eq 0 ]; then
    echo "All test suites passed!"
    exit 0
else
    echo "Some test suites failed:"
    [ $BASELINE_RESULT -ne 0 ] && echo "  - Baseline tests failed"
    [ $API_RESULT -ne 0 ] && echo "  - API endpoint tests failed"
    exit 1
fi
