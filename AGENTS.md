| field | value |
|-------|-------|
| file | AGENTS.md |
| version | 1.6 |
| purpose | agent_bootstrap |
| priority | critical |
| compatibility | OpenCode, Claude Code, Cursor, Copilot, MCP-compatible systems |
| last_updated | 2026-05-14 |

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
4. **.opencode/rules/** (behavioral constraints)
5. **docs/architecture/governance/** (platform invariants)
6. **docs/developer/** (developer guides)

## Critical Constraints

### Issue-First Development (MANDATORY)

**ALWAYS create an issue before starting work.** No exceptions without explicit override.

**Override mechanism:** See Section 9 -- Emergency Workflow Override.

**Issue format:**
- Title: `[TYPE] Description` (NO colons in title, e.g. `[TASK] Setup agent`, not `[TASK]: Setup agent`)
- Body: **Read the template file first**, then use its exact section headings
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

**PR creation -- pass labels at creation time**

The PR Validation workflow fires on the `opened` event. Labels and assignees must be passed together to `gh pr create` to prevent a race condition.

**Required approach:**
```bash
# Use the wrapper script (validates title, passes --label and --assignee)
./scripts/utils/create-pr.sh "<title> (#<number>)" "Fixes #<number>" "component:cli" "<username>"

# Or pass explicitly:
git push -u origin issue-<number>/<description>
gh pr create --title "<description> (#<number>)" --body "Fixes #<number>" --assignee <username> --label "component:..."
```

**Never** use two-step creation (`gh pr create` then `gh pr edit --add-label`). The fallback creates a race condition where the first validation run sees no labels and permanently blocks the PR. See DEVELOPMENT.md for details.

**Post-creation label enforcement (issues only)**
```bash
gh issue edit <number> --add-label "component:cli" --add-assignee <username>
```

**Template loading (MANDATORY before composing any issue/PR body)**
```bash
# Read the template first, then compose the body using its exact headings
cat .github/ISSUE_TEMPLATE/task.md
cat .github/ISSUE_TEMPLATE/bug_report.md
cat .github/ISSUE_TEMPLATE/feature_request.md
cat .github/PULL_REQUEST_TEMPLATE.md
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
- Profile: `profile:bld`, `profile:sys`
- Category: `Fix`, `Enhancement`, `Refactor`, `Maintenance`

## Platform Invariants (NON-NEGOTIABLE)

### Fixed Core Runtime

- **Inference Engine** (Ollama) - Docker-managed, always enabled
- **OpenCode** - Agentic coding assistant, always enabled
- Never remove, replace, or conditionally disable runtime core components

### Runtime vs Operational Services Boundary

- Runtime core must be runnable **without** operational services
- Runtime core must **never** depend on operational services
- Network mode: `host` networking for all services (by design)

## Essential Commands

### Stack Operations
```bash
./aixcl utils check-env               # Validate environment prerequisites
./aixcl stack start --profile sys    # Start stack: bld/sys
./aixcl stack status                  # Check service health
./aixcl stack logs engine             # View inference logs
./aixcl stack stop                    # Stop all services gracefully
./aixcl stack logs -f                 # Follow logs for all services
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
```

### Validation & Lint
```bash
./scripts/checks/check-agents.sh      # Lint .opencode/agents/agent-*.md, .opencode/skills/*/SKILL.md
./scripts/checks/check-environment.sh # Full environment check
```

### OpenCode CLI
```bash
opencode                              # Start OpenCode session (global binary; repo provides opencode.json)
```

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

## Lean Repository Policy

The AIXCL repository follows a **lean repository** philosophy to maintain clarity and freshness:

### Principles

1. **Delete, Don't Archive**
   - Outdated reports and dated documentation should be **deleted**, not moved to archive directories
   - Historical data belongs in Git history, not in the working tree
   - Archive directories accumulate stale content and create confusion

2. **Fresh Information Only**
   - Operations reports should be current (within 30 days)
   - Test results should be generated on-demand, not stored
   - Documentation should reflect the current state of the codebase

3. **Generated Files Stay Generated**
   - Files that can be regenerated should not be committed
   - Test outputs, logs, and reports are generated artifacts
   - Use `.gitignore` to prevent accidental commits

### Examples

| What | Policy | Action |
|------|--------|--------|
| Dated operations reports (>30 days) | DELETE | `git rm docs/operations/report-2026-01-01.md` |
| Test result files | DELETE | `git rm tests/test-results.md` |
| Old engine test results | DELETE | `git rm ENGINE_TEST_RESULTS.md` |
| Backup directories | DELETE | `rm -rf tests/.backup/*` |

### Verification

Agents should verify:
- No dated reports are in the repository
- No generated files are tracked in Git
- Archive directories are empty or removed

## Self-Verification Checklist

Before ANY operation, confirm:

- [ ] I have read AGENTS.md and DEVELOPMENT.md
- [ ] This change is explicitly requested and minimally scoped
- [ ] Sufficient repository evidence exists (no hallucination risk)
- [ ] Required issue exists or override is documented per Section 8
- [ ] No security principles are violated
- [ ] No unauthorized dependencies are introduced
- [ ] **Merged files scanned for conflict markers** (when merge was performed)

If ANY check fails → **HALT** and escalate.

## Escalation Procedures

When halting due to insufficient evidence, missing requirements, or conflicts:

1. **If working on an issue:** Post clarification question as issue comment
2. **If no issue exists:** Ask human operator directly; do not create issue unilaterally
3. **If security concern:** Flag with `[SECURITY]` prefix and await explicit approval
4. **If authority conflict:** Document override request in a new `[TASK]` issue; obtain explicit written confirmation; prefix commits with `[OVERRIDE]` if proceeding. **NEVER silently bypass issue-first requirement.**

## 9. Emergency Workflow Override

In exceptional situations, a human operator may explicitly authorize the agent to proceed without a pre-existing issue. This is NOT the default path and must be clearly authorized per session.

### Authorization (Required)

The human operator must provide a **direct, explicit instruction** in the active session. Example:

> "[OVERRIDE] Proceed without creating an issue first. Create a retroactive issue afterward."

### Conditions

- The override applies ONLY to the specific change being discussed
- All OTHER rules still apply: branch naming, commits, GPG signing, PRs, CI verification
- The change must be minimal and reversible

### Retroactive Documentation (Required)

After completing the work, the agent MUST create a [TASK] issue prefixed with [OVERRIDE]:

```bash
./scripts/utils/create-issue.sh "[OVERRIDE] Retroactive documentation for X" "task" "component:cli,Maintenance" "<assignee>"
```

The retroactive issue must document:

- The original human instruction (quoted verbatim)
- The reason the override was granted
- The changes made and the PR that resulted

### Commit Format Under Override

Prefix the commit subject with [OVERRIDE]:

```
[OVERRIDE] type: Brief description

- Change details

Fixes #<retroactive-issue-number>
```

### What DOES NOT Qualify

- "Just do it" without context
- Vague urgency ("this is important")
- Agent inferring urgency from tone

## 10. Checklist Filling Policy (Human in the Loop)

The agent MUST distinguish between agent-completed items and human-verification items.

| Party | Fills [x] | Example |
|-------|-----------|---------|
| Agent | Items the agent performed | "Issue referenced", "Branch named correctly" |
| Human | Items requiring manual verification | "Behavior works as expected", "No regressions observed" |

The human sees [ ] on verification items and ticks them during code review. The checklist serves as a gate, not passive decoration.

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

## 11. House Keeping

Session hygiene, metadata management, and clean-up verification.

### Release Metadata Standardization

When retroactively editing or creating GitHub releases:

```bash
# Prepare body files in /tmp (never repo tree)
cat > /tmp/vX.Y.Z-body.md << 'EOF'
## AIXCL vX.Y.Z
...
EOF

# Edit release title and body
gh release edit vX.Y.Z --title "AIXCL vX.Y.Z" --notes-file /tmp/vX.Y.Z-body.md

# Batch many releases
for tag in v1.1.10 v1.1.9 ...; do
  gh release edit "$tag" --title "AIXCL ${tag}" --notes-file "/tmp/${tag}-body.md"
done

# Remove prerelease flag if needed
gh release edit vX.Y.Z --prerelease=false
```

Caveat: `gh release edit` mutates GitHub metadata, not git history. The tag and commit remain immutable.

### RC Release Naming Convention

RC releases keep the `-rcN` suffix in both tag and title:
- Tag: `v1.0.0-rc9`
- Title: `AIXCL v1.0.0-rc9`

Do not strip the `-rc` suffix from the title. Multiple RCs sharing the same display name causes confusion.

### Body Pre-population Rule

**NEVER create an issue, PR, or release with a generic or empty body.**

Before creating any item, draft the complete body in `/tmp/`:

1. **Read the template first** (lazy-loading)
2. **Draft the complete body in `/tmp/`** -- every section populated with real content
3. **Confirm zero placeholder text** exists (no "Describe what needs to be done")
4. **Confirm checkboxes are pre-filled correctly:**
   - `[x]` = Agent has already completed this step
   - `[ ]` = Requires human verification
5. Use `cat /tmp/body.md` to review the full body before creation

**Important tool distinction:**

| Tool | Supports custom body | When to use |
|------|----------------------|-------------|
| `./scripts/utils/create-issue.sh` | No | Quick creation using template only (default body) |
| `./scripts/utils/create-pr.sh` | No | Quick creation using template only (default body) |
| `gh issue create --body-file` | Yes | Pre-populated issues (drafted in /tmp first) |
| `gh pr create --body-file` | Yes | Pre-populated PRs (drafted in /tmp first) |
| `gh release edit --notes-file` | Yes | Release notes (drafted in /tmp first) |

For pre-populated issues and PRs, use raw `gh` commands with `--body-file`:

```bash
# Correct: draft full body first via heredoc, review visually, then create
cat > /tmp/issue-body.md << 'EOF'
...
EOF
cat /tmp/issue-body.md  # Review before creation

gh issue create --title "[TASK] Title" --body-file /tmp/issue-body.md --label "component:..." --assignee "..."
```

### Release Template Compliance Checklist

Before creating or editing a release, verify it matches `.github/RELEASE_TEMPLATE.md` v3.0:

| Element | Required |
|---------|----------|
| Title prefix | `AIXCL ` |
| Top heading | `## AIXCL vX.Y.Z` |
| Sections | `Added`, `Changed`, `Fixed`, `Removed` |
| Item prefix | `✅ ` |
| Item suffix | `(#issue-number)` |
| Docs section | Relative paths (e.g., `README.md`) |
| No blocks | No `Installation`, no `Related Issues` |

### House Keeping Verification

Before deleting branches or temp files, verify state:

```bash
gh pr view <number> --json state     # Ensure MERGED
git branch -vv | grep issue-<n>      # Check if local exists
git push origin --delete <branch>      # Only if remote exists
rm -f /tmp/v1.*-body.md               # Remove temp release bodies
```

### Do Not Close Issues That PRs Will Auto-Close

If an issue is referenced in an **open** PR body with `Fixes #N`, **do not manually close it**.
GitHub will auto-close it on PR merge.

Manual closure breaks the auto-close link and creates orphaned issues.

Exception: If the PR is closed without merging, then manually close the issue.

### Merge Conflict Prevention

**Always review merged files for conflict markers before committing.**
**This rule applies to ALL merges, including promotion PRs (dev -> main).**

After any `git merge`, BEFORE committing or pushing:

```bash
# After resolving a merge, scan for residual markers
grep -r "<<<<<<<\|=======\|>>>>>>>" --include="*.md" --include="*.sh" --include="*.yml" .

# If any results found:
# 1. Open the file and resolve manually
# 2. Re-stage: git add <file>
# 3. Amend commit: git commit --amend -S -m "message"
```

**Key rules:**
- Never push a merge without reviewing file content for `<<<<<<<` markers
- If markers exist, resolve the conflict properly -- do not commit the raw markers
- Run the grep command as part of pre-push verification

## External References

- `DEVELOPMENT.md` -- Full workflow rules and templates
- `docs/developer/development-workflow.md` -- Complete developer guide
- `docs/architecture/governance/00_invariants.md` -- Platform invariants
- `docs/architecture/governance/01_ai_guidance.md` -- Agentic behavioral guidance
- `.opencode/rules/workflow.md` -- Workflow constraints
- `opencode.json` -- OpenCode configuration

---

**Remember:** Security over convenience. Determinism over creativity. Minimal scope changes.
