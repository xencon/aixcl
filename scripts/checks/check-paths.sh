#!/usr/bin/env bash
# Check documentation paths and file references
# Exit code: 0 if all paths valid, 1 if any missing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0
WARNINGS=0

# shellcheck disable=SC1091
source "${REPO_ROOT}/lib/core/color.sh"

error() {
    echo -e "${RED}${ICON_ERROR:-❌}${NC} $1" >&2
    ((ERRORS++)) || true
}

warn() {
    echo -e "${YELLOW}${ICON_WARNING:-⚠️}${NC} $1" >&2
    ((WARNINGS++)) || true
}

info() {
    print_info "$1"
}

# Check for references to non-existent files in markdown
check_markdown_paths() {
    info "Checking markdown file references..."

    local md_files=()
    while IFS= read -r -d '' file; do
        md_files+=("$file")
    done < <(find . -name "*.md" -type f -not -path "./.git/*" -not -path "./.backup/*" -not -path "./node_modules/*" -not -path "./.opencode/node_modules/*" -print0 2>/dev/null || true)

    local checked=0
    local issues=0

    for md_file in "${md_files[@]}"; do
        # Extract relative paths from markdown links [text](./path) or [text](../path)
        # Using simpler grep pattern and processing
        local links
        links=$(grep -oE '\]\([^)]+\)' "$md_file" 2>/dev/null | tr -d ']()' || true)

        for link in $links; do
            # Skip external URLs and anchors
            [[ "$link" =~ ^https?:// ]] && continue
            [[ "$link" =~ ^# ]] && continue
            [[ "$link" =~ ^mailto: ]] && continue

            # Skip template placeholder paths (release notes, templates)
            [[ "$link" =~ vPREVIOUS\.\.\.vX\.Y\.Z ]] && continue
            [[ "$link" =~ \.\.\./\.\./compare/ ]] && continue

            # Remove anchor fragments
            local path="${link%%#*}"

            # Only check relative paths starting with ./ or ../
            [[ ! "$path" =~ ^\./ ]] && [[ ! "$path" =~ ^\.\./ ]] && continue

            # Resolve relative path
            local dir
            dir=$(dirname "$md_file")
            local full_path
            full_path="$dir/$path"

            ((checked++)) || true

            if [[ ! -e "$full_path" ]]; then
                error "In $md_file: Referenced path does not exist: $path"
                ((issues++)) || true
            fi
        done
    done

    info "Checked $checked markdown references, found $issues issues"
}

# Check for common stale path patterns
check_common_stale_paths() {
    info "Checking for common stale path patterns..."

    local stale_patterns=(
        "scripts/check-agents.sh"  # Should be scripts/checks/check-agents.sh
        "ai/skills/"               # Directory does not exist
        "ai/orchestration/registry.yaml"  # File does not exist
        "opencode/cli-ollama.yaml"        # Path changed
    )

    for pattern in "${stale_patterns[@]}"; do
        if grep -r "$pattern" --include="*.md" --include="*.yml" --include="*.yaml" --include="*.json" . 2>/dev/null | grep -v ".git/" | head -1 >/dev/null; then
            warn "Found potential stale reference: $pattern"
            grep -rn "$pattern" --include="*.md" --include="*.yml" --include="*.yaml" --include="*.json" . 2>/dev/null | grep -v ".git/" | head -5
        fi
    done
}

# Check for hardcoded usernames that should be placeholders
check_hardcoded_usernames() {
    info "Checking for hardcoded usernames..."

    local username_pattern="sbadakhc"
    local occurrences
    # Exclusions (see issue #1756): CHANGELOG.md is a historical record,
    # and the fork repo slug (sbadakhc/aixcl) documents real infrastructure
    # (remote URLs, fork layout) rather than an assignee that should be a
    # placeholder. Everything else stays strict.
    occurrences=$(grep -rn "$username_pattern" --include="*.md" . 2>/dev/null \
        | grep -v ".git/" \
        | grep -v "CODEOWNERS" \
        | grep -v "^\./CHANGELOG\.md:" \
        | grep -v "sbadakhc/aixcl" \
        || true)

    if [[ -n "$occurrences" ]]; then
        warn "Found hardcoded username (should use <assignee> placeholder):"
        echo "$occurrences" | head -5
    fi
}

# Check for non-existent directories referenced in docs (that SHOULD exist)
check_directory_references() {
    info "Checking directory references..."

    local dirs_to_check=(
        ".opencode/agents"   # Should exist
    )

    for dir in "${dirs_to_check[@]}"; do
        if [[ ! -d "$dir" ]]; then
            # Check if referenced in documentation
            if grep -r "$dir" --include="*.md" . 2>/dev/null | grep -v ".git/" | head -1 >/dev/null; then
                error "Directory $dir does not exist but is referenced in documentation"
            fi
        fi
    done
}

# Main execution
main() {
    echo "========================================"
    echo "Documentation Path Validation"
    echo "========================================"
    echo ""

    check_markdown_paths
    check_common_stale_paths
    check_hardcoded_usernames
    check_directory_references

    echo ""
    echo "========================================"
    if [[ $ERRORS -eq 0 ]]; then
        info "All path checks passed!"
        if [[ $WARNINGS -gt 0 ]]; then
            warn "Found $WARNINGS warning(s) to review"
        fi
        exit 0
    else
        error "Found $ERRORS error(s) - please fix before committing"
        if [[ $WARNINGS -gt 0 ]]; then
            warn "Also found $WARNINGS warning(s)"
        fi
        exit 1
    fi
}

main "$@"
