#!/usr/bin/env bash
# check-obfuscation.sh -- scan shell code for obfuscation/injection patterns
#
# ShellCheck catches quoting bugs; it does not catch deliberate obfuscation.
# This check codifies the manual pre-release scan from 2026-07-11 (#1870):
#
#   1. base64 decode piped to a shell interpreter
#   2. ANSI-C hex/unicode escapes ($'\x..') constructing strings
#   3. quote-split expansion ("$"{ -- hides a variable expansion from greps)
#   4. printf-built commands piped to a shell interpreter
#   5. curl/wget piped straight to a shell interpreter
#   6. eval without an inline justification comment
#
# Rule 6 waiver: an `# eval-waiver: <reason>` comment on the eval line or
# one of the two lines above it exempts that site. Every waiver must say
# why the input is safe (see lib/core/app_parser.sh for the pattern).
#
# Scope: tracked *.sh files, plus rules 1/5 over *.yml and *.md (install
# snippets and compose inline scripts). This script exempts itself -- it
# necessarily contains every pattern it hunts.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SELF="scripts/checks/check-obfuscation.sh"
fail=0

report() {
    echo "OBFUSCATION ($1): $2"
    fail=1
}

# Tracked shell files, excluding this script
shell_files() {
    git ls-files '*.sh' | grep -v "^${SELF}$"
}

# 1. base64 decode piped to a shell interpreter
while IFS= read -r match; do
    report "base64-to-shell" "$match"
done < <(shell_files | xargs grep -nE 'base64[^|]*(-d|--decode)[^|]*\|[[:space:]]*(ba|z|da)?sh' 2>/dev/null || true)

# 2. ANSI-C escapes constructing strings ($'\x..' or $'\u..')
while IFS= read -r match; do
    report "ansi-c-escape" "$match"
done < <(shell_files | xargs grep -nE "\\\$'\\\\[xu]" 2>/dev/null || true)

# 3. quote-split expansion: "$"{ hides the expansion from pattern matching
while IFS= read -r match; do
    report "quote-split-expansion" "$match"
done < <(shell_files | xargs grep -nF '"$"{' 2>/dev/null || true)

# 4. printf output piped to a shell interpreter
while IFS= read -r match; do
    report "printf-to-shell" "$match"
done < <(shell_files | xargs grep -nE 'printf[^|]*\|[[:space:]]*(ba|z|da)?sh([[:space:]]|$)' 2>/dev/null || true)

# 5. curl/wget piped straight to a shell interpreter (also in docs and yaml:
#    install snippets teach users habits, so they are held to the same bar)
while IFS= read -r match; do
    report "pipe-to-shell" "$match"
done < <(git ls-files '*.sh' '*.yml' '*.md' | grep -v "^${SELF}$" \
    | xargs grep -nE '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|$)' 2>/dev/null || true)

# 6. eval without a waiver comment on the same line or the three lines
#    above (multi-line waiver comments)
while IFS= read -r loc; do
    file="${loc%%:*}"
    line="${loc#*:}"
    line="${line%%:*}"
    start=$((line - 3))
    [ "$start" -lt 1 ] && start=1
    if ! sed -n "${start},${line}p" "$file" | grep -q "eval-waiver:"; then
        report "unwaivered-eval" "${file}:${line}: eval without an eval-waiver comment"
    fi
done < <(shell_files | xargs grep -nE '(^|[^A-Za-z_.-])eval[[:space:]]' 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | cut -d: -f1,2 || true)

if [ "$fail" -ne 0 ]; then
    echo ""
    echo "Obfuscation check FAILED."
    echo "Legitimate eval sites need an '# eval-waiver: <reason>' comment (see lib/core/app_parser.sh)."
    echo "The other patterns have no waiver -- rewrite without the obfuscation."
    exit 1
fi
echo "No shell obfuscation patterns found"
