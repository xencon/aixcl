#!/bin/bash
# Wrapper script to run performance test with automatic venv setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
TEST_SCRIPT="$SCRIPT_DIR/test_performance_user.py"

# Check if httpx is available
if python3 -c "import httpx" 2>/dev/null; then
    echo "httpx is available - running test directly"
    python3 "$TEST_SCRIPT"
    exit $?
fi

# httpx not available - set up venv
echo "httpx not found. Setting up virtual environment..."

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate venv
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Install httpx if not installed
if ! python -c "import httpx" 2>/dev/null; then
    echo "Installing httpx..."
    pip install httpx
fi

# Run test
echo "Running performance test..."
python "$TEST_SCRIPT"

# Exit code from test
exit $?

