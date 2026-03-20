
# Workflow Governance

## Core Rule
All changes must follow Issue-First Development.

## Non-Negotiable Constraints
- No PR without linked issue
- No branch without issue number
- Conventional commit format required
- Issue and PR titles must use uppercase type in brackets: `[TYPE] Description` (e.g., `[TASK]`, `[BUG]`, `[FEATURE]`)
- PR must reference issue at the bottom (e.g., `Fixes #123`)
- Matching labels between Issue and PR
- All issues and PRs must have at least one assignee
- Plain text formatting only (ASCII, markdown checkboxes)
- Issue type must be Bug, Feature, or Task
- Verified CI success for all PRs (all status checks must be green)

## Standard Formatting Templates
All Issues and PRs must follow a consistent markdown body structure. When using CLI tools, do not use literal `\n` escape characters in inline strings as they break formatting; instead, use interactive editors or multiline string passing.

### Issue Body Template
```markdown
## Description
[Clear description of the bug, feature, or task]

## Context/Additional Information
[Any relevant background, screenshots, or logs]
```

### Pull Request Body Template
```markdown
## Summary
[Brief description of the changes being made]

## Changes
- [File/Component]: [What was changed]
- [File/Component]: [What was changed]

Fixes #[Issue Number]
```

## Label Taxonomy Rules
- Task is an issue type, not a label
- Fix pairs with Bug
- Enhancement pairs with Feature
- Refactor pairs with Task
- Component labels required (e.g., `component:runtime-core`, `component:api`)
- Priority and Profile labels optional but recommended (e.g., `P1`, `P2`, `P3`)

## Automated PR Rule
If automated PRs bypass issue-first:
1. Merge after review
2. Create retrospective issue documenting PR numbers

## Lint Requirement
If modifying agent-*.md, skill-*.md, or ai-report-*.md:
MD files are the sole governance artifacts. No external script is required.
