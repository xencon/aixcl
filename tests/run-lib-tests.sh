#!/usr/bin/env bash
# Run library unit tests -- used by pre-push hook and CI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec bash "${SCRIPT_DIR}/run-tests.sh" --category lib
