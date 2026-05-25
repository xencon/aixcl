#!/usr/bin/env bash
# Install git hooks for AIXCL development
# Run once after cloning: ./scripts/utils/setup-hooks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
SCRIPTS_DIR="$REPO_ROOT/scripts/hooks"

install_hook() {
    local name="$1"
    local src="$SCRIPTS_DIR/$name"
    local dst="$HOOKS_DIR/$name"

    if [ ! -f "$src" ]; then
        echo "ERROR: Hook source not found: $src" >&2
        return 1
    fi

    cp "$src" "$dst"
    chmod +x "$dst"
    echo "Installed: $name"
}

mkdir -p "$SCRIPTS_DIR"

echo "Installing git hooks..."
install_hook pre-commit
echo "Done. Hooks installed to $HOOKS_DIR"

# Ensure ShellCheck is available
if [ -f "$REPO_ROOT/scripts/utils/setup-shellcheck.sh" ]; then
    echo ""
    echo "Checking ShellCheck..."
    bash "$REPO_ROOT/scripts/utils/setup-shellcheck.sh"
fi

echo ""
echo "Run 'git commit' as normal — shellcheck will run automatically."
