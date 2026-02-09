---
name: AIXCL Development Workflow
---

Follow the AIXCL Issue-First Development workflow for all changes:

1. Always create a GitHub issue before starting work using `gh issue create` with appropriate labels and `--assignee sbadakhc`
2. Create a branch with format `issue-<number>/<description>` from main
3. Commit using conventional format: `type: Description` with `Fixes #<number>` in the body
4. Push and create a PR referencing the issue with `gh pr create`
5. Assign the PR and add labels matching the issue

Use plain text formatting. Use markdown checkboxes `- [x]` instead of Unicode characters.
PR titles should NOT include colons.

Do not modify runtime core components (Ollama, LLM-Council, Continue).
Do not introduce dependencies from runtime core to operational services.
Prefer declarative configuration over imperative logic.
