---
name: Developer Workflow
description: Runs the AIXCL issue-first developer workflow end-to-end (issue, branch, commit, PR, assign and label).
---

You orchestrate the full AIXCL development workflow from this repository. Follow `docs/developer/development-workflow.md` exactly. Use only plain text (markdown checkboxes `- [x]`, no Unicode checkmarks or emoji). Do not use colons in issue or PR titles (e.g. "Fix CLI error" not "Fix: CLI error").

## Workflow steps (in order)

1. **Create an issue** (always first)
2. **Create a branch** from `main`
3. **Make changes and commit** (conventional commit, reference issue)
4. **Push and create PR** (link issue, then assign and add matching labels)
5. **Review and merge** (human step; you only remind)

You may run one step at a time and wait for the user to say "next" or "do step 2", or run several steps in sequence when the user asks (e.g. "create issue and branch"). When the user describes work (e.g. "add docs for Continue CLI"), infer a good issue title, body, and labels unless they specify them.

## Step 1 – Create issue

- Get assignee: `gh api user -q .login` (or `gh auth status`).
- Build: `gh issue create --title "..." --body "..." --label "..." --assignee <login>`.
- **Title:** Short, descriptive; no colon. Add **Type:** Bug / Feature / Task in the body and remind user to set type in GitHub UI.
- **Labels:** Comma-separated. Always include at least one component (e.g. `component:cli`, `component:ollama`). Add priority/profile/category as appropriate (see Label Guidelines in the workflow doc). Do not create or use a "Task" label; Task is an issue type only.
- After creation, output the new issue number and URL. Use this number for branch name and for "Fixes #N" in commits and PR.

## Step 2 – Create branch

- Ensure repo is clean or user has committed/stashed: `git status`.
- `git fetch origin main && git checkout main && git pull origin main`.
- Branch name: `issue-<number>/<short-description>` (e.g. `issue-412/add-continue-cli-docs`), or `feature/<name>`, `fix/<name>`, `refactor/<name>`.
- `git checkout -b <branch-name>`.

## Step 3 – Make changes and commit

- User makes edits (you may help with file edits if asked). When ready to commit:
- `git add <files>` (or `git add .` if appropriate).
- Commit message format:
  ```
  type: Brief description

  - Point 1
  - Point 2

  Fixes #<issue-number>
  ```
- Use types: `fix:`, `feat:`, `refactor:`, `docs:`, `test:`, etc. First line under 72 characters.
- Run: `git commit -m "..."` (use -m for first line and -m for body so Fixes #N is in body).

## Step 4 – Push and create PR

- `git push -u origin <branch-name>`.
- PR title: reference the issue without colon, e.g. `Fix Title (#<number>)` or `Add Continue CLI setup (#412)`.
- PR body: start with `Fixes #<number>` or `Addresses #<number>`, then e.g.:
  ```markdown
  ## Changes
  - [x] Change one
  - [x] Change two
  ## Testing
  - ...
  ```
- Run: `gh pr create --title "..." --body "..."`.
- Then assign and add the same labels as the issue: `gh pr edit <pr-number> --add-assignee <login> --add-label "component:cli" ...` (repeat --add-label for each label used on the issue).

## Step 5 – Review and merge

- Remind the user to review, address feedback, and merge via GitHub UI or CLI.

## Label reference (from workflow doc)

- **Component (at least one):** `component:runtime-core`, `component:ollama`, `component:llm-council`, `component:persistence`, `component:observability`, `component:ui`, `component:cli`, `component:infrastructure`, `component:testing`
- **Priority (optional):** `priority:high`, `priority:medium`, `priority:low`
- **Profile:** `profile:usr`, `profile:dev`, `profile:ops`, `profile:sys`
- **Category:** `Fix`, `Enhancement`, `Refactor`, `Maintenance`, `documentation`
- **Other:** `dependencies`, `good first issue`, `help wanted`, `question`

When the user says what they want to work on, propose the issue title, body snippet, and labels, then run step 1. Proceed to later steps only when the user confirms or asks for the next step.
