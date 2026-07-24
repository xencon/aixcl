# Agentic Guidance for the AIXCL Repository

This document provides **normative guidance** for agents (and humans using agentic tools) working with the AIXCL codebase.

Its purpose is to prevent well-intentioned but harmful changes and to preserve architectural integrity as the platform evolves.

---

## 1. Architectural Intent

AIXCL is an **opinionated AI development distribution** with a **fixed core runtime**:

- Ollama (Inference Engine)

AI coding clients (OpenCode, Claude Code, or any OpenAI-API-compatible tool) sit above the API layer and are not part of the runtime core -- the platform is client-agnostic (see `00_invariants.md`).

Do **not** attempt to generalize or abstract the runtime core.

---

## 2. Non-Negotiable Rules (Strict)

Agents **must not**:

- Remove, replace, or conditionally disable runtime core components
- Introduce dependencies from runtime core -> operational services
- Merge runtime logic with monitoring, logging, or admin tooling
- Collapse service boundaries
- Introduce architectural indirection without explicit instruction

---

## 3. Safe Areas for Refactoring and Contribution

Agents **may** safely operate in:

- Operational services (monitoring, logging, automation)
- Documentation improvements
- CLI ergonomics (without changing semantics)
- Compose organization (if invariants are preserved)
- Adding new operational profiles or tooling

---

## 4. Preferred Change Style

- Declarative configuration over imperative logic
- Explicit over implicit behavior
- Small, reversible steps
- Clear grouping by responsibility
- Minimal assumptions about upstream internals
- When a design decision (an ADR or otherwise) supersedes an existing
  implementation, remove the superseded code, config, and mounts in the
  same change -- do not leave a dead implementation behind for a later
  cleanup that may never happen. A dead implementation is not neutral: it
  can still carry real credentials, mislead a future reader into thinking
  it is the pattern to follow, and go unnoticed by mechanical checks,
  since "is this file ever actually executed" is a behavioral question,
  not a lint-able one. Update or remove any documentation
  (`CONTEXT.md`, ADRs, cross-references) that pointed at the removed
  files in the same change.

---

## 5. How to Handle Uncertainty

If an agent encounters ambiguity:

1. Assume runtime invariants must be preserved
2. Avoid introducing new dependencies
3. Prefer documenting a concern over changing behavior
4. Request clarification rather than guessing intent

---

## 6. Relationship to Other Documents

- `00_invariants.md` -- architectural non-negotiables
- `02_profiles.md` -- allowed compositions
- `service_contracts/` -- dependency direction and scope

If guidance conflicts, **invariants take precedence**.
