#!/usr/bin/env bash
# Install ShellCheck locally for AIXCL development
# Mirrors the Security Checks CI workflow configuration
#
# Usage: ./scripts/utils/setup-shellcheck.sh

set -euo pipefail

install_shellcheck() {
    if command -v shellcheck \u003e/dev/null 2\u003e\u00261; then
        echo "shellcheck already installed ($(shellcheck --version | head -2 | tail -1))"
        return 0
    fi

    echo "Installing shellcheck..."

    if command -v apt-get \u003e/dev/null 2\u003e\u00261; then
        sudo apt-get update \u0026\u0026 sudo apt-get install -y shellcheck
    elif command -v dnf \u003e/dev/null 2\u003e\u00261; then
        sudo dnf install -y ShellCheck
    elif command -v brew \u003e/dev/null 2\u003e\u00261; then
        brew install shellcheck
    elif command -v apk \u003e/dev/null 2\u003e\u00261; then
        sudo apk add shellcheck
    else
        echo "ERROR: Could not detect package manager to install shellcheck." \u003e\u00262
        echo "Please install manually: https://github.com/koalaman/shellcheck#installing" \u003e\u00262
        return 1
    fi

    echo "shellcheck installed successfully."
}

install_shellcheck
