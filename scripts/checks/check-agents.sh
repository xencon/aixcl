#!/usr/bin/env bash
# Check Claude Code skills and AI reports for compliance with naming conventions and structure.
# Exit code: 0 if all checks pass, 1 if any check fails.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0
WARNINGS=0

# shellcheck disable=SC1091
source "${REPO_ROOT}/lib/core/color.sh"

error() {
    echo -e "${RED}${ICON_ERROR:-❌}${NC} $1" >&2
    ERRORS=$((ERRORS + 1))
}

warn() {
    echo -e "${YELLOW}${ICON_WARNING:-⚠️}${NC} $1" >&2
    WARNINGS=$((WARNINGS + 1))
}

info() {
    print_info "$1"
}

# Check skill files
check_skills() {
    local skills_dir=".claude/skills"
    if [[ ! -d "$skills_dir" ]]; then
        return 0  # Skills directory is optional
    fi

    local skill_files=()
    while IFS= read -r -d '' file; do
        skill_files+=("$file")
    done < <(find "$skills_dir" -name "SKILL.md" -type f -print0 2>/dev/null || true)

    if [[ ${#skill_files[@]} -eq 0 ]]; then
        return 0
    fi

    for skill_file in "${skill_files[@]}"; do
        local basename
        basename=$(basename "$(dirname "$skill_file")")
        info "Checking skill: $basename"

        if ! grep -q "^---$" "$skill_file"; then
            warn "$basename/SKILL.md: Missing YAML frontmatter"
            continue
        fi

        local frontmatter
        frontmatter=$(awk '/^---$/{flag=1; next} /^---$/{flag=0} flag' "$skill_file")

        if ! echo "$frontmatter" | grep -q "^name:"; then
            error "$basename/SKILL.md: Missing 'name' field in frontmatter"
        fi
        if ! echo "$frontmatter" | grep -q "^description:"; then
            error "$basename/SKILL.md: Missing 'description' field in frontmatter"
        fi
    done
}

# Check AI report files
check_reports() {
    local reports_dir="docs/reference"
    if [[ ! -d "$reports_dir" ]]; then
        return 0
    fi

    local report_files=("$reports_dir"/ai-report-*.md)
    if [[ ! -e "${report_files[0]}" ]]; then
        return 0  # No reports yet
    fi

    for report_file in "${report_files[@]}"; do
        local basename
        basename=$(basename "$report_file")
        info "Checking AI report: $basename"

        if [[ ! "$basename" =~ ^ai-report-.*\.md$ ]]; then
            warn "$basename does not match ai-report-*.md naming convention"
        fi
    done
}

# Main execution
main() {
    echo "Checking skills and AI reports..."
    echo ""

    check_skills
    check_reports

    echo ""
    if [[ $ERRORS -eq 0 ]]; then
        info "All checks passed!"
        if [[ $WARNINGS -gt 0 ]]; then
            echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
        fi
        exit 0
    else
        error "Found $ERRORS error(s)"
        if [[ $WARNINGS -gt 0 ]]; then
            warn "Found $WARNINGS warning(s)"
        fi
        exit 1
    fi
}

main "$@"
