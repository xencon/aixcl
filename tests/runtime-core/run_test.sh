#!/bin/bash
# Main entry point for running performance tests with benchmarking metrics
# This script handles venv setup and passes all arguments to the Python test script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
TEST_SCRIPT="$SCRIPT_DIR/test_council_performance.py"

# Store all arguments to pass to Python script
ARGS=("$@")

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run performance tests for Ollama optimizations with benchmarking metrics.

Options:
    --warmup              Warm up models before benchmarking (recommended)
    --csv [FILE]          Export results to CSV file
                          If FILE is not specified, uses default: benchmark_YYYYMMDD_HHMMSS.csv
    --no-warmup           Explicitly disable warmup (default behavior)
    -h, --help            Show this help message

Examples:
    # Basic test (backward compatible)
    $0
    
    # With warmup
    $0 --warmup
    
    # Export to CSV
    $0 --csv benchmark.csv
    
    # Both warmup and CSV export
    $0 --warmup --csv benchmark.csv
    
    # CSV with default filename
    $0 --csv

EOF
}

# Check for help flag
if [[ " ${ARGS[@]} " =~ " --help " ]] || [[ " ${ARGS[@]} " =~ " -h " ]]; then
    show_usage
    exit 0
fi

# Check if httpx is available
if python3 -c "import httpx" 2>/dev/null; then
    echo "httpx is available - running test directly"
    python3 "$TEST_SCRIPT" "${ARGS[@]}"
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
    pip install httpx --quiet
fi

# Run test with all arguments
echo "Running performance test..."
python "$TEST_SCRIPT" "${ARGS[@]}"

# Exit code from test
exit $?

