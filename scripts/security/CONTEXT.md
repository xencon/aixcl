# CONTEXT: scripts/security/

Security initialisation, credential rotation, and emergency procedures.
Scripts here may modify `.security/`, host networking, or running service state.

## Contents

| File | Purpose | Authorization required |
|------|---------|----------------------|
| `init-secrets.sh` | Generates initial secrets (GPG-encrypted vault tokens, postgres passwords). Run once at platform setup. | Explicit human instruction |
| `init-postgres-ssl.sh` | Generates self-signed TLS certificates for postgres. Run once. | Explicit human instruction |
| `rotate-credentials.sh` | Rotates all service credentials via Vault. | Explicit human instruction |
| `emergency-lockdown.sh` | Stops all services and revokes Vault tokens. Emergency use only. | Explicit human instruction |
| `host-firewall.sh` | Configures host firewall rules for the platform. | Explicit human instruction |
| `start-with-secrets.sh` | Starts the stack with Docker secrets injection (alternative to Vault). | Explicit human instruction |
| `start-with-ssl.sh` | Starts the stack with SSL-enabled postgres. | Explicit human instruction |
| `validate-token.sh` | Validates a Vault token against the running Vault instance. | Safe to run read-only. |

## Agent Guidance

**STOP.** Do not run any script in this directory autonomously.

Every script here except `validate-token.sh` modifies security-sensitive state:
encrypted files in `.security/`, host firewall rules, or running service credentials.

**You MUST:**
- Obtain explicit human instruction before running any script here
- Prefix any security concern with `[SECURITY]` and await approval
- Read `docs/security/threat-model.md` and `docs/operations/security-runbook.md`
  before proposing changes in this directory

## Cross-References

- `.security/` -- encrypted secrets modified by init-secrets.sh
- `docs/security/threat-model.md` -- platform threat model
- `docs/security/compensating-controls.md` -- documented accepted risks
- `docs/operations/security-runbook.md` -- operational security procedures
- `AGENTS.md` Section 7 -- escalation procedures for security concerns
