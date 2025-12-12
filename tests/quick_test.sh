#!/usr/bin/env bash
# Quick test to verify basic functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AIXCL="${SCRIPT_DIR}/aixcl.sh"

echo "Quick Baseline Test"
echo "==================="
echo ""

# Test 1: File exists
echo "Test 1: Main script exists"
if [ -f "$AIXCL" ]; then
    echo "✅ PASS: aixcl.sh exists"
else
    echo "❌ FAIL: aixcl.sh not found"
    exit 1
fi

# Test 2: Script is executable
echo "Test 2: Main script is executable"
if [ -x "$AIXCL" ]; then
    echo "✅ PASS: aixcl.sh is executable"
else
    echo "❌ FAIL: aixcl.sh is not executable"
    exit 1
fi

# Test 3: Help command works
echo "Test 3: Help command works"
if "$AIXCL" help 2>&1 | grep -q "Usage"; then
    echo "✅ PASS: Help command works"
else
    echo "❌ FAIL: Help command failed"
    exit 1
fi

# Test 4: Invalid command shows error
echo "Test 4: Invalid command shows error"
if "$AIXCL" invalid-command 2>&1 | grep -q "Unknown command"; then
    echo "✅ PASS: Error handling works"
else
    echo "❌ FAIL: Error handling failed"
    exit 1
fi

# Test 5: Stack command structure
echo "Test 5: Stack command structure"
if "$AIXCL" stack 2>&1 | grep -q "subcommand"; then
    echo "✅ PASS: Stack command structure works"
else
    echo "❌ FAIL: Stack command structure failed"
    exit 1
fi

# Test 6: Library files exist
echo "Test 6: Library files exist"
missing_libs=0
for lib in common.sh docker_utils.sh color.sh logging.sh env_check.sh; do
    if [ ! -f "${SCRIPT_DIR}/lib/$lib" ]; then
        echo "❌ FAIL: Missing lib/$lib"
        missing_libs=1
    fi
done
if [ $missing_libs -eq 0 ]; then
    echo "✅ PASS: All library files exist"
fi

# Test 7: CLI modules exist
echo "Test 7: CLI modules exist"
missing_cli=0
for cli in stack.sh service.sh models.sh dashboard.sh utils.sh; do
    if [ ! -f "${SCRIPT_DIR}/cli/$cli" ]; then
        echo "❌ FAIL: Missing cli/$cli"
        missing_cli=1
    fi
done
if [ $missing_cli -eq 0 ]; then
    echo "✅ PASS: All CLI modules exist"
fi

# Test 8: Docker compose files exist
echo "Test 8: Docker compose files exist"
missing_compose=0
for compose in docker-compose.yml docker-compose.arm.yml docker-compose.gpu.yml; do
    if [ ! -f "${SCRIPT_DIR}/services/$compose" ]; then
        echo "❌ FAIL: Missing services/$compose"
        missing_compose=1
    fi
done
if [ $missing_compose -eq 0 ]; then
    echo "✅ PASS: All docker compose files exist"
fi

echo ""
echo "==================="
echo "Quick Test Complete"
echo "==================="
