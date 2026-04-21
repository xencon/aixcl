| field | value |
|-------|-------|
| file | AGENTS.md |
| version | 1.4 |
| purpose | agent_bootstrap |
| priority | critical |
| compatibility | OpenCode, Claude Code, Cursor, Copilot, MCP-compatible systems |
| last_updated | 2026-04-21 |

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
- Title: `[TYPE] Description` (NO colons in title, e.g. `[TASK] Setup agent`, not `[TASK]: Setup agent`)
- Body: Use templates from `ai/templates/issue/`
- Labels: `component:*` required; `P1/P2/P3` optional; `profile:*` optional
- Assignee: Required (use `<assignee>` placeholder in templates; never hardcode usernames)

**Branch format:** `issue-<number>/<short-description>` (e.g. `issue-217/fix-encoding`)

**Commit format:**
```
<type>: <description> (under 72 chars)

- Change details

Fixes #<issue-number>
```
Allowed types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`, `ci`.

**PR format:**
```
Title: <description> (#<number>) (NO colons)
Body: Fixes #<number>
Labels: Must match issue
Assignee: Required
```

### Formatting Rules (NON-NEGOTIABLE)

- **NO colons** in issue/PR titles (e.g. `[TASK] Setup agent`, not `[TASK]: Setup agent`)
- **NO Unicode checkmarks**: Use `- [x]` checkboxes, not ✓ or emoji
- **ASCII only**: Plain text for cross-platform compatibility
- **Unix line endings (LF)**, never CRLF (`.gitattributes` enforces LF; CI fails on CRLF)

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
- **OpenCode** - Client-side AI assistant, always enabled
- Never remove, replace, or conditionally disable runtime core components

### Runtime vs Operational Services Boundary

- Runtime core must be runnable **without** operational services
- Runtime core must **never** depend on operational services
- Network mode: `host` networking for all services (by design)

## Essential Commands

### Stack Operations
```bash
./aixcl utils check-env               # Validate environment prerequisites
./aixcl stack start --profile usr    # Start stack: usr/dev/ops/sys
./aixcl stack status                  # Check service health
./aixcl stack logs engine             # View inference logs
./aixcl stack stop                    # Stop all services gracefully
./aixcl utils clean                   # Wipe containers/volumes (destructive — confirm first)
```

### Engine & Model Management
```bash
./aixcl engine auto                   # Auto-detect optimal engine
./aixcl engine set ollama             # Set engine: ollama / vllm / llamacpp
./aixcl stack restart engine          # Restart engine to apply changes
./aixcl models add qwen2.5-coder:0.5b # Add model(s)
./aixcl models list                   # List installed models
```

### Testing
```bash
./tests/run-tests.sh                  # Run all platform tests
./tests/run-tests.sh --quick          # Quick mode
./tests/run-tests.sh --category cmd   # Run specific category
cat tests/test-results.md             # View latest run results
```

### Validation & Lint
```bash
./scripts/checks/check-agents.sh      # Lint ai/orchestration/agent-*.md, ai/actions/action-*.md, ai-report-*
./scripts/checks/check-environment.sh # Full environment check
```

### OpenCode CLI
```bash
opencode                              # Start OpenCode session (global binary; repo provides opencode.json)
```

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

If ANY check fails → **HALT** and escalate.

## Escalation Procedures

When halting due to insufficient evidence, missing requirements, or conflicts:

1. **If working on an issue:** Post clarification question as issue comment
2. **If no issue exists:** Ask human operator directly; do not create issue unilaterally
3. **If security concern:** Flag with `[SECURITY]` prefix and await explicit approval
4. **If authority conflict:** Document override request in a new `[TASK]` issue; obtain explicit written confirmation; prefix commits with `[OVERRIDE]` if proceeding. **NEVER silently bypass issue-first requirement.**

## Tool Usage

### bash
- Prefer actually running commands over printing them
- Avoid destructive operations (`git push --force`, `git reset --hard`, `rm -rf`)
- Wildcard permissions must be first: `"*": "ask"` then specific overrides

### read/edit/write
- Load files on a need-to-know basis (lazy loading)
- Read full files when needed, not just snippets
- Preserve existing code style and conventions; make minimal, focused changes

### webfetch
- Use only when explicitly needed for external documentation; ask for approval first

## Response Style

- Use plain ASCII text (no Unicode special characters)
- Use markdown checkboxes: `- [x]` completed, `- [ ]` incomplete
- Prefer **tabular formatting** for commands, file lists, and status reports (2+ columns)
- Use lists only for single-column data, step-by-step instructions, or narrative
- Be concise but thorough; surface risks and assumptions explicitly
- Suggest tests when making code changes

## External References

- `DEVELOPMENT.md` — Full workflow rules and templates
- `docs/developer/development-workflow.md` — Complete developer guide
- `docs/architecture/governance/00_invariants.md` — Platform invariants
- `docs/architecture/governance/01_ai_guidance.md` — AI behavioral guidance
- `ai/governance/workflow-governance.md` — Workflow constraints
- `ai/actions/*` — Executable workflow actions (lazy-load when needed)
- `opencode.json` — OpenCode configuration

---

**Remember:** Security over convenience. Determinism over creativity. Minimal scope changes.
