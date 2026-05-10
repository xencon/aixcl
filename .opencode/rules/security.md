# Security and Architecture Policy

## Fixed Core Runtime (Non-Negotiable)
- **Inference Engine** (Ollama) -- Docker-managed, always enabled
- **OpenCode** -- AI-powered code assistance (VS Code plugin, client-side), always enabled
- Never remove, replace, or conditionally disable runtime core components

## Runtime vs Operational Services Boundary
- Runtime core must be runnable **without** any operational services
- Operational services may depend on runtime core
- Runtime core must **never** depend on operational services

## Safe Areas for AI Contribution
**You MAY:**
- Modify operational services (monitoring, logging, automation)
- Improve documentation
- Adjust CLI ergonomics (without changing semantics)
- Organize Compose files (if invariants are preserved)
- Add new operational profiles or tooling

**You MUST NOT:**
- Remove/replace/disable runtime core components
- Introduce runtime core → operational service dependencies
- Merge runtime logic with monitoring/admin tooling
- Collapse service boundaries
- Add external libraries, cloud services, telemetry, or analytics without explicit approval

## Escalation
1. If working on an issue → Post clarification as issue comment
2. If no issue exists → Ask human operator directly; do not create issue unilaterally
3. If security concern → Flag with `[SECURITY]` prefix and await explicit approval
4. If authority conflict → Document override request and obtain explicit confirmation
