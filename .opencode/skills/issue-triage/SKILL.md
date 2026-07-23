---
name: issue-triage
description: >
  Triage a GitHub issue end-to-end: verify the issue, check repo state and
  rules, investigate scope, draft and validate an approach, then verify with
  CI parity before pushing. Use when picking up an issue, starting work on
  one, or asked to "triage", "take issue N", "work on this issue". Triggers
  on GitHub issue URLs and issue numbers.
argument-hint: <issue number or GitHub issue URL>
compatibility: OpenCode, Claude Code
metadata:
  category: workflow
  version: "1.0"
---

# Issue Triage

Run these steps in order. Present findings before taking action. Detailed
command references live in [references/triage-playbook.md](references/triage-playbook.md).

## Pre-flight

- `gh auth status` works; `git remote -v` shows `origin` (fork) and
  `upstream` (canonical) -- push to origin, PR against upstream
- Read project memory for context on this issue and prior decisions

## Step 0: Repo housekeeping

`git status`, `git stash list`, `git branch --show-current`. Verify `dev` is
current against the real base: `git fetch upstream && git log --oneline
dev..upstream/dev`. Flag uncommitted work or drift before starting.

## Step 1: Read the issue

Fetch live -- never trust cached context:

```bash
gh issue view <N> --repo xencon/aixcl --json title,body,labels,assignees,state
```

Verify: assignee set, `component:*` label present, title format
`[TYPE] Description` with no colons. Check referenced issues/PRs for prior
art or a parent effort.

## Step 2: Scope the change

Classify against AGENTS.md: safe area (operational services, docs, CLI
ergonomics, tooling) or invariant territory (runtime core, service
boundaries, host networking)? Invariant-adjacent work needs explicit operator
sign-off before any code.

## Step 3: Rules compliance checklist

Read the rules that apply to the touched file types (`.claude/rules/`,
DEVELOPMENT.md) and the target directory's `CONTEXT.md`. Write down the
checklist you will be held to (mirror parity, ASCII, shellcheck, pin
hygiene, ...) -- CI enforces these later; violating them now compounds.

## Step 4: Investigate and draft an approach

1. Read the relevant code; prefer extending existing `lib/` and `scripts/`
   patterns over building parallel ones
2. Check for existing work: merged PRs touching the same paths, sibling
   issues
3. Classify the work -- one-time verification scripts belong in the session
   scratchpad, not the repo
4. Flag discovered gaps as candidate issues for the operator to decide on;
   do not auto-create scope
5. Draft the approach: what changes, where, how it is verified

## Step 5: Validate the design -- hard gate for non-trivial work

For anything with multiple plausible approaches, invariant contact, or
sparse issue description: run the grill-with-docs skill against the draft
and present the surviving approach to the operator before writing code. A
30-minute design conversation is cheaper than a reversed PR.

## Step 6: Implement

Branch `issue-<N>/<short-description>` from current `dev`. Follow the rules
checklist from Step 3 as you go, not retroactively.

## Step 7: Pre-PR verification -- CI parity

Run everything CI will run, locally, before pushing:

```bash
./aixcl checks all
shellcheck --severity=warning --exclude=SC1091 <changed .sh files>
./scripts/checks/check-ai-elisions.sh --staged
```

Then self-review the staged diff: no unexplained deletions, no stray scope,
commit message `<type>: <description>` with `Fixes #<N>`.

## Step 8: Commit and PR

Stage and hand the GPG commit command to the operator (never commit
yourself). After signing: push to origin, create the PR against upstream
`dev` with title `<description> (#<N>)`, assignee and `component:*` label at
creation time, body validated with `scripts/checks/check-pr-references.sh`.

## Step 9: Update the issue

Tick deliverable checkboxes only with evidence. Comment with findings and
the agent identification block (AGENTS.md 9.5). Writing rules: short direct
sentences, plain ASCII, one reference per list item, keep the issue body the
source of truth -- rewrite it if the approach changed; comments are history.

## Step 10: Close the loop

Before merge: `./aixcl checks pr-ready <PR>`. After merge: sync dev, delete
the branch, confirm the issue closed. Record new friction points or
decisions in project memory.
