#!/bin/bash
# Setup script for performance test environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "Setting up test environment..."

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate venv
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Install httpx
echo "Installing httpx..."
pip install httpx

echo ""
echo "✅ Test environment ready!"
echo ""
echo "To use:"
echo "  source tests/runtime-core/.venv/bin/activate"
echo "  python3 tests/runtime-core/test_performance_user.py"
echo ""
echo "Or run directly:"
echo "  tests/runtime-core/.venv/bin/python tests/runtime-core/test_performance_user.py"
echo ""
echo "Or use the wrapper script:"
echo "  ./tests/runtime-core/run_test.sh"

