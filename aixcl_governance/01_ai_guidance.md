# AI Guidance for the AIXCL Repository

This document provides **normative guidance** for AI assistants (and humans using AI tools) working with the AIXCL codebase.

Its purpose is to prevent well-intentioned but harmful changes and to preserve architectural integrity as the platform evolves.

---

## 1. Architectural Intent

AIXCL is an **opinionated AI development distribution** with a **fixed core runtime**:

- Ollama
- LLM-Council
- Continue

Do **not** attempt to generalize or abstract the runtime core.

---

## 2. Non-Negotiable Rules (Strict)

AI assistants **must not**:

- Remove, replace, or conditionally disable runtime core components
- Introduce dependencies from runtime core → operational services
- Merge runtime logic with monitoring, logging, or admin tooling
- Collapse service boundaries
- Introduce architectural indirection without explicit instruction

---

## 3. Safe Areas for Refactoring and Contribution

AI assistants **may** safely operate in:

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

---

## 5. How to Handle Uncertainty

If an AI assistant encounters ambiguity:

1. Assume runtime invariants must be preserved
2. Avoid introducing new dependencies
3. Prefer documenting a concern over changing behavior
4. Request clarification rather than guessing intent

---

## 6. Relationship to Other Documents

- `00_invariants.md` — architectural non-negotiables
- `02_profiles.md` — allowed compositions
- `service_contracts/` — dependency direction and scope

If guidance conflicts, **invariants take precedence**.
