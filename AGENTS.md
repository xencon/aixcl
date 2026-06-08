| field | value |
|-------|-------|
| file | AGENTS.md |
| version | 2.0 |
| purpose | agent_contract |
| priority | critical |
| compatibility | OpenCode, Claude Code, Cursor, Copilot, MCP-compatible systems |
| last_updated | 2026-06-08 |

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
4. **.opencode/rules/** and **.claude/rules/** (behavioral constraints)
5. **docs/architecture/governance/** (platform invariants)
6. **docs/developer/** (developer guides)

## Critical Constraints

### Issue-First Development (MANDATORY)

**ALWAYS create an issue before starting work.** No exceptions without explicit override.

- Title: `[TYPE] Description` (NO colons)
- Labels: `component:*` required
- Assignee: Required
- Branch: `issue-<number>/<short-description>` from `dev`
- Commit: `<type>: <description>` (under 72 chars), include `Fixes #<number>`
- PR: `<description> (#<number>)` (NO colons), assignee + labels at creation time

**For complete details:**
- [docs/developer/development-workflow.md](docs/developer/development-workflow.md) -- Full step-by-step guide
- [DEVELOPMENT.md](DEVELOPMENT.md) -- Quick reference and PR race condition rules

### Platform Invariants (NON-NEGOTIABLE)

#### Fixed Core Runtime

- **Inference Engine** (Ollama) - Docker-managed, always enabled
- **OpenCode** - AI-powered code assistance, always enabled
- Never remove, replace, or conditionally disable runtime core components

#### Runtime vs Operational Services Boundary

- Runtime core must be runnable without operational services
- Runtime core must never depend on operational services
- Network mode: `host` networking for all services (by design)

### Formatting Rules

- **NO colons** in issue/PR titles (e.g. `[TASK] Setup agent`, not `[TASK]: Setup agent`)
- **NO Unicode checkmarks**: Use `- [x]` checkboxes, not emoji
- **ASCII only**: Plain text for cross-platform compatibility
- **Unix line endings (LF)**, never CRLF (`.gitattributes` enforces LF; CI fails on CRLF)

### Label Taxonomy

**Issue Types:** `Bug`, `Feature`, `Task`

**Component Labels (required):**
`component:runtime-core`, `component:ollama`, `component:persistence`,
`component:observability`, `component:ui`, `component:cli`,
`component:infrastructure`, `component:testing`

**Other Labels:**
- Priority: `P1`, `P2`, `P3`
- Profile: `profile:bld`, `profile:sys`
- Category: `Fix`, `Enhancement`, `Refactor`, `Maintenance`

### Lean Repository Policy

- Delete outdated reports and dated documentation; do not archive
- Operations reports should be current (within 30 days)
- Generated files stay generated; use `.gitignore`
- Verify: no dated reports, no tracked generated files, no stale archive directories

## Safe Areas for Agentic Contribution

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

## Essential Commands

### Stack Operations
```bash
./aixcl utils check-env               # Validate environment prerequisites
./aixcl stack start --profile sys     # Start stack
./aixcl stack status                  # Check service health
./aixcl stack stop                    # Stop all services gracefully
```

### Validation & Lint
```bash
./scripts/checks/check-agents.sh      # Lint agent and skill files
./scripts/checks/check-environment.sh # Full environment check
./tests/run-tests.sh                  # Run all platform tests
```

## Self-Verification Checklist

Before ANY operation, confirm:

- [ ] I have read AGENTS.md and DEVELOPMENT.md
- [ ] This change is explicitly requested and minimally scoped
- [ ] Sufficient repository evidence exists (no hallucination risk)
- [ ] Required issue exists or override is documented per Section 8
- [ ] No security principles are violated
- [ ] No unauthorized dependencies are introduced
- [ ] Merged files scanned for conflict markers (when merge performed)

If ANY check fails → **HALT** and escalate.

## Escalation Procedures

When halting due to insufficient evidence, missing requirements, or conflicts:

1. **If working on an issue:** Post clarification question as issue comment
2. **If no issue exists:** Ask human operator directly; do not create issue unilaterally
3. **If security concern:** Flag with `[SECURITY]` prefix and await explicit approval
4. **If authority conflict:** Document override request, obtain explicit written confirmation

## Emergency Workflow Override

In exceptional situations, a human operator may explicitly authorize the agent to proceed without a pre-existing issue.

**Required:** Direct instruction: "[OVERRIDE] Proceed without creating an issue first."

**Conditions:**
- Override applies ONLY to the specific change
- All OTHER rules still apply (branch naming, commits, GPG signing, PRs, CI)
- The change must be minimal and reversible

**Retroactive Documentation:** Create a `[TASK]` issue prefixed with `[OVERRIDE]` after completion.

**Commit Format:** `[OVERRIDE] type: Brief description`

### What DOES NOT Qualify

- "Just do it" without context
- Vague urgency

## 10. Human in the Loop Checklist Policy

The agent MUST distinguish between agent-completed items and human-verification items.

| Party | Fills [x] | Example |
|-------|-----------|---------|
| Agent | Items the agent performed | "Issue referenced", "Branch named correctly" |
| Human | Items requiring manual verification | "Behavior works as expected", "No regressions observed" |

The human sees `[ ]` on verification items and ticks them during code review.

## 11. Quick References

### Tool Usage

- Prefer actually running commands over printing them
- Avoid destructive operations (`git push --force`, `git reset --hard`)
- Load files on a need-to-know basis (lazy loading)
- Preserve existing code style and conventions

### Response Style

- Use plain ASCII text (no Unicode special characters)
- Prefer tabular formatting for commands, file lists, and status reports
- Be concise but thorough; surface risks explicitly
- Suggest tests when making code changes

## External References

- [DEVELOPMENT.md](DEVELOPMENT.md) -- Full workflow rules and templates
- [docs/developer/development-workflow.md](docs/developer/development-workflow.md) -- Complete developer guide
- [docs/architecture/governance/00_invariants.md](docs/architecture/governance/00_invariants.md) -- Platform invariants
- [docs/architecture/governance/01_ai_guidance.md](docs/architecture/governance/01_ai_guidance.md) -- Agentic behavioral guidance
- `.opencode/rules/workflow.md` -- OpenCode workflow constraints
- `.claude/rules/workflow.md` -- Claude Code workflow constraints
- `opencode.json` -- OpenCode configuration

---

**Remember:** Security over convenience. Determinism over creativity. Minimal scope changes.
