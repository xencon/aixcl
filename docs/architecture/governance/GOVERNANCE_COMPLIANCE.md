# Governance Compliance Confirmation

**This session is in compliance with the governance standards and workflow best practices as defined in `docs/`**

## Compliance Checklist

### Architectural Invariants
- [x] Runtime core (Ollama, LLM-Council, Continue) is preserved and never disabled
- [x] No dependencies introduced from runtime core → operational services
- [x] Service boundaries are respected
- [x] CLI remains a control plane, not a decision engine

### Development Workflow
- [x] Issue-first development workflow followed
- [x] Branch naming: `issue-<number>/<description>`
- [x] Conventional commit format with issue references
- [x] PR format follows template with markdown checkboxes
- [x] Appropriate labels applied to issues

### AI Assistant Guidelines
- [x] Runtime core components treated as non-refactorable unless explicitly instructed
- [x] Declarative configuration preferred over imperative logic
- [x] Small, reversible steps taken
- [x] Uncertainties documented rather than guessed

## Key Governance Documents

All work in this session adheres to:

- **Invariants**: [`docs/architecture/governance/00_invariants.md`](../architecture/governance/00_invariants.md)
- **AI Guidance**: [`docs/architecture/governance/01_ai_guidance.md`](../architecture/governance/01_ai_guidance.md)
- **Profiles**: [`docs/architecture/governance/02_profiles.md`](../architecture/governance/02_profiles.md)
- **Development Workflow**: [`docs/developer/development-workflow.md`](../developer/development-workflow.md)
- **Service Contracts**: [`docs/architecture/governance/service_contracts/`](../architecture/governance/service_contracts/)

## Quick Reference

**Before starting work:**
1. Review [`docs/developer/development-workflow.md`](../developer/development-workflow.md)
2. Review [`docs/architecture/governance/00_invariants.md`](../architecture/governance/00_invariants.md)
3. Review relevant service contracts if making architectural changes

**When making changes:**
- Preserve runtime core invariants
- Follow issue-first workflow
- Use declarative configuration
- Maintain service boundaries

---

*Last verified: Session initialization*

