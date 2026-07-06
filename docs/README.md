# AIXCL Documentation

Documentation organized by audience. Keep it lean -- if something can be regenerated or is operator-only, it belongs in the [wiki](https://github.com/xencon/aixcl/wiki), not the repo.

This file is the complete index of `docs/`. Every file under `docs/` must be listed here -- update this index in the same PR that adds, moves, or removes a doc.

## User Guides (`user/`)

- [`usage.md`](user/usage.md) -- Commands and service URLs
- [`apps.md`](user/apps.md) -- App framework guide

## Developer Guides (`developer/`)

- [`development-workflow.md`](developer/development-workflow.md) -- Full issue-first workflow, step by step
- [`opencode-setup.md`](developer/opencode-setup.md) -- OpenCode CLI configuration for the local stack
- [`adding-services.md`](developer/adding-services.md) -- Add a service to the stack
- [`adding-apps.md`](developer/adding-apps.md) -- Add an app on the app framework
- [`app-builder-guide.md`](developer/app-builder-guide.md) -- Build apps against the platform contract
- [`agent-pitfalls.md`](developer/agent-pitfalls.md) -- Known agent failure modes and recovery steps
- [`ai-file-naming.md`](developer/ai-file-naming.md) -- File naming and metadata conventions
- [`env-configuration.md`](developer/env-configuration.md) -- Environment variable reference
- [`gpg-signed-commits.md`](developer/gpg-signed-commits.md) -- GPG signing setup and troubleshooting
- [`pre-commit-setup.md`](developer/pre-commit-setup.md) -- Pre-commit hook installation
- [`vault-integration.md`](developer/vault-integration.md) -- Vault secret management for services and apps

## Architecture (`architecture/`)

### Governance (`architecture/governance/`)

- [`00_invariants.md`](architecture/governance/00_invariants.md) -- Platform invariants (non-negotiable)
- [`01_ai_guidance.md`](architecture/governance/01_ai_guidance.md) -- Agentic behavioral guidance
- [`02_profiles.md`](architecture/governance/02_profiles.md) -- Stack profile definitions
- [`03_stack_status.md`](architecture/governance/03_stack_status.md) -- Stack status specification
- [`service_contracts/`](architecture/governance/service_contracts/) -- Service dependency contracts (runtime and bld profiles)

### Decision Records (`architecture/decisions/`)

- [`001-network-mode-host.md`](architecture/decisions/001-network-mode-host.md) -- Host networking for all services
- [`002-one-shot-bootstrap.md`](architecture/decisions/002-one-shot-bootstrap.md) -- One-shot bootstrap containers
- [`003-vault-token-escape-hatch.md`](architecture/decisions/003-vault-token-escape-hatch.md) -- VAULT_TOKEN escape hatch
- [`004-topological-sort-depends-on.md`](architecture/decisions/004-topological-sort-depends-on.md) -- Topological sort for depends_on
- [`005-python3-yaml-parser.md`](architecture/decisions/005-python3-yaml-parser.md) -- python3 as the YAML parser

## Security (`security/`)

- [`threat-model.md`](security/threat-model.md) -- Platform threat model
- [`compensating-controls.md`](security/compensating-controls.md) -- Compensating controls for accepted risks

## Operations (`operations/`)

- [`security-runbook.md`](operations/security-runbook.md) -- Security operations runbook
- [`incident-response.md`](operations/incident-response.md) -- Incident response procedures

## Reference (`reference/`)

- [`manpage.txt`](reference/manpage.txt) -- Generated CLI man page
- [`ai-report-structured-knowledge-architectures.md`](reference/ai-report-structured-knowledge-architectures.md) -- Research report on structured knowledge architectures

## Root-Level Contracts

These files are canonical and loaded by all agents:
- `AGENTS.md` -- Operating contract
- `DEVELOPMENT.md` -- Workflow rules
- `CONTRIBUTING.md` -- External contributor guide
- `SECURITY.md` -- Security policy

## Multi-Agent CLI Support

This repository supports both OpenCode and Claude Code agentic CLIs. Tool-specific configuration lives in `.opencode/` and `.claude/` respectively. Both tools share the same governance rules (Issue-First workflow, platform invariants) defined in `AGENTS.md` and `DEVELOPMENT.md`.
