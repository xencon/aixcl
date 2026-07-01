| field | value |
|-------|-------|
| file | AGENTS.md |
| version | 2.1 |
| purpose | agent_contract |
| priority | critical |
| compatibility | OpenCode, Claude Code, Cursor, Copilot, MCP-compatible systems |
| last_updated | 2026-06-14 |

# AGENTS.md

Authoritative agent operating contract for this repository.

## 0. Cold Start -- Read These First

If you are starting a new session in this repository, read exactly these four documents in this order and stop:

| Order | File | What it gives you |
|-------|------|------------------|
| 1 | `AGENTS.md` (this file) | Operating contract, constraints, authority hierarchy |
| 2 | `DEVELOPMENT.md` | Workflow rules, issue/PR templates, commit format |
| 3 | `docs/architecture/governance/00_invariants.md` | Non-negotiable platform invariants |
| 4 | `docs/architecture/governance/01_ai_guidance.md` | Agentic behavioral guidance |

You do NOT need to read `.claude/rules/` or `.opencode/rules/` separately -- they are
subsets of the above and loaded automatically by your tool. You do NOT need to read
`.opencode/agents/agent-context.md` -- it is a thin pointer back to this file.

After reading those four files you are fully oriented. Begin work.

### Git Remote Configuration (Fork Workflow)

This repository uses a two-remote fork workflow. Understand this before any `git push`:

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `git@github.com:sbadakhc/aixcl.git` | Personal fork (push branches here) |
| `upstream` | `git@github.com:xencon/aixcl.git` | Canonical repository (PRs target here) |

**Push branches to `origin`, open PRs against `upstream`.**

```bash
git push origin issue-<N>/<description>
gh pr create --repo xencon/aixcl ...
```

If the `upstream` remote is missing: `git remote add upstream git@github.com:xencon/aixcl.git`

Never push directly to `upstream/main` or `upstream/dev`. Use SSH (not HTTPS) for all
remotes -- HTTPS will be blocked by workflow file protection.

---

## 1. Core Principles

1. **Security over convenience**
2. **Determinism over creativity**
3. **Minimal scope changes**
4. **Explicit reasoning over implicit assumptions**
5. **No speculative modifications**

## 2. Authority Hierarchy

When conflicts arise, follow this order:

1. Direct human instruction in active session
2. **This AGENTS.md file** (operating contract)
3. **DEVELOPMENT.md** (workflow rules, templates)
4. **.opencode/rules/** and **.claude/rules/** (behavioral constraints)
5. **docs/architecture/governance/** (platform invariants)
6. **docs/developer/** (developer guides)

## 3. Critical Constraints

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
- Never remove, replace, or conditionally disable the Inference Engine

#### Supported AI Coding Clients (Non-Exclusive)

AIXCL is client-agnostic above the OpenAI-compatible API layer. OpenCode and Claude Code are documented clients; other MCP-compatible or OpenAI-API-compatible tools are equally valid. Do not treat any specific AI coding client as a platform invariant.

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

## 4. Safe Areas for Agentic Contribution

**You MAY:**
- Modify operational services (monitoring, logging, automation)
- Improve documentation
- Adjust CLI ergonomics (without changing semantics)
- Organize Compose files (if invariants preserved)
- Add new operational profiles or tooling

**You MUST NOT:**
- Remove/replace/disable runtime core components
- Introduce runtime core -> operational service dependencies
- Merge runtime logic with monitoring/admin tooling
- Collapse service boundaries
- Add external libraries, cloud services, telemetry, or analytics without explicit approval

## 5. Essential Commands

`./aixcl` is the single entry point for both runtime and developer workflow.

### Stack Operations
```bash
./aixcl utils check-env               # Validate environment prerequisites
./aixcl stack start --profile sys     # Start stack
./aixcl stack status                  # Check service health
./aixcl stack stop                    # Stop all services gracefully
```

### Validation, Tests, and Release
```bash
./aixcl checks all                    # Full local CI parity sweep (summary table)
./aixcl checks agents                 # Mirror parity only (.claude/.opencode)
./aixcl test all                      # Run every test suite
./aixcl test lib                      # Shell library unit tests (no stack needed)
./aixcl release status                # Where the current release cycle stands
```

## 6. Self-Verification Checklist

Before ANY operation, confirm:

- [ ] I have read AGENTS.md and DEVELOPMENT.md
- [ ] This change is explicitly requested and minimally scoped
- [ ] Sufficient repository evidence exists (no hallucination risk)
- [ ] Required issue exists or override is documented per Section 8
- [ ] No security principles are violated
- [ ] No unauthorized dependencies are introduced
- [ ] Merged files scanned for conflict markers (when merge performed)
- [ ] Staged diff reviewed before commit -- no unexplained mass deletions,
      no placeholder/elision text standing in for preserved content
      (verify: `./scripts/checks/check-ai-elisions.sh --staged`)

If ANY check fails -> **HALT** and escalate.

### Definition of Done

A task is complete only when ALL of the following are true:

- [ ] All CI checks are green (not just locally passing)
- [ ] `./scripts/checks/check-ai-elisions.sh --staged` ran clean before commit
- [ ] PR is approved and merged to `dev`
- [ ] Linked issue is closed
- [ ] No broken relative links introduced (run `bash scripts/checks/check-paths.sh`)

## 7. Escalation Procedures

When halting due to insufficient evidence, missing requirements, or conflicts:

1. **If working on an issue:** Post clarification question as issue comment
2. **If no issue exists:** Ask human operator directly; do not create issue unilaterally
3. **If security concern:** Flag with `[SECURITY]` prefix and await explicit approval
4. **If authority conflict:** Document override request, obtain explicit written confirmation

## 8. Emergency Workflow Override

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

## 9. Human in the Loop Checklist Policy

The agent MUST distinguish between agent-completed items and human-verification items.

| Party | Fills [x] | Example |
|-------|-----------|---------|
| Agent | Items the agent performed | "Issue referenced", "Branch named correctly" |
| Human | Items requiring manual verification | "Behavior works as expected", "No regressions observed" |

The human sees `[ ]` on verification items and ticks them during code review.

## 9.5 Agent Identification in GitHub Interactions

Every comment or PR body posted by an agent to GitHub **MUST** end with a standard identification block. This lets reviewers calibrate trust based on which agent, model, methodology, and scope produced the contribution.

### Required block format

Use plain ASCII only. Place the block at the end of the comment or PR body, after any substantive content:

```
---
- Agent: <agent name and model>
- Date: YYYY-MM-DD
- Method: <what the agent did, e.g. read-only repository scan>
- Scope: <files, issues, or context the agent had access to>
- Confirmation: <whether any code changes were made; yes/no>
---
```

### Required fields

| Field | Value |
|-------|-------|
| `Agent` | Tool name and model, e.g. `Claude Code (claude-sonnet-4-6)` or `OpenCode (ollama-cloud/kimi-k2.7-code)` |
| `Date` | Date the interaction was posted, in `YYYY-MM-DD` format |
| `Method` | Brief description of what the agent did, e.g. `read-only issue review and repository scan` |
| `Scope` | Files, directories, issues, or context the agent had access to when forming the comment |
| `Confirmation` | `yes` if the agent made code or file changes; `no` if it was read-only |

### When the block is required

- Agent-authored issue comments
- Agent-authored PR descriptions
- Agent-authored PR review comments
- Agent-authored issue bodies (when the agent creates issues under human direction)

### When the block is not required

- Commit messages (conventional commit format takes precedence)
- Internal tool outputs not posted to GitHub
- Human-authored content

## 10. Quick References

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

## 11. External References

- [DEVELOPMENT.md](DEVELOPMENT.md) -- Full workflow rules and templates
- [docs/developer/development-workflow.md](docs/developer/development-workflow.md) -- Complete developer guide
- [docs/architecture/governance/00_invariants.md](docs/architecture/governance/00_invariants.md) -- Platform invariants
- [docs/architecture/governance/01_ai_guidance.md](docs/architecture/governance/01_ai_guidance.md) -- Agentic behavioral guidance
- `.opencode/rules/workflow.md` -- OpenCode workflow constraints
- `.claude/rules/workflow.md` -- Claude Code workflow constraints
- `.claude/rules/discussions.md` / `.opencode/rules/discussions.md` -- GitHub
  Discussions policy (secret handling, untrusted-input treatment,
  advisory-only status)
- `opencode.json` -- OpenCode configuration

---

**Remember:** Security over convenience. Determinism over creativity. Minimal scope changes.
