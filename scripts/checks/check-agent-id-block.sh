#!/usr/bin/env bash
# Checks that a GitHub PR body or issue comment posted by an agent includes
# the required agent identification block (AGENTS.md section 9.5).
#
# Usage:
#   check-agent-id-block.sh <file>          # check body saved to a file
#   echo "$BODY" | check-agent-id-block.sh  # check body from stdin
#
# Exit 0 = identification block found. Exit 1 = block missing.
#
# Required block format (AGENTS.md 9.5):
#   ---
#   - Agent: <name and model>
#   - Date: YYYY-MM-DD
#   - Method: <what the agent did>
#   - Scope: <files or context>
#   - Confirmation: yes|no
#   ---

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_ROOT}/lib/core/color.sh"

input_file="${1:-/dev/stdin}"

body=$(cat "$input_file")

# Check for the minimum required fields: Agent and Date lines inside a --- block
if echo "$body" | grep -qE '^\s*-\s+Agent:' && \
   echo "$body" | grep -qE '^\s*-\s+Date:' && \
   echo "$body" | grep -qE '^\s*-\s+Confirmation:'; then
    print_success "agent identification block found"
    exit 0
fi

print_error "agent identification block missing or incomplete"
echo ""
echo "Agent-authored PR bodies and issue comments MUST end with:"
echo ""
echo "  ---"
echo "  - Agent: <tool name and model>"
echo "  - Date: $(date +%Y-%m-%d)"
echo "  - Method: <what the agent did>"
echo "  - Scope: <files, issues, or context>"
echo "  - Confirmation: yes|no"
echo "  ---"
echo ""
echo "See AGENTS.md section 9.5 for the full specification."
exit 1
