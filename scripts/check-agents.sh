#!/bin/bash
# Check AI agents, skills, and reports for compliance with naming conventions and structure.
# Exit code: 0 if all checks pass, 1 if any check fails.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
    ((ERRORS++))
}

warn() {
    echo -e "${YELLOW}WARN:${NC} $1" >&2
    ((WARNINGS++))
}

info() {
    echo -e "${GREEN}INFO:${NC} $1"
}

# Check agent files
check_agents() {
    local agents_dir=".continue/agents"
    if [[ ! -d "$agents_dir" ]]; then
        warn "Agent directory $agents_dir does not exist"
        return 0
    fi

    local agent_files=("$agents_dir"/agent-*.md)
    if [[ ! -e "${agent_files[0]}" ]]; then
        warn "No agent files found matching agent-*.md pattern"
        return 0
    fi

    for agent_file in "${agent_files[@]}"; do
        local basename=$(basename "$agent_file")
        info "Checking agent: $basename"

        # Check naming convention
        if [[ ! "$basename" =~ ^agent-.*\.md$ ]]; then
            error "$basename does not match agent-*.md naming convention"
        fi

        # Check YAML frontmatter
        if ! grep -q "^---$" "$agent_file"; then
            error "$basename: Missing YAML frontmatter (no --- delimiter)"
        else
            # Extract frontmatter
            local frontmatter=$(awk '/^---$/{flag=1; next} /^---$/{flag=0} flag' "$agent_file")

            # Check required fields
            if ! echo "$frontmatter" | grep -q "^name:"; then
                error "$basename: Missing 'name' field in frontmatter"
            fi
            if ! echo "$frontmatter" | grep -q "^description:"; then
                error "$basename: Missing 'description' field in frontmatter"
            fi
            if ! echo "$frontmatter" | grep -q "^role: system"; then
                error "$basename: Missing 'role: system' in frontmatter"
            fi
        fi

        # Check required sections
        local content=$(awk '/^---$/{flag=1} /^---$/{flag=0; next} !flag' "$agent_file")
        
        local required_sections=(
            "Purpose"
            "Canonical references"
            "Global rules"
            "Tool usage"
            "Workflow steps"
            "Safety"
        )

        for section in "${required_sections[@]}"; do
            if ! echo "$content" | grep -qi "^## $section\|^### $section"; then
                error "$basename: Missing required section: $section"
            fi
        done

        # Check for references to core docs
        if ! grep -q "docs/developer/development-workflow.md" "$agent_file"; then
            error "$basename: Missing reference to docs/developer/development-workflow.md"
        fi
        if ! grep -q "docs/architecture/governance/01_ai_guidance.md" "$agent_file"; then
            error "$basename: Missing reference to docs/architecture/governance/01_ai_guidance.md"
        fi
    done
}

# Check skill files
check_skills() {
    local skills_dir=".continue/skills"
    if [[ ! -d "$skills_dir" ]]; then
        return 0  # Skills directory is optional
    fi

    local skill_files=("$skills_dir"/skill-*.md)
    if [[ ! -e "${skill_files[0]}" ]]; then
        return 0  # No skills yet
    fi

    for skill_file in "${skill_files[@]}"; do
        local basename=$(basename "$skill_file")
        info "Checking skill: $basename"

        if [[ ! "$basename" =~ ^skill-.*\.md$ ]]; then
            error "$basename does not match skill-*.md naming convention"
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
        local basename=$(basename "$report_file")
        info "Checking AI report: $basename"

        if [[ ! "$basename" =~ ^ai-report-.*\.md$ ]]; then
            warn "$basename does not match ai-report-*.md naming convention (this is a warning, not an error)"
        fi
    done
}

# Main execution
main() {
    echo "Checking AI agents, skills, and reports..."
    echo ""

    check_agents
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
