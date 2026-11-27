#!/usr/bin/env bash
# check-action-pins.sh -- verify GitHub Action references are pinned to commit SHAs
#
# A tag (v7, v7.0.1) is a movable pointer: whoever controls the action's
# repository can repoint it, and every workflow using the tag runs the new
# code on its next trigger (the tj-actions/changed-files compromise). A
# full 40-character commit SHA is immutable. SHA pinning was first done in
# #1413, then regressed to tags as new workflows were added; this check
# keeps it from regressing again (issue #2080).
#
# Rules, for every uses: line in .github/workflows/*.yml and
# .github/actions/**/action.yml:
#   1. Remote actions must be pinned as owner/repo[/path]@<40-hex-sha>
#   2. The SHA must carry a trailing "# <version>" comment, so reviewers
#      and Dependabot can see which release it is
#   Exempt: local actions (./path), docker:// references pinned by
#   @sha256 digest, and commented-out lines.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0

report() {
    echo "UNPINNED ($1): $2"
    fail=1
}

files=()
while IFS= read -r f; do
    files+=("$f")
done < <(find .github/workflows -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort
         find .github/actions \( -name 'action.yml' -o -name 'action.yaml' \) 2>/dev/null | sort)

if [ "${#files[@]}" -eq 0 ]; then
    echo "No workflow files found"
    exit 0
fi

while IFS= read -r match; do
    # match format: file:line:content
    content="${match#*:*:}"
    ref="$(sed -E 's/^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*//; s/[[:space:]]+#.*$//; s/^["'\'']//; s/["'\'']$//' <<<"$content")"

    case "$ref" in
        ./*) continue ;;
        docker://*@sha256:*) continue ;;
        docker://*) report "docker tag" "$match"; continue ;;
    esac

    if ! grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}$' <<<"$ref"; then
        report "not a SHA" "$match"
        continue
    fi

    if ! grep -qE '@[0-9a-f]{40}["'\'']?[[:space:]]+#[[:space:]]*v?[0-9]' <<<"$content"; then
        report "no version comment" "$match"
    fi
done < <(grep -HnE '^[[:space:]]*(-[[:space:]]*)?uses:' "${files[@]}" || true)

if [ "$fail" -eq 1 ]; then
    echo "FAIL: GitHub Action references must be pinned to a commit SHA with a version comment"
    echo "      e.g. uses: actions/checkout@<40-char-sha> # v7.0.1"
    exit 1
fi

echo "All GitHub Action references are pinned to commit SHAs"
exit 0
