# ADR 003 -- VAULT_TOKEN Environment Variable Escape Hatch

| Field | Value |
|-------|-------|
| Status | Accepted |
| Decided | 2026-06 (issue #1339) |
| Authority | lib/aixcl/commands/stack.sh |

## Context

The AIXCL stack loads the Vault root token from a GPG-encrypted file at
`.security/vault-root-token.gpg`. GPG decryption requires a TTY for pinentry.

In CI environments, agent sessions, and non-interactive scripts, no TTY is
available. Without an escape hatch, the token cannot be loaded and all
Vault-dependent stack commands fail.

## Decision

CLI commands that need the Vault token check `VAULT_TOKEN` in the environment
BEFORE attempting GPG decryption. If `VAULT_TOKEN` is set and non-empty, GPG
is skipped entirely.

```bash
if [ -n "${VAULT_TOKEN:-}" ]; then
    export VAULT_TOKEN
    return 0
fi
# ... GPG decrypt path ...
```

## Rationale

- **CI compatibility**: CI workflows can inject `VAULT_TOKEN` as a secret
  without requiring GPG or a TTY.
- **Agent compatibility**: AI agents operating in non-TTY contexts can set
  `VAULT_TOKEN` before invoking CLI commands.
- **Security**: The escape hatch does not weaken the GPG-encrypted storage on
  developer workstations. GPG remains the default for interactive sessions.
  The token value itself is equally sensitive in both paths.

## Usage Patterns

**Interactive developer session** (TTY available):
```bash
# GPG decrypt happens automatically -- no action needed
./aixcl stack start --profile sys
```

**CI / agent / non-interactive session** (no TTY):
```bash
export VAULT_TOKEN=$(gpg --pinentry-mode loopback --decrypt .security/vault-root-token.gpg)
./aixcl stack start --profile sys
```

**Or inject directly in CI**:
```bash
# In GitHub Actions, store as a secret and inject:
export VAULT_TOKEN=${{ secrets.VAULT_TOKEN }}
```

## TTY Detection

The code uses POSIX `[ ! -t 0 ]` to detect non-interactive stdin.
Do NOT use the `tty` command for this -- it prints "not a tty" to stdout in
non-interactive contexts, which corrupts variable assignment.

## What This Means for Agents

- If Vault commands fail with "could not decrypt" errors, set `VAULT_TOKEN` in
  the environment. This is the intended path for agent sessions.
- The escape hatch is present in `stack.sh`, `vault-status.sh`, and `vault-commands.sh`.
- Do NOT remove the `VAULT_TOKEN` check -- CI and agents depend on it.
