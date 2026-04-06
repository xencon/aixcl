---
name: Action Dependency Visualization
description: Visualizes the relationships between actions in the AIXCL Issue-First workflow
category: documentation
tool: none
requires: []
---

# Action Dependency Visualization

This document visualizes the relationships and dependencies between actions in the AIXCL Issue-First workflow.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AIXCL Issue-First Workflow                        │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  1. CREATE ISSUE                                                   │
│     Action: action-create-issue.md                                  │
│     Command: /issue                                                 │
│     Requires: gh CLI, GitHub auth                                   │
│     Outputs: Issue number (e.g., #217)                              │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Validation:                                                 │   │
│  │  • Component label applied (REQUIRED)                      │   │
│  │  • Assignee set (REQUIRED)                                 │   │
│  │  • Issue type selected in GitHub UI (Bug/Feature/Task)   │   │
│  │  • Title format: [TYPE] Description (no colons)            │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. CREATE BRANCH                                                    │
│     Action: action-create-branch.md                                 │
│     Command: /branch                                                │
│     Requires: git, issue number                                     │
│     Outputs: Feature branch                                         │
│                                                                     │
│     Format: issue-<number>/<description>                              │
│     Example: issue-217/setup-agent-template                         │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. MAKE CHANGES                                                     │
│     Agent: agent-context.md                                         │
│     Mode: /mode building                                            │
│     Activities:                                                      │
│     • Code implementation                                           │
│     • Documentation updates                                         │
│     • Test creation                                                   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. COMMIT                                                           │
│     Action: action-commit.md                                        │
│     Command: /commit                                                │
│     Requires: git, staged changes, issue number                     │
│     Outputs: Committed changes                                        │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Format:                                                     │   │
│  │  <type>: <short description>                                 │   │
│  │                                                              │   │
│  │  <optional body>                                             │   │
│  │                                                              │   │
│  │  Fixes #<issue-number>                                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  5. CREATE PR                                                        │
│     Action: action-create-pr.md                                     │
│     Command: /pr                                                    │
│     Requires: gh CLI, pushed branch, issue number                   │
│     Outputs: Pull request                                             │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Title Format: <Description> (#<number>)                     │   │
│  │  Example: "Setup agent template (#217)"                      │   │
│  │                                                              │   │
│  │  ⚠️ NO colons in title!                                      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Validation:                                                 │   │
│  │  • PR title has no colons (REQUIRED)                        │   │
│  │  • Issue referenced in body (REQUIRED)                     │   │
│  │  • Labels match issue (REQUIRED)                           │   │
│  │  • Assignee set (REQUIRED)                                 │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  6. VERIFY CI                                                        │
│     Action: action-verify-ci.md                                     │
│     Command: /verify                                                │
│     Requires: gh CLI, PR created                                      │
│     Outputs: CI status                                                │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Required Checks:                                            │   │
│  │  • All GitHub Actions workflows pass                         │   │
│  │  • Lint checks pass                                          │   │
│  │  • Tests pass                                                │   │
│  │  • Security scans pass                                         │   │
│  │                                                              │   │
│  │  ⚠️ Task NOT complete until all checks green!                │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  ✓ READY TO MERGE                                                   │
│     Requirements:                                                    │
│     • Code review approval                                            │
│     • All CI checks passing                                           │
│     • No conflicts                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Action Relationships

### Sequential Dependencies

| Action | Depends On | Produces | Next Step |
|--------|-----------|----------|-----------|
| Create Issue | - | Issue # | Create Branch |
| Create Branch | Issue # | Feature branch | Make Changes |
| Commit | Changes, Issue # | Commits | Create PR |
| Create PR | Commits, Branch, Issue # | Pull request | Verify CI |
| Verify CI | PR # | CI status | Merge |

### Data Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Issue #   │────▶│   Branch    │────▶│   Commits   │
│  (source)   │     │  (issue-#)  │     │ (Fixes #)   │
└─────────────┘     └─────────────┘     └──────┬──────┘
       │                                       │
       │         ┌─────────────────────────────┘
       │         │
       ▼         ▼
┌─────────────┐     ┌─────────────┐
│  PR Body    │◀────│     PR      │
│ (Fixes #)   │     │ (# in title)│
└─────────────┘     └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  CI Checks  │
                    │   (green)   │
                    └─────────────┘
```

## Cross-Cutting Actions

These actions support the workflow but aren't part of the linear sequence:

### Validation Actions

```
Workflow Step ────────────────▶ Validation Action

Create Issue ──────────────────▶ Check Labels
                                (action-create-issue.md)
                                  • Component (REQUIRED)
                                  • Priority (optional)
                                  • Profile (optional)

Create Branch ─────────────────▶ Check Naming
                                (action-create-branch.md)
                                  • issue-<#>/description

Commit ────────────────────────▶ Check Format
                                (action-commit.md)
                                  • Conventional format
                                  • Fixes #<issue>

Create PR ─────────────────────▶ Check Compliance
                                (action-create-pr.md)
                                  • No colons in title
                                  • Labels match issue
                                  • Assignee set
```

### Utility Actions

```
┌────────────────────────────────────────────────────────┐
│                   Utility Actions                       │
├────────────────────────────────────────────────────────┤
│                                                         │
│  action-detect-workflow-state.md                      │
│   └── Detect current state and suggest next step        │
│                                                         │
│  action-lint-agents.md                                  │
│   └── Validate agent/action file structure              │
│                                                         │
│  action-icon-usage.md                                   │
│   └── ASCII-only guidelines                             │
│                                                         │
└────────────────────────────────────────────────────────┘
```

## Command Hierarchy

### Primary Commands

```
/workflow          (runs full sequence)
    │
    ├──▶ /issue   (step 1)
    ├──▶ /branch  (step 2)
    │     └── requires issue #
    ├──▶ /commit  (step 4)
    │     └── requires changes
    ├──▶ /pr      (step 5)
    │     └── requires branch + commits
    └──▶ /verify  (step 6)
          └── requires PR
```

### Support Commands

```
/actions           (list all actions)
/lint              (validate structure)
/mode planning     (analysis mode)
/mode building     (development mode)
/mode reviewing    (review mode)
```

## Validation Gates

```
┌─────────────────────────────────────────────────────────┐
│                    Validation Gates                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  [Issue Created]                                        │
│    ✓ Has component label (REQUIRED)                    │
│    ✓ Is assigned (REQUIRED)                            │
│    ✓ Title format correct                              │
│                                                          │
│  [Branch Created]                                       │
│    ✓ Named: issue-<#>/<description>                    │
│    ✓ Based on latest main                              │
│                                                          │
│  [Commit Made]                                          │
│    ✓ Conventional format                               │
│    ✓ References issue                                  │
│                                                          │
│  [PR Created]                                           │
│    ✓ Title: <Description> (#<#>)                       │
│    ✓ No colons in title                                │
│    ✓ Body references issue                             │
│    ✓ Labels match issue                                │
│    ✓ Is assigned                                       │
│                                                          │
│  [CI Verified]                                          │
│    ✓ All checks pass                                   │
│    ✓ Tests pass                                        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## State Detection Points

The workflow can be resumed from any state:

```
┌─────────────────────────────────────────────────────┐
│                  State Detection                     │
├─────────────────────────────────────────────────────┤
│                                                       │
│  Check: Current branch                               │
│   • On main → Start at /issue                        │
│   • On issue-<#>/* → Resume from current             │
│                                                       │
│  Check: Uncommitted changes                          │
│   • git status clean → Ready for /commit             │
│   • Modified files → Prompt to /commit              │
│                                                       │
│  Check: Existing PR                                  │
│   • PR exists → Skip to /verify                      │
│   • No PR → Create with /pr                          │
│                                                       │
│  Check: CI Status                                    │
│   • All green → Ready to merge                       │
│   • Pending/failing → Investigate                    │
│                                                       │
└─────────────────────────────────────────────────────┘
```

## Common Workflows

### Full Workflow (Recommended)

```
/workflow "Add feature X"
    ↓
[Issue #217 created with labels, assigned]
    ↓
[Branch issue-217/add-feature-x created]
    ↓
[Work on implementation]
    ↓
[Changes committed: "feat: Add feature X\n\nFixes #217"]
    ↓
[PR #42 created: "Add feature X (#217)", labeled, assigned]
    ↓
[CI checks: ✓ lint ✓ test ✓ security]
    ↓
[Ready to merge ✓]
```

### Quick Fix Workflow

```
/issue "Fix bug in Y"
    ↓
/branch 218
    ↓
[Fix the bug]
    ↓
/commit fix: Resolve bug in Y
    ↓
/pr Fix bug in Y
    ↓
/verify
```

### Resume Existing Work

```
/workflow
    ↓
[State detected: On branch issue-217, 3 commits, no PR]
    ↓
User: "Create PR"
    ↓
/pr
    ↓
/verify
```

## File Locations

```
ai/actions/
├── action-create-issue.md          (Step 1)
├── action-create-branch.md         (Step 2)
├── action-commit.md                (Step 4)
├── action-create-pr.md             (Step 5)
├── action-verify-ci.md             (Step 6)
├── action-detect-workflow-state.md  (State detection)
├── action-lint-agents.md           (Validation)
└── action-icon-usage.md            (Style guide)

.opencode/commands/
├── issue.md                        (Command: /issue)
├── branch.md                       (Command: /branch)
├── commit.md                       (Command: /commit)
├── pr.md                           (Command: /pr)
├── verify.md                       (Command: /verify)
├── workflow.md                     (Command: /workflow)
├── lint.md                         (Command: /lint)
└── actions.md                      (Command: /actions)
```

## Notes

- **Issue # is the anchor** - Every step references the original issue
- **Labels flow forward** - Issue labels → PR labels (MUST match)
- **Assignment required** - Both issue and PR must be assigned
- **No colons in titles** - Issue titles: `[TYPE] Desc` - PR titles: `Desc (#<#>)`
- **CI is the gate** - Task not complete until all checks pass
- **Mode matters** - Use `/mode planning` before coding, `/mode building` to implement
