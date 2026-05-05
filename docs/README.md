# AIXCL Documentation

Documentation organized by audience. Keep it lean -- if something can be regenerated or is operator-only, it belongs in the [wiki](https://github.com/xencon/aixcl/wiki), not the repo.

## Structure

| Directory | Audience | Key Files |
|-----------|----------|-----------|
| `user/` | End users | [`usage.md`](user/usage.md) - Setup, commands, troubleshooting |
| `developer/` | Contributors | [`development-workflow.md`](developer/development-workflow.md), [`opencode-setup.md`](developer/opencode-setup.md), [`adding-services.md`](developer/adding-services.md) |
| `architecture/governance/` | Architects | [`00_invariants.md`](architecture/governance/00_invariants.md), [`02_profiles.md`](architecture/governance/02_profiles.md), [`service_contracts/`](architecture/governance/service_contracts/) |
| `operations/` | Operators | [`security.md`](operations/security.md), [`model-recommendations.md`](operations/model-recommendations.md) |
| `reference/` | All | [`manpage.txt`](reference/manpage.txt) |

## Root-Level Contracts

These files are canonical and loaded by all agents:
- `AGENTS.md` — Operating contract
- `DEVELOPMENT.md` — Workflow rules
- `CONTRIBUTING.md` — External contributor guide
- `SECURITY.md` — Security policy

