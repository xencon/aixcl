#!/usr/bin/env bash
# sync-mirrors.sh -- Synchronize the .claude/ and .opencode/ mirror directories
#
# Rules and skills must stay byte-identical between .claude/ and .opencode/
# (verified by scripts/checks/check-agents.sh). Editing both sides by hand is
# error-prone; this script performs the copy in one direction and verifies.
#
# Usage:
#   ./scripts/utils/sync-mirrors.sh                 # .claude/ -> .opencode/ (default)
#   ./scripts/utils/sync-mirrors.sh --from-opencode # .opencode/ -> .claude/
#
# Scope: skills/ and rules/ subdirectories only. Agent definitions and other
# tool-specific files are not mirrored and are left untouched.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SRC=".claude"
DST=".opencode"
if [ "${1:-}" = "--from-opencode" ]; then
    SRC=".opencode"
    DST=".claude"
elif [ -n "${1:-}" ]; then
    echo "Usage: $0 [--from-opencode]"
    exit 2
fi

echo "Syncing mirrors: ${SRC}/ -> ${DST}/"

for subdir in skills rules; do
    if [ ! -d "${SRC}/${subdir}" ]; then
        echo "  Skipping ${subdir}: ${SRC}/${subdir} does not exist"
        continue
    fi
    mkdir -p "${DST}/${subdir}"

    # Remove destination entries that no longer exist in the source
    # (handles skill renames and deletions)
    local_entry=""
    for local_entry in "${DST}/${subdir}"/*; do
        [ -e "$local_entry" ] || continue
        name=$(basename "$local_entry")
        if [ ! -e "${SRC}/${subdir}/${name}" ]; then
            echo "  Removing ${DST}/${subdir}/${name} (not in source)"
            rm -rf "$local_entry"
        fi
    done

    # Copy source over destination
    cp -r "${SRC}/${subdir}/." "${DST}/${subdir}/"
    echo "  Synced ${subdir}/"
done

echo ""
echo "Verifying parity..."
if bash "${REPO_ROOT}/scripts/checks/check-agents.sh"; then
    echo ""
    echo "Mirrors are in sync."
else
    echo ""
    echo "Parity verification FAILED after sync -- inspect check-agents output above."
    exit 1
fi
