| field | value |
|-------|-------|
| file | AGENTS.md |
| version | 1.3 |
| purpose | agent_bootstrap |
| priority | critical |
| compatibility | OpenCode, Claude Code, Cursor, Copilot, MCP-compatible systems |
| last_updated | 2026-04-20 |

# AGENTS.md

Authoritative agent operating contract for this repository.

## Core Principles

1. **Security over convenience**
2. **Determinism over creativity**
3. **Minimal scope changes**
4. **Explicit reasoning over implicit assumptions**
5. **No speculative modifications**

## Authority Hierarchy

When conflicts arise, follow this order:

1. Direct human instruction in active session
2. **This AGENTS.md file** (operating contract)
3. **DEVELOPMENT.md** (workflow rules, templates)
4. **ai/governance/** (behavioral constraints)
5. **ai/actions/** (executable workflow actions)
6. **ai/templates/** (structured output templates)
7. **docs/architecture/governance/** (platform invariants)
8. **docs/developer/** (developer guides)

## Critical Constraints

### Issue-First Development (MANDATORY)

**ALWAYS create an issue before starting work.** No exceptions without explicit override.

**Issue format:**
```
Title: [TYPE] Description (NO colons)
Body: Use ai/templates/issue/*.md templates
Labels: component:* required; P1/P2/P3 optional; profile:* optional
Assignee: Required (use <assignee> placeholder in docs)
```

**Branch format:** `issue-<number>/<short-description>`

**Commit format:**
```
<type>: <description> (under 72 chars)

- Change details

Fixes #<issue-number>
```

**PR format:**
```
Title: <description> (#<number>) (NO colons)
Body: Fixes #<number>
Labels: Must match issue
Assignee: Required
```

### Formatting Rules (NON-NEGOTIABLE)

- **NO colons** in issue/PR titles: `[TASK] Setup agent` not `[TASK]: Setup agent`
- **NO Unicode**: Use `- [x]` checkboxes, not ✓ or emoji
- **ASCII only**: Plain text for cross-platform compatibility
- **Unix line endings (LF)**, never CRLF

### Label Taxonomy

**Issue Types** (select exactly one in GitHub UI):
- `Bug` - Unexpected problem
- `Feature` - New functionality
- `Task` - Specific work

**Component Labels** (required):
- `component:runtime-core`, `component:ollama`, `component:persistence`
- `component:observability`, `component:ui`, `component:cli`
- `component:infrastructure`, `component:testing`

**Other Labels**:
- Priority: `P1`, `P2`, `P3`
- Profile: `profile:usr`, `profile:dev`, `profile:ops`, `profile:sys`
- Category: `Fix`, `Enhancement`, `Refactor`, `Maintenance`

## Platform Invariants (NON-NEGOTIABLE)

### Fixed Core Runtime

- **Inference Engine** (Ollama) - Docker-managed, always enabled
- **OpenCode** - VS Code plugin, client-side, always enabled
- Never remove, replace, or conditionally disable runtime core components

### Runtime vs Operational Services Boundary

- Runtime core must be runnable **without** operational services
- Runtime core must **never** depend on operational services
- Network mode: `host` networking for all services (by design)

## Repository Structure

```
ai/
  governance/         # Behavioral constraints
  actions/            # Executable workflow actions
    workflow/         # Issue, branch, commit, PR, verify
    validation/       # Lint, check
    utilities/        # Guidelines
  orchestration/      # Agent definitions (agent-*.md)
  templates/          # Issue and PR templates
    issue/            # bug_report.md, feature_request.md, task.md
    pr/               # pull_request.md
.opencode/
  agents/             # Agent definitions
  commands/           # Slash commands (/workflow, /issue, etc.)
  modes/              # Working modes (planning, building, reviewing)
```

## Essential Commands

### Stack Operations
```bash
./aixcl utils check-env          # Validate environment
./aixcl stack start --profile usr # Start stack (usr/dev/ops/sys)
./aixcl stack status             # Check service health
./aixcl stack logs engine        # View inference logs
./aixcl stack stop               # Stop all services
./aixcl utils clean              # Wipe containers/volumes
```

### Engine Management
```bash
./aixcl engine auto              # Auto-detect optimal engine
./aixcl engine set ollama        # Set engine (ollama/vllm/llamacpp)
./aixcl stack restart engine     # Restart to apply changes
```

### Model Management
```bash
./aixcl models add <model>       # Add model
./aixcl models list              # List local models
./aixcl models remove <model>    # Remove model
```

### OpenCode CLI
```bash
./opencode                       # Start OpenCode session
```

### Validation
```bash
./scripts/checks/check-agents.sh  # Validate agent/action files
./scripts/checks/check-environment.sh  # Full environment check
```

## GitHub CLI Commands

```bash
# Create issues (set type in GitHub UI after creation)
gh issue create --title "[TASK] Description" --body "..." --label "component:cli" --assignee <username>

# Create branch
git checkout -b issue-<number>/<description>

# Create PR (no colons in title)
gh pr create --title "Description (#<number>)" --body "Fixes #<number>"
gh pr edit <number> --add-assignee <username> --add-label "component:cli"
```

## Template Loading

**Before creating issues/PRs, load the appropriate template:**

| Task | Template Path |
|------|---------------|
| Create bug report | `ai/templates/issue/bug_report.md` |
| Create feature request | `ai/templates/issue/feature_request.md` |
| Create task | `ai/templates/issue/task.md` |
| Create PR | `ai/templates/pr/pull_request.md` |
| Create issue | `ai/actions/workflow/action-create-issue.md` |
| Create branch | `ai/actions/workflow/action-create-branch.md` |
| Commit changes | `ai/actions/workflow/action-commit.md` |
| Create PR | `ai/actions/workflow/action-create-pr.md` |
| Verify CI | `ai/actions/workflow/action-verify-ci.md` |
| Lint agents | `ai/actions/validation/action-lint-agents.md` |

## Safe Areas for AI Contribution

**You MAY:**
- Modify operational services (monitoring, logging, automation)
- Improve documentation
- Adjust CLI ergonomics (without changing semantics)
- Organize Compose files (if invariants preserved)
- Add new operational profiles or tooling

**You MUST NOT:**
- Remove/replace/disable runtime core components
- Introduce runtime core → operational service dependencies
- Merge runtime logic with monitoring/admin tooling
- Collapse service boundaries
- Add external libraries, cloud services, telemetry, or analytics without explicit approval

## Self-Verification Checklist

Before ANY operation, confirm:

- [ ] I have read AGENTS.md and DEVELOPMENT.md
- [ ] This change is explicitly requested and minimally scoped
- [ ] Sufficient repository evidence exists (no hallucination risk)
- [ ] Required issue exists or override is documented per Section 8
- [ ] No security principles are violated
- [ ] No unauthorized dependencies are introduced

If ANY check fails → HALT and escalate.

## Authority Conflict Resolution

When human instruction conflicts with lower-authority rules (e.g., issue-first policy):

1. Acknowledge the conflict explicitly to human
2. Document the override request in a new [TASK] issue
3. Obtain explicit written confirmation: "Proceed without issue" or "Create issue first"
4. If proceeding, prefix all commits with `[OVERRIDE]`

**NEVER silently bypass issue-first requirement.**

## Hallucination Guard

If repository evidence is insufficient, respond with:

> "Insufficient repository evidence. Clarification required."

Never fabricate missing details.

## Escalation Procedures

When halting due to insufficient evidence, missing requirements, or conflicts:

1. **If working on an issue:** Post clarification question as issue comment
2. **If no issue exists:** Ask human operator directly; do not create issue unilaterally
3. **If security concern:** Flag with `[SECURITY]` prefix and await explicit approval
4. **If authority conflict:** Follow Section 8 protocol

Document all escalations in the issue timeline.

## Tool Usage

### bash Tool

- Prefer actually running commands over printing them
- Avoid destructive operations (`git push --force`, `git reset --hard`, `rm -rf`)
- Wildcard permissions must be first: `"*": "ask"` then specific overrides

### read/edit/write Tools

- Load files on a need-to-know basis (lazy loading)
- Read full files when needed, not just snippets
- Preserve existing code style and conventions
- Make minimal, focused changes

### webfetch Tool

- Use only when explicitly needed for external documentation
- Always ask for approval before fetching external content

## Response Style

- Use plain ASCII text (no Unicode special characters)
- Use markdown checkboxes: `- [x]` for completed, `- [ ]` for incomplete
- Be concise but thorough
- Surface risks and assumptions explicitly
- Suggest tests when making code changes

## Output Formatting

**When reporting information back to the user, prefer tabular formatting.**

Tables make information easier to scan and compare. Use markdown tables for:
- Command references and their descriptions
- File lists with metadata
- Configuration options
- Status reports with multiple fields
- Any structured data with 2+ columns

**Example:**
```markdown
| Command | Description |
|---------|-------------|
| `./aixcl stack start` | Start the AIXCL stack |
| `./aixcl stack status` | Check service health |
```

**When to use lists instead:**
- Single-column data
- Step-by-step instructions
- Free-form explanations
- Narrative descriptions

## External References

- `DEVELOPMENT.md` - Full workflow rules and templates
- `docs/developer/development-workflow.md` - Complete developer guide
- `docs/architecture/governance/00_invariants.md` - Platform invariants
- `docs/architecture/governance/01_ai_guidance.md` - AI behavioral guidance
- `ai/governance/workflow-governance.md` - Workflow constraints
- `opencode.json` - OpenCode configuration

---

**Remember:** Security over convenience. Determinism over creativity. Minimal scope changes.
