# Security and Architecture Policy

**Canonical text: AGENTS.md** -- Section 3 (Platform Invariants), Section 4
(Safe Areas), Section 7 (Escalation Procedures). This file is a summary for
the rules set; it adds no policy of its own. If this summary and AGENTS.md
ever disagree, AGENTS.md wins.

## Hard Invariants (summary)

- **Inference Engine** (Ollama) is fixed core runtime -- never remove,
  replace, or conditionally disable it
- Runtime core must never depend on operational services; operational
  services may depend on runtime core
- AIXCL is client-agnostic above the OpenAI-compatible API layer -- no
  specific AI coding client is a platform invariant
- No external libraries, cloud services, telemetry, or analytics without
  explicit approval

## Escalation (summary)

- Security concern -> flag with `[SECURITY]` prefix and await explicit
  approval
- No issue exists -> ask the human operator directly; do not create issues
  unilaterally
