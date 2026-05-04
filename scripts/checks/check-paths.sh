#!/usr/bin/env bash
# Check documentation paths and file references
# Exit code: 0 if all paths valid, 1 if any missing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
    ((ERRORS++)) || true
}

warn() {
    echo -e "${YELLOW}WARN:${NC} $1" >&2
    ((WARNINGS++)) || true
}

info() {
    echo -e "${GREEN}INFO:${NC} $1"
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
    occurrences=$(grep -rn "$username_pattern" --include="*.md" . 2>/dev/null | grep -v ".git/" | grep -v "CODEOWNERS" || true)
    
    if [[ -n "$occurrences" ]]; then
        warn "Found hardcoded username (should use <assignee> placeholder):"
        echo "$occurrences" | head -5
    fi
}

# Check for non-existent directories referenced in docs (that SHOULD exist)
check_directory_references() {
    info "Checking directory references..."
    
    # Only check directories that SHOULD exist (not optional ones like ai/skills)
    local dirs_to_check=(
        ".opencode/agents"   # Should exist
        ".opencode/commands" # Should exist
        ".opencode/modes"   # Should exist
    )
    
    for dir in "${dirs_to_check[@]}"; do
        if [[ ! -d "$dir" ]]; then
            # Check if referenced in documentation
            if grep -r "$dir" --include="*.md" . 2>/dev/null | grep -v ".git/" | head -1 >/dev/null; then
                error "Directory $dir does not exist but is referenced in documentation"
            fi
        fi
    done
    
    # ai/skills is optional - check it's documented as such
    if [[ ! -d "ai/skills" ]]; then
        # This is expected - it's documented as optional
        info "Directory ai/skills does not exist (documented as optional)"
    fi
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
