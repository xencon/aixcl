#!/usr/bin/env bash
# Checks that no list item in a PR or issue body bunches multiple #N references.
# Each issue/PR reference must be on its own list item line.
# Catches comma-separated (#N, #M), slash-separated (#N/#M), and space-separated (#N #M).
#
# Usage:
#   check-pr-references.sh <file>          # check a body saved to a file
#   echo "$BODY" | check-pr-references.sh  # check body from stdin
#
# Exit 0 = clean. Exit 1 = violations found.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_ROOT}/lib/core/color.sh"

input_file="${1:-/dev/stdin}"

violations=()

while IFS= read -r line; do
    # Only check list item lines (- or *)
    if [[ "$line" =~ ^[[:space:]]*[-*] ]]; then
        # Strip inline code (backtick spans) before checking -- examples in
        # code spans are not subject to the reference style rule
        stripped=$(echo "$line" | sed 's/`[^`]*`//g')
        # Flag bunched #N references separated by comma, slash, or bare space
        if echo "$stripped" | grep -qE '#[0-9]+[[:space:]]*[,/][[:space:]]*#[0-9]+|#[0-9]+[[:space:]]+#[0-9]+'; then
            violations+=("$line")
        fi
    fi
done < "$input_file"

if [[ "${#violations[@]}" -eq 0 ]]; then
    print_success "no comma-packed issue references found"
    exit 0
fi

print_error "each issue/PR reference must be on its own list item line (no comma, slash, or space-separated bunching)"
echo "Found ${#violations[@]} violation(s):"
for v in "${violations[@]}"; do
    echo "  $v"
done
echo ""
echo "Fix: split comma-packed references into separate list items, e.g.:"
echo "  - Closes #1"
echo "  - Closes #2"
exit 1
