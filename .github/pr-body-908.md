## Summary

Adds automated checks to enforce PR formatting standards from AGENTS.md.

## Problem Statement

Recent audit of last 10 PRs found formatting compliance issues:
- **70%** Missing issue reference in title
- **50%** Missing assignee
- **50%** Missing component labels

## Solution

New GitHub workflow `.github/workflows/pr-validation.yml` with 3 jobs:

| Job | Check | Error Message |
|-----|-------|---------------|
| validate-pr-title | Ends with `(#<number>)` | "PR title must end with issue reference" |
| validate-pr-title | No colons before issue ref | "PR title should not contain colons" |
| validate-pr-assignee | Has assignee | "PR must have at least one assignee" |
| validate-pr-labels | Has `component:*` label | "PR must have at least one component label" |

## Standards Enforced

Per AGENTS.md:
- **Title**: `<description> (#<number>)` (NO colons)
- **Labels**: Must include `component:*` (e.g., component:cli)
- **Assignee**: Required (no PRs unassigned)

## Verification

- [x] Workflow syntax validated
- [x] Checks match AGENTS.md requirements
- [x] Runs on PR open, edit, sync, reopen
- [x] Targets main and dev branches

## Impact

Future PRs will be **blocked** at CI time if they don't comply with formatting standards. This prevents documentation drift and ensures consistency.
