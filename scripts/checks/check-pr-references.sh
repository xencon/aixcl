#!/usr/bin/env bash
# Checks that no list item in a PR or issue body comma-packs multiple #N references.
# Each issue/PR reference must be on its own list item line.
#
# Usage:
#   check-pr-references.sh <file>          # check a body saved to a file
#   echo "$BODY" | check-pr-references.sh  # check body from stdin
#
# Exit 0 = clean. Exit 1 = violations found.

set -euo pipefail

input_file="${1:-/dev/stdin}"

violations=()

while IFS= read -r line; do
    # Only check list item lines (- or *)
    if [[ "$line" =~ ^[[:space:]]*[-*] ]]; then
        # Strip inline code (backtick spans) before checking -- examples in
        # code spans are not subject to the reference style rule
        stripped=$(echo "$line" | sed 's/`[^`]*`//g')
        # Flag only comma-separated #N references: #123, #456 or #123,#456
        if echo "$stripped" | grep -qE '#[0-9]+[[:space:]]*,[[:space:]]*#[0-9]+'; then
            violations+=("$line")
        fi
    fi
done < "$input_file"

if [[ "${#violations[@]}" -eq 0 ]]; then
    echo "OK: no comma-packed issue references found"
    exit 0
fi

echo "ERROR: each issue/PR reference must be on its own list item line"
echo "Found ${#violations[@]} violation(s):"
for v in "${violations[@]}"; do
    echo "  $v"
done
echo ""
echo "Fix: split comma-packed references into separate list items, e.g.:"
echo "  - Closes #1"
echo "  - Closes #2"
exit 1
