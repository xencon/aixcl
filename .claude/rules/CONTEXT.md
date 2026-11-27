# CONTEXT: .claude/rules/

Behavioral constraint files loaded automatically by Claude Code for every
session in this repository. Five files covering CI, formatting, security,
workflow, and Discussions.

## Contents

| File | What it constrains |
|------|-------------------|
| `ci-checks.md` | Pre-commit checklist, elision guard, CI workflow summary, ShellCheck flags |
| `formatting.md` | ASCII scope + terminal exception, PR/issue body no-hard-wrap rule, lazy-loading pointers |
| `security.md` | Untrusted-input rules (general + Discussions cross-ref); invariants/escalation point to AGENTS.md |
| `workflow.md` | Pointer to AGENTS.md/DEVELOPMENT.md for issue-first workflow and branch strategy |
| `discussions.md` | GitHub Discussions policy -- secret handling, untrusted-input treatment, advisory-only status |

## Agent Guidance

**You MAY:**
- Update rules files when AGENTS.md or DEVELOPMENT.md policy changes
- Add a new rules file if a new behavioral constraint category is needed

**You MUST NOT:**
- Contradict AGENTS.md -- these files are subordinate to AGENTS.md (authority hierarchy level 4)

## Cross-References

- `AGENTS.md` -- authoritative operating contract (these files are subordinate)
- `DEVELOPMENT.md` -- workflow rules that these files summarise
- `.claude/skills/` -- skills that enforce the rules defined here
