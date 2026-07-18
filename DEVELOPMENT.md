# Development Workflow Rules

| field         | value                                                                      |
|---------------|----------------------------------------------------------------------------|
| file          | DEVELOPMENT.md                                                             |
| version       | 2.1 (tracks workflow evolution; subordinate to AGENTS.md v2.2)             |
| scope         | all agents                                                                 |
| priority      | high                                                                       |
| compatibility | OpenCode, Claude Code, Cursor, Copilot, any MCP-compatible agent           |

Agents MUST read this file before performing any development work in this repository.
This file is the single source of truth for workflow, formatting, and contribution rules.
It complements `AGENTS.md` (the operating contract) and `.opencode/rules/` (behavioral constraints).

---

## 1. Before starting any task

Read the four cold-start documents in the order given in **AGENTS.md Section 0** -- that list is canonical and is deliberately not repeated here. For the complete step-by-step workflow beyond this file, see `docs/developer/development-workflow.md`.

**VALIDATION REQUIRED:** If any document referenced by AGENTS.md Section 0 is absent -> **HALT** and ask the human operator directly, per AGENTS.md Section 7 (do not create issues unilaterally). Await human clarification before proceeding.

---

## 2. Issue-first development

**Always create an issue before starting work.** Every code change, fix, or feature must be
traceable to a GitHub issue. Do not begin modifying files until an issue exists.

Select the correct template from `.github/ISSUE_TEMPLATE/` based on the type of work.

**Labels are defined once, in AGENTS.md (Label Taxonomy) -- that section is
canonical.** In summary: exactly one type label (`Bug`, `Feature`, `Task`),
at least one `component:*` label (required), optional priority (`P1`-`P3`),
optional profile (`profile:bld`, `profile:sys`), optional category. Do not
invent labels outside that taxonomy.

### Bug report - `.github/ISSUE_TEMPLATE/bug_report.md`

- Title prefix: `[BUG]`
- Labels: `Bug` + required `component:*` (+ optional `P1`-`P3`, `profile:*`)
- Assignee: `<assignee>`
- Required sections: Bug Summary, Steps to Reproduce, Expected Behavior, Actual Behavior,
  Impact (component / severity / frequency), Root Cause Analysis, Remediation, Verification,
  Additional Context

### Feature request - `.github/ISSUE_TEMPLATE/feature_request.md`

- Title prefix: `[FEATURE]`
- Labels: `Feature` + required `component:*`
- Assignee: `<assignee>`
- Required sections: Feature Overview, Problem Statement, Current Behavior, Proposed Solution,
  Design Considerations, Implementation Plan, Verification

### Task / investigation - `.github/ISSUE_TEMPLATE/task.md`

- Title prefix: `[TASK]`
- Labels: `Task` + required `component:*`
- Assignee: `<assignee>`
- Required sections: Task Summary, Background, Deliverables, Verification

Every issue must include a **Verification** section with concrete done-criteria before it is
considered ready to work.

```bash
# IMPORTANT: Use --body-file (not inline --body) to prevent backtick command substitution.
# Never use inline --body with multiline strings containing backticks -- shell will
# execute them and inject output into the issue body.
cat > /tmp/issue-body.md << 'EOF'
## Summary
Brief description here.

## Deliverables
- [ ] Step 1
- [ ] Step 2
EOF
gh issue create --title "[BUG] <title>" --body-file /tmp/issue-body.md --label "Bug,component:<name>" --assignee <assignee>
gh issue create --title "[FEATURE] <title>" --body-file /tmp/issue-body.md --label "Feature,component:<name>" --assignee <assignee>
gh issue create --title "[TASK] <title>" --body-file /tmp/issue-body.md --label "Task,component:<name>" --assignee <assignee>
```

**Recommended**: Use the wrapper script `./scripts/utils/create-issue.sh` which handles validation, uses `/tmp`, and prevents both backtick injection and assignee race conditions.

---

## 3. Branch Strategy

### Main vs Dev Branches

This repository uses a **two-branch strategy** with clear promotion flow:

| Branch | Purpose | When to Use |
|--------|---------|-------------|
| `main` | Production-ready code | Final releases only |
| `dev` | Active development, feature integration | All feature development |

### Correct Workflow (Feature -> Dev -> Main)

**ALWAYS follow this path:**

```
Feature Branch -> Dev -> Main
      ^             ^       ^
   create         PR      PR
   from          merge   merge
   dev           (test)  (final test)
```

#### Step-by-Step

1. **Create feature branch FROM `dev`:**
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b issue-<number>/<description>
   ```

2. **Develop and quick test locally**

3. **Create PR to `dev`:**
   ```bash
   gh pr create --title "Description (#<issue>)" --base dev
   # Merge to dev after CODEOWNERS review
   ```

4. **Create PR from `dev` to `main` when ready for release:**
   ```bash
   gh pr create --title "Release X.Y.Z" --base main --head dev
   # Merge to main after final testing
   ```

   When creating a promotion PR from `dev` to `main`:
   - Use the same PR template as feature PRs
   - Title format: `Release X.Y.Z (#<release-issue>)`
   - Ensure all CI checks pass on `dev` before opening the promotion PR
   - Assign the PR and add `component:infrastructure` label

### Emergency Workflow Override

See AGENTS.md Section 8 -- Emergency Workflow Override for the protocol to proceed without a pre-existing issue when explicitly authorized by a human operator.

### INCORRECT Workflows

| Workflow | Status | Why |
|----------|--------|-----|
| `feature -> main` | WRONG | Bypasses dev testing |
| `main -> feature` | WRONG | Wrong base branch |
| `main -> dev` | WRONG | Dev feeds main, not vice versa |

### Emergency Hotfixes

For critical production fixes:
1. Create hotfix branch from `main`
2. Apply fix
3. Create PR to `main`
4. **Also** cherry-pick/cherry-pick to `dev` to keep branches synchronized

### Protected Branches

- `main`: Requires PR review, status checks pass
- `dev`: Requires status checks, PR recommended

### Branch naming

```
issue-<number>/<short-description>
feature/<short-description>
fix/<short-description>
```

### Fork Workflow

This project is developed both in the canonical repository and in forks
(e.g. app-builder forks doing local MVP work). The rules above assume the
canonical repo; forks follow these adaptations:

- **Remotes:** `origin` is your fork, `upstream` is the canonical repo
  (xencon/aixcl). Sync `dev`/`main` from upstream; never push to upstream
  directly -- contribute via PRs from the fork.
- **Local-only branches** (work that will not be pushed) may use the
  Emergency Workflow Override (AGENTS.md Section 8) standing for the
  duration of that work, since fork-local issues would never be triaged.
  All other rules (commit format, diff verification, CI checks run
  locally) still apply.
- **Capturing upstream defects:** platform problems discovered during
  fork work are recorded in `UPSTREAM-ISSUES.md` at the repository root
  -- one entry per candidate ticket with severity and suggested labels.
  The file is created on demand (it does not exist when the inventory is
  empty) and is exempt from the dated-reports lean policy. When an entry
  is filed as a real issue upstream, delete it from the file (the issue
  tracker takes over). Entry format:

  ```markdown
  ## <short title>
  - Severity: P1 | P2 | P3
  - Suggested labels: <type>, component:<name>
  - Observed: <what happened, where, how to reproduce>
  - Proposed fix: <one line, optional>
  ```
- **Before proposing fork work upstream:** scrub anything fork-specific
  (local tokens, machine paths, app experiments), squash exploratory
  history, and reference or create the upstream issue per the standard
  workflow.

---

## 4. Commit message format

Use conventional commits. Reference the issue number in every commit.

```
<type>: <description>

Fixes #<issue-number>
```

Allowed types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`, `ci`

- First line under 72 characters
- Use bullet points for multi-change commits
- Always include `Fixes #<n>` or `Addresses #<n>`
- **Review the staged diff before committing** (see the Pre-Commit
  Checklist in `.claude/rules/ci-checks.md` / `.opencode/rules/ci-checks.md`,
  and `./scripts/checks/check-ai-elisions.sh --staged`). Unexplained mass
  deletions and placeholder text are commit blockers, not review nits.

### GPG-Signed Commits

Commits pushed to `main` and `dev` **must be GPG-signed by the human
operator**. Honest scoping of this rule:

- CI reports unsigned commits on pushes to `main`/`dev`
  (`commit-signature-check.yml`) but the check is **non-blocking**;
  enforcement is by maintainer discipline.
- Agents running without a TTY cannot complete GPG pinentry. An agent
  asked to push signed commits must surface that limitation and hand the
  push to the operator -- never disable signing or bypass the requirement
  silently. Local working branches that are not pushed may be unsigned.

**Setup** (run once per developer):
```bash
./scripts/utils/setup-gpg.sh
```

This script:
- Checks for GPG installation
- Configures terminal for passphrase prompts (`GPG_TTY`)
- Generates or uses existing GPG key
- Configures Git for automatic signing

**Common error and fix**:
If you see `gpg: signing failed: Inappropriate ioctl for device`, run:
```bash
export GPG_TTY=$(tty)
# Or permanently add to ~/.bashrc:
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
```

**Verification**:
```bash
git log --show-signature --oneline -1
# Should show: gpg: Good signature from ...
```

---

## 5. Pull request format -- `.github/PULL_REQUEST_TEMPLATE.md`

All PRs must follow this structure exactly:

```markdown
# Pull Request

## Summary

Fixes #<ISSUE_NUMBER>

### Description of Changes

Provide a concise summary of changes.

### Change Checklist

- [ ] Issue referenced in title and description
- [ ] Branch is named correctly
- [ ] Commit messages follow conventional style
- [ ] All tests run and pass

### Testing Notes

Describe how this change was tested:

- Steps to reproduce (if relevant)
- What environments were used

### Verification

To verify this change is complete:

- Behavior works as expected
- No regressions observed
- Tests cover change

### Related Issues

- Closes #<ISSUE_NUMBER>
```

Additional PR rules:

- Title must reference the issue number: `<description> (#<number>)`
- No colons in PR titles (e.g. "Fix CLI error handling (#42)" not "Fix: CLI error handling (#42)")
- Labels and assignee must match the originating issue
- All CI checks must be green before the PR is considered complete

```bash
# CORRECT: Pass assignee and labels at creation time
gh pr create --title "<description> (#<number>)" --body "Fixes #<number>" --assignee <github-username> --label "component:..."

# INCORRECT: Two-step creates race condition
# gh pr create --title "..." --body "..." --assignee <github-username>
# gh pr edit <number> --add-label "component:..."
```

**Critical**: Always pass `--assignee` and `--label` to `gh pr create` at creation time. The PR Validation workflow fires immediately on PR creation. If the assignee or label is not set at creation time, the validation check will fail on the `opened` event. The fallback two-step (`create` then `gh pr edit`) creates a race condition where the first check run sees no assignee/label and permanently blocks the PR.

**Required**: Use the wrapper script `./scripts/utils/create-pr.sh` for all PRs. This script validates the title format, validates the branch name, uses `/tmp` for body files, and always passes `--assignee` and `--label` at creation time.

If you must use raw `gh pr create`, always include `--label`:
```bash
git push -u origin issue-<number>/<description>
gh pr create --title "<description> (#<number>)" --body "Fixes #<number>" --assignee <github-username> --label "component:..."
```

**Never** use `gh pr edit` to add labels after creation. The validation workflow has already fired and the failed check will persist.

**Workaround if race condition occurs:**
1. Close the PR
2. Reopen the PR immediately (this triggers a new check run)
3. Or: Merge with admin privileges if all current checks pass

---

## 6. Formatting guidelines

- Use markdown checkboxes: `- [x]` for completed items -- not Unicode checkmarks or emoji
- Use standard markdown: `**bold**`, `*italic*`, `` `code` ``
- Avoid special characters and non-ASCII symbols in technical documentation
- Use plain ASCII for cross-platform consistency

---

## 7. Governance references

Consult these before making architectural or structural decisions:

| Document | Purpose |
|---|---|
| `docs/architecture/governance/00_invariants.md` | Platform invariants -- do not violate |
| `docs/architecture/governance/01_ai_guidance.md` | Agent behavioural guidance |
| `docs/architecture/governance/02_profiles.md` | Stack profile definitions |
| `docs/architecture/governance/03_stack_status.md` | Stack status specification |
| `docs/architecture/governance/service_contracts/` | Service dependency rules |

---

## 8. OpenCode-specific notes

When working via the OpenCode CLI:

- This file is loaded automatically via the `instructions` field in `opencode.json`
- The AIXCL local provider is configured in `opencode.json` -- use `/connect` in the OpenCode TUI to select a provider, or connect to the local provider with `./aixcl stack start --profile sys`
- Custom agents can be added under `.opencode/agents/`
- Rules can be added under `.opencode/rules/`
- Permissions for `bash`, `edit`, and `webfetch` tools are configured in `opencode.json`

---

## 9. Template locations summary

| Template | Path |
|---|---|
| Bug report | `.github/ISSUE_TEMPLATE/bug_report.md` |
| Feature request | `.github/ISSUE_TEMPLATE/feature_request.md` |
| Task / investigation | `.github/ISSUE_TEMPLATE/task.md` |
| Pull request | `.github/PULL_REQUEST_TEMPLATE.md` |

---

## 10. Agent Compliance

Agents must confirm they've read AGENTS.md and verified compliance with its agent governance model before starting any task.

---

## 11. Issue and PR Assignee Policy

**Issue and PR templates must use generic assignee placeholders, not specific usernames.**

- Use `<assignee>` placeholder in templates and documentation
- Never hardcode specific GitHub usernames 
- Individual issues/PRs can be manually assigned as needed
- This applies to: issue templates, PR templates, and workflow documentation

This rule prevents documentation from becoming outdated when team members change.

---
