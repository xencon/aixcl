---
name: "Task / Investigation"
about: "Capture a task or investigation work"
title: "[TASK] "
labels: ["Task"]
assignees: ["<assignee>"]
---

<!-- Add the required component:* label (and optional P1-P3 priority) when creating this issue; see AGENTS.md Label Taxonomy. -->

<!-- IMPORTANT: When creating via CLI, use --body-file or quoted HEREDOC to prevent backtick command substitution. Do not use inline --body with multiline strings containing backticks. -->

<!-- REFERENCES: List one issue/PR reference per line. Do not comma-pack multiple #N references on a single line. -->

## Task Summary
Describe what needs to be done.

### Background
Context, related issues, references.

### Deliverables
- [ ] Task step 1
- [ ] Task step 2

### Verification
- [ ] Confirm task completion
- [ ] Note results/findings

## Human in the Loop

The agent is responsible for completing all deliverables. The human is responsible for completing the verification checklist.
