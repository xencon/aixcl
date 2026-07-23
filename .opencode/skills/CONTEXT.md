# CONTEXT: skills/

Agent skills following the [Agent Skills open standard](https://agentskills.io).
This directory and its counterpart (`.claude/skills/` <-> `.opencode/skills/`)
are byte-identical mirrors, enforced by `check-agents.sh` and CI
(`check-opencode.yml`). **Edit both sides together, always.**

## Catalog

| Skill | Category | Purpose |
|-------|----------|---------|
| `add-service` | platform | Checklist for adding an operational service without breaking invariants |
| `check-updates` | maintenance | Audit versioned components; manage updates issue-first |
| `delegate` | workflow | Route mechanistic sub-tasks to the OpenCode peer (sequential, logged) |
| `delegate-review` | workflow | Analytics over the delegation log |
| `grill-with-docs` | workflow | Stress-test a plan against the codebase before implementing |
| `housekeeping` | maintenance | Repo health + session-startup sweep, status report with priorities |
| `investigate` | workflow | Root-cause-first bug investigation; no fixing until complete |
| `issue-triage` | workflow | End-to-end GitHub issue workflow with design and CI-parity gates |
| `release` | workflow | Cut a release (operator-gated via disable-model-invocation) |
| `reviewing-skills` | maintenance | Audit SKILL.md files against authoring best practices |
| `session-review` | workflow | End-of-session delegation feedback loop |
| `workflow-guard` | workflow | Validate issue-first compliance before execution |

How they interlock: `housekeeping` orients the session and may hand
mechanical checks to `delegate`; `issue-triage` drives an issue end to end,
calling `grill-with-docs` to validate the design and `investigate` for bugs;
`session-review` closes the delegation loop that `delegate` logs;
`reviewing-skills` lints all of the above.

## Agent Guidance

**You MAY:**
- Add a new skill (directory + SKILL.md, kebab-case name matching frontmatter)
- Update skills when policy or tooling changes (bump `metadata.version`)

**You MUST NOT:**
- Edit one side of the mirror without the other (`./aixcl checks agents`)
- Merge a skill change without running the `reviewing-skills` audit on it
- Use non-ASCII characters or reference tools the repository does not have

## Conventions

- Frontmatter: `name`, `description` (with trigger phrases), optional
  `argument-hint`, `compatibility`, `metadata.category`/`metadata.version`
- SKILL.md stays under 500 lines / 5KB; bulky material goes to
  `references/` (one level deep, table of contents if over 100 lines)
- Update this catalog in the same PR that adds, renames, or removes a skill
