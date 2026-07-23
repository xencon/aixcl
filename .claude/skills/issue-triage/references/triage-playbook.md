# Triage playbook -- repo map, research method, design validation

## Contents

- Repo map
- Command cheat sheet
- Research method (code and history first)
- Design validation rationale

## Repo map

| Path | What it is | Watch for |
|------|-----------|-----------|
| `aixcl` | Single CLI entry point | Never bypass it for stack ops |
| `lib/` | Shell library (CLI logic) | `./aixcl test lib` covers it; shellcheck on every change |
| `scripts/checks/` | CI-parity check scripts | Same scripts run locally and in CI |
| `scripts/utils/` | Workflow wrappers (create-issue, create-pr) | They validate reference style before creation -- use them |
| `scripts/runtime/` | Service entrypoint scripts | `set -euo pipefail`; mounted read-only in compose |
| `services/docker-compose.yml` | All service definitions | `network_mode: host` invariant; pinned image tags |
| `config/profiles/` | Which services each profile starts | bld is a subset of sys; register new services or they will not start |
| `docs/architecture/governance/` | Invariants, AI guidance, profiles, service contracts | Read 00_invariants.md before touching anything structural |
| `.claude/` and `.opencode/` | Agent rules, skills, commands | Byte-identical mirrors for rules and skills; `./aixcl checks agents` |
| `tests/` | Test suites | `./aixcl test all` |

## Command cheat sheet

| Purpose | Command |
|---------|---------|
| Full local CI parity | `./aixcl checks all` |
| One check | `./aixcl checks <paths\|agents\|ascii\|pins\|...>` |
| Shell library tests | `./aixcl test lib` |
| Stack health (read-only) | `./aixcl stack status` |
| Service logs | `./aixcl stack logs <service>` |
| Merge gate | `./aixcl checks pr-ready <PR>` |
| Safe issue creation | `./scripts/utils/create-issue.sh "[TYPE] Title" <type> <labels> <assignee> <body-file>` |
| PR body reference lint | `bash scripts/checks/check-pr-references.sh < body.md` |

Merge workflow: push branches to `origin` (fork), open PRs against
`upstream` (xencon/aixcl) base `dev`. Never push to upstream branches
directly. GPG commits are operator-signed -- stage, hand over the command.

## Research method

The source code has the answer, and git history stores the knowledge.
Documentation can be stale; the code is current.

```bash
git log --oneline -- <path>                               # why code is the way it is
git log --all --oneline --grep="<keyword>"                # when a pattern was introduced
git blame <file>                                          # who decided what, in which commit
gh pr list --repo xencon/aixcl --state merged --search "<keyword>" --limit 5
```

Before introducing anything new:

- Read the target directory's `CONTEXT.md` end to end -- it is the agent
  contract for that directory
- Study 2-3 prior merged PRs that touched the same area: how they wired,
  tested, and verified the change, and what review feedback they got
- Produce the rules compliance checklist (issue-triage Step 3) before the
  first edit, not after

## Design validation rationale

Full PRs have been reversed because the operator had different constraints
than the draft assumed. A short design conversation before coding is cheaper
than a redone PR.

Validate the approach (grill-with-docs) when:

- Multiple approaches exist with different tradeoffs
- The change touches invariants, service boundaries, or new dependencies
  (external libraries and services need explicit approval -- AGENTS.md)
- The issue description is sparse or ambiguous

Afterwards, capture the decisions in the issue body. The body is the source
of truth; comments are the history trail.
