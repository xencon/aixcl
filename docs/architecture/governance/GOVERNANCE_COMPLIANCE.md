# Governance Compliance Confirmation

**This session is in compliance with the governance standards and workflow best practices as defined in `docs/`**

## Compliance Checklist

### Architectural Invariants
- [x] Runtime core (Ollama, OpenCode) is preserved and never disabled
- [x] No dependencies introduced from runtime core → operational services
- [x] Service boundaries are respected
- [x] CLI remains a control plane, not a decision engine

### Development Workflow
- [x] Issue-first development workflow followed
- [x] Branch naming: `issue-<number>/<description>`
- [x] Conventional commit format with issue references
- [x] PR format follows template with markdown checkboxes
- [x] Appropriate labels applied to issues

### Agentic Guidelines
- [x] Runtime core components treated as non-refactorable unless explicitly instructed
- [x] Declarative configuration preferred over imperative logic
- [x] Small, reversible steps taken
- [x] Uncertainties documented rather than guessed

## Key Governance Documents

All work in this session adheres to:

- **Invariants**: [`00_invariants.md`](00_invariants.md)
- **Agentic Guidance**: [`01_ai_guidance.md`](01_ai_guidance.md)
- **Profiles**: [`02_profiles.md`](02_profiles.md)
- **Development Workflow**: [`../../developer/development-workflow.md`](../../developer/development-workflow.md)
- **Service Contracts**: [`service_contracts/`](service_contracts/)

## Quick Reference

**Before starting work:**
1. Review [`../../developer/development-workflow.md`](../../developer/development-workflow.md)
2. Review [`00_invariants.md`](00_invariants.md)
3. Review relevant service contracts if making architectural changes

**When making changes:**
- Preserve runtime core invariants
- Follow issue-first workflow
- Use declarative configuration
- Maintain service boundaries

---

*Last verified: Session initialization*

