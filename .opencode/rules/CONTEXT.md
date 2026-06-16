# CONTEXT: .claude/rules/

Behavioral constraint files loaded automatically by Claude Code for every
session in this repository. Five files covering CI, formatting, security,
workflow, and Discussions.

## Contents

| File | What it constrains |
|------|-------------------|
| `ci-checks.md` | Pre-commit checklist, elision guard, CI workflow summary, ShellCheck flags |
| `formatting.md` | Title formats (no colons), ASCII mandate, label taxonomy, commit types |
| `security.md` | Runtime core invariants, safe vs prohibited areas for agents |
| `workflow.md` | Issue-first step-by-step, branch strategy, PR requirements |
| `discussions.md` | GitHub Discussions policy -- secret handling, untrusted-input treatment, advisory-only status |

## Mirror Parity -- CRITICAL

These five files are byte-identical mirrors of `.opencode/rules/`:

```
.claude/rules/ci-checks.md     <-->  .opencode/rules/ci-checks.md
.claude/rules/formatting.md    <-->  .opencode/rules/formatting.md
.claude/rules/security.md      <-->  .opencode/rules/security.md
.claude/rules/workflow.md      <-->  .opencode/rules/workflow.md
.claude/rules/discussions.md   <-->  .opencode/rules/discussions.md
```

**If you edit any file here, edit the corresponding file in `.opencode/rules/`.**

Verify parity before committing:
```bash
diff .claude/rules/workflow.md .opencode/rules/workflow.md
diff .claude/rules/formatting.md .opencode/rules/formatting.md
diff .claude/rules/ci-checks.md .opencode/rules/ci-checks.md
diff .claude/rules/security.md .opencode/rules/security.md
diff .claude/rules/discussions.md .opencode/rules/discussions.md
```

The `check-agents.sh` script also validates this parity.

## Agent Guidance

**You MAY:**
- Update rules files when AGENTS.md or DEVELOPMENT.md policy changes
- Add a new rules file if a new behavioral constraint category is needed

**You MUST NOT:**
- Edit one side of the mirror without editing the other
- Contradict AGENTS.md -- these files are subordinate to AGENTS.md (authority hierarchy level 4)

## Cross-References

- `.opencode/rules/` -- mirror of this directory
- `AGENTS.md` -- authoritative operating contract (these files are subordinate)
- `DEVELOPMENT.md` -- workflow rules that these files summarise
- `.claude/skills/` -- skills that enforce the rules defined here
