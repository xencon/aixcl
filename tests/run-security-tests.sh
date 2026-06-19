#!/usr/bin/env bash
# Run all security tests -- used by pre-push hook and CI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running security tests..."
for test in "${SCRIPT_DIR}/security/"*.sh; do
    echo "  $test"
    bash "$test" || exit 1
done
echo "All security tests passed."
