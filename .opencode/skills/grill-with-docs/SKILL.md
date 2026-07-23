---
name: grill-with-docs
description: >
  Stress-test a plan or approach against the codebase before implementing.
  Challenges assumptions, checks for existing patterns, and sharpens decisions
  one question at a time. Use when a draft approach exists and needs
  validation before coding or before presenting to the operator. Triggers on
  "grill this", "stress test the plan", "challenge this approach", "validate
  the design".
argument-hint: <description of the plan or approach to challenge>
compatibility: OpenCode, Claude Code
metadata:
  category: workflow
  version: "1.0"
---

# Grill with Docs

Interview relentlessly about every aspect of the plan until shared
understanding is reached. Walk down each branch of the design tree, resolving
dependencies between decisions one by one. For each question, provide a
recommended answer.

Ask questions one at a time, waiting for feedback before continuing.

If a question can be answered by exploring the codebase, explore the codebase
instead of asking.

## During the session

### Challenge against existing patterns

When the plan proposes building something, check whether the repo already has
it. Search `lib/` for existing functions, `scripts/checks/` for existing
validations, `scripts/utils/` for existing wrappers. "The plan writes a new
issue-creation helper, but scripts/utils/create-issue.sh already validates
references and labels. Why not use it?"

### Check against rules and invariants

When the plan makes a structural choice, verify it against AGENTS.md and
`docs/architecture/governance/00_invariants.md`. "The plan adds a runtime
dependency on Grafana, but runtime core must never depend on operational
services. How does the service behave when Grafana is absent?"

### Discuss concrete scenarios

Stress-test with specific edge cases. "What happens on a truly fresh install
with no volumes? On restart with a populated volume from the previous
version? When the stack is down and the command runs anyway? Under
`cap_drop: ALL`?"

### Cross-reference with code

When the plan states how something works, check whether the code agrees.
"The plan assumes the entrypoint runs as root, but the compose file sets
`user:` -- which is it?"

### Surface infrastructure constraints

Check CI workflows, profile registration, mirror parity, and permissions.
"The plan adds a skill file -- where is the byte-identical .opencode mirror?
Which profile registers the new service?"

### Flag when to stop

When the grilling reveals the plan needs an operator decision (invariant
exception, new dependency approval, scope change), say so and stop. Do not
continue designing around unknowns that are not yours to resolve.
