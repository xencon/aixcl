# Development Workflow Rules

| field         | value                                                                      |
|---------------|----------------------------------------------------------------------------|
| file          | DEVELOPMENT.md                                                             |
| version       | 2.0 (tracks workflow evolution; subordinate to AGENTS.md v1.2)             |
| scope         | all agents and AI assistants                                               |
| priority      | high                                                                       |
| compatibility | OpenCode, Claude Code, Cursor, Copilot, any MCP-compatible agent           |

Agents and AI assistants MUST read this file before performing any development work in this repository.
This file is the single source of truth for workflow, formatting, and contribution rules.
It complements `AGENTS.md` (the operating contract) and `ai/governance/` (behavioral constraints).

---

## 1. Before starting any task

Read the following documents before beginning work:

1. `AGENTS.md` — agent operating contract and authority hierarchy
2. `DEVELOPMENT.md` — workflow rules, issue and PR templates
3. `docs/developer/development-workflow.md` — full workflow guide
4. `docs/architecture/governance/` — platform invariants and service contracts

**VALIDATION REQUIRED:** If any documents in #3 or #4 are absent → **HALT** and create [TASK] issue: "Missing governance documentation". Await human clarification before proceeding.

---

## 2. Issue-first development

**Always create an issue before starting work.** Every code change, fix, or feature must be
traceable to a GitHub issue. Do not begin modifying files until an issue exists.

Select the correct template from `ai/templates/issue/` based on the type of work:

### Bug report - `ai/templates/issue/bug_report.md`

- Title prefix: `[BUG]`
- Labels: `priority:medium`, `profile:dev`
- Assignee: `<assignee>`
- Required sections: Bug Summary, Steps to Reproduce, Expected Behavior, Actual Behavior,
  Impact (component / severity / frequency), Root Cause Analysis, Remediation, Verification,
  Additional Context

### Feature request - `ai/templates/issue/feature_request.md`

- Title prefix: `[FEATURE]`
- Labels: `enhancement`
- Assignee: `<assignee>`
- Required sections: Feature Overview, Problem Statement, Current Behavior, Proposed Solution,
  Design Considerations, Implementation Plan, Verification

### Task / investigation - `ai/templates/issue/task.md`

- Title prefix: `[TASK]`
- Labels: `maintenance`
- Assignee: `<assignee>`
- Required sections: Task Summary, Background, Deliverables, Verification

Every issue must include a **Verification** section with concrete done-criteria before it is
considered ready to work.

```bash
gh issue create --title "[BUG] <title>" --label "priority:medium,profile:dev" --assignee <assignee>
gh issue create --title "[FEATURE] <title>" --label "enhancement" --assignee <assignee>
gh issue create --title "[TASK] <title>" --label "maintenance" --assignee <assignee>
```

---

## 3. Branch Strategy

### Main vs Dev Branches

This repository uses a **two-branch strategy**:

| Branch | Purpose | When to Use |
|--------|---------|-------------|
| `main` | Production-ready code | Only for releases and hotfixes |
| `dev` | Active development | All new features, fixes, and PRs |

### Workflow

1. **Create feature branches from `dev`:**
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b issue-<number>/<description>
   ```

2. **Push to `dev` via PR:**
   ```bash
   gh pr create --title "Description (#<issue>)" --base dev
   ```

3. **Merge to `main` when ready:**
   - Create PR from `dev` → `main` for releases
   - Or cherry-pick hotfixes directly to `main`

### Protected Branches

- `main`: Requires PR review, status checks pass
- `dev`: Requires status checks, PR recommended

### Branch naming

```
issue-<number>/<short-description>
feature/<short-description>
fix/<short-description>
```

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

---

## 5. Pull request format — `ai/templates/pr/pull_request.md`

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
gh pr create --title "<description> (#<number>)" --body "Fixes #<number>"
gh pr edit <number> --add-assignee <your-github-username> --add-label "component:..."
```

---

## 6. Formatting guidelines

- Use markdown checkboxes: `- [x]` for completed items — not Unicode checkmarks or emoji
- Use standard markdown: `**bold**`, `*italic*`, `` `code` ``
- Avoid special characters and non-ASCII symbols in technical documentation
- Use plain ASCII for cross-platform consistency

---

## 7. Governance references

Consult these before making architectural or structural decisions:

| Document | Purpose |
|---|---|
| `docs/architecture/governance/00_invariants.md` | Platform invariants — do not violate |
| `docs/architecture/governance/01_ai_guidance.md` | AI assistant behavioural guidance |
| `docs/architecture/governance/02_profiles.md` | Stack profile definitions |
| `docs/architecture/governance/03_stack_status.md` | Stack status specification |
| `docs/architecture/governance/service_contracts/` | Service dependency rules |

---

## 8. OpenCode-specific notes

When working via the OpenCode CLI:

- This file is loaded automatically via the `instructions` field in `opencode.json`
- The AIXCL local provider is configured in `opencode.json` — use `./opencode` to start a session
- Custom slash commands can be added under `.opencode/commands/`
- Custom agents can be added under `.opencode/agents/`
- Permissions for `bash`, `edit`, and `webfetch` tools are configured in `opencode.json`

---

## 9. Template locations summary

| Template | Path |
|---|---|
| Bug report | `ai/templates/issue/bug_report.md` |
| Feature request | `ai/templates/issue/feature_request.md` |
| Task / investigation | `ai/templates/issue/task.md` |
| Pull request | `ai/templates/pr/pull_request.md` |

---

## 10. Agent Compliance

Agents must confirm they've read AGENTS.md and verified compliance with its security model before starting any task.

---

## 11. Issue and PR Assignee Policy

**Issue and PR templates must use generic assignee placeholders, not specific usernames.**

- Use `<assignee>` placeholder in templates and documentation
- Never hardcode specific GitHub usernames 
- Individual issues/PRs can be manually assigned as needed
- This applies to: issue templates, PR templates, and workflow documentation

This rule prevents documentation from becoming outdated when team members change.

---
