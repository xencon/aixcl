#!/usr/bin/env bash
# Check AI agents, skills, and reports for compliance with naming conventions and structure.
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

# Check agent files
check_agents() {
    local agents_dir=".opencode/agents"
    if [[ ! -d "$agents_dir" ]]; then
        warn "Agent directory $agents_dir does not exist"
        return 0
    fi

    local agent_files=("$agents_dir"/agent-*.md)
    if [[ ! -e "${agent_files[0]}" ]]; then
        warn "No agent files found matching agent-*.md pattern in $agents_dir"
        return 0
    fi

    for agent_file in "${agent_files[@]}"; do
        local basename
        basename=$(basename "$agent_file")
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
            local frontmatter
            frontmatter=$(awk '/^---$/{flag=1; next} /^---$/{flag=0} flag' "$agent_file")

            # Check required fields.
            # NOTE: 'name' must NOT be present -- OpenCode uses it to
            # override the filename-derived agent identifier, which breaks
            # every reference to the agent (command agent fields,
            # default_agent in opencode.json). Identifiers come from
            # filenames only. See issue #1703.
            if echo "$frontmatter" | grep -q "^name:"; then
                error "$basename: 'name' field present in frontmatter (overrides the filename-derived agent id; remove it)"
            fi
            if ! echo "$frontmatter" | grep -q "^description:"; then
                error "$basename: Missing 'description' field in frontmatter"
            fi
            if ! echo "$frontmatter" | grep -q "^mode:"; then
                warn "$basename: Missing 'mode' in frontmatter (e.g., mode: primary or subagent)"
            fi
        fi

        # Check for references to core docs (optional but recommended).
        # Files that defer to AGENTS.md inherit its cold-start reading
        # list (Section 0), which names both documents, so duplicate
        # references are not required there (see issue #1751).
        if ! grep -q "AGENTS.md" "$agent_file"; then
            if ! grep -q "docs/developer/development-workflow.md" "$agent_file"; then
                warn "$basename: Missing reference to docs/developer/development-workflow.md"
            fi
            if ! grep -q "docs/architecture/governance/01_ai_guidance.md" "$agent_file"; then
                warn "$basename: Missing reference to docs/architecture/governance/01_ai_guidance.md"
            fi
        fi
    done
}

# Check skill files
check_skills() {
    local skills_dir=".opencode/skills"
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

# Check that the per-tool rules mirrors have not drifted apart.
# .claude/rules/ and .opencode/rules/ carry the same behavioral constraints
# for different agent tools; divergence here has caused contradictory
# guidance in the past. Update both together, always.
check_rules_parity() {
    local claude_rules=".claude/rules"
    local opencode_rules=".opencode/rules"

    if [[ ! -d "$claude_rules" ]] || [[ ! -d "$opencode_rules" ]]; then
        return 0
    fi

    info "Checking rules parity: $claude_rules <-> $opencode_rules"

    local rule_file basename
    for rule_file in "$claude_rules"/*.md; do
        [[ -e "$rule_file" ]] || continue
        basename=$(basename "$rule_file")
        if [[ ! -f "$opencode_rules/$basename" ]]; then
            error "rules parity: $basename exists in $claude_rules but not $opencode_rules"
        elif ! diff -q "$rule_file" "$opencode_rules/$basename" >/dev/null; then
            error "rules parity: $basename differs between $claude_rules and $opencode_rules"
        fi
    done

    for rule_file in "$opencode_rules"/*.md; do
        [[ -e "$rule_file" ]] || continue
        basename=$(basename "$rule_file")
        if [[ ! -f "$claude_rules/$basename" ]]; then
            error "rules parity: $basename exists in $opencode_rules but not $claude_rules"
        fi
    done

    # Skills are mirrored the same way
    if [[ -d .claude/skills ]] && [[ -d .opencode/skills ]]; then
        info "Checking skills parity: .claude/skills <-> .opencode/skills"
        if ! diff -rq .claude/skills .opencode/skills >/dev/null 2>&1; then
            error "skills parity: .claude/skills and .opencode/skills differ (sync them together)"
            diff -rq .claude/skills .opencode/skills 2>/dev/null | sed 's/^/    /' >&2 || true
        fi
    fi
}

# Print a markdown file's body with any leading YAML frontmatter removed.
strip_frontmatter() {
    awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' "$1"
}

# Check that commands present in BOTH tool directories carry the same body.
# Command sets are intentionally tool-specific (a file on only one side is
# fine), but a shared command must not drift: only frontmatter may differ
# per tool (e.g. the OpenCode 'agent:' field). See issue #1910.
check_commands_parity() {
    local claude_cmds=".claude/commands"
    local opencode_cmds=".opencode/commands"

    if [[ ! -d "$claude_cmds" ]] || [[ ! -d "$opencode_cmds" ]]; then
        return 0
    fi

    info "Checking shared-command parity: $claude_cmds <-> $opencode_cmds"

    local cmd_file basename
    for cmd_file in "$claude_cmds"/*.md; do
        [[ -e "$cmd_file" ]] || continue
        basename=$(basename "$cmd_file")
        [[ -f "$opencode_cmds/$basename" ]] || continue
        if ! diff -q \
            <(strip_frontmatter "$cmd_file") \
            <(strip_frontmatter "$opencode_cmds/$basename") >/dev/null; then
            error "commands parity: $basename body differs between $claude_cmds and $opencode_cmds (frontmatter may differ; bodies must match)"
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
    echo "Checking AI agents, skills, and reports..."
    echo ""

    check_agents
    check_skills
    check_rules_parity
    check_commands_parity
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
