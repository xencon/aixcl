# GPG-Signed Commits Guide

This document explains how to set up and use GPG-signed commits in the AIXCL project.

## Overview

All commits to the `main` and `dev` branches must be cryptographically signed using GPG. This ensures:

- **Proof of Authorship**: Cryptographic verification of who made changes
- **Code Integrity**: Tamper-evident commit history
- **Compliance**: Supports SOC 2 / ISO 27001 compliance objectives
- **Security**: Protection against compromised GitHub credentials

**Honest scoping of enforcement**: CI reports unsigned commits on pushes to `main` and `dev` via `.github/workflows/commit-signature-check.yml`, but the check is **non-blocking** -- enforcement is by maintainer discipline. Agents cannot complete GPG pinentry (no TTY) and must hand commits to the human operator rather than bypass signing; see `docs/developer/agent-pitfalls.md`.

### Scope: Human Developers Only

**This guide is for PERSONAL GPG keys** used by individual developers.

- **Key Type**: Personal identity keys (4096-bit RSA)
- **Storage**: `~/.gnupg/` on developer machines
- **Responsibility**: Each developer manages their own key lifecycle
- **Never Shared**: Keys are individual and non-transferable

### Agent Keys: Future Scope

**AI agents or CI/CD automation requiring GPG signing is NOT covered here.**

If agents need signing capability (Phase 3+):
- Agent keys require **separate management** from human keys
- Must be stored in secure secret vaults (HashiCorp Vault, etc.)
- Distinct identity: `aixcl-bot@company.com` vs `human@company.com`
- Audit trail for all automated signed commits
- **Do NOT** use human keys for automated processes

**For security questions about agent keys**: Stop and escalate to security team before proceeding.

## Quick Start

### Automated Setup

```bash
# Run the setup script
./scripts/utils/setup-gpg.sh

# Verify configuration
./scripts/utils/setup-gpg.sh --verify

# Export public key for GitHub
./scripts/utils/setup-gpg.sh --export
```

### Manual Setup

1. **Install GPG**
   ```bash
   # Fedora/RHEL
   sudo dnf install gnupg2

   # Ubuntu/Debian
   sudo apt-get install gnupg2

   # macOS
   brew install gnupg
   ```

2. **Generate a GPG Key**
   ```bash
   gpg --full-generate-key
   ```
   - Type: RSA and RSA
   - Key size: 4096 bits
   - Validity: 2 years (recommended)
   - Enter your name and email

3. **Configure Git**
   ```bash
   # Get your key ID
   gpg --list-secret-keys --keyid-format LONG

   # Configure Git to use the key
   git config --global user.signingkey YOUR_KEY_ID
   git config --global commit.gpgsign true
   ```

4. **Add Key to GitHub**
   ```bash
   # Export public key
   gpg --armor --export YOUR_KEY_ID

   # Add to GitHub: Settings > SSH and GPG keys > New GPG key
   ```

## Commit Workflow

### Making Signed Commits

Once configured, commits are automatically signed:

```bash
# Standard commit (automatically signed)
git commit -m "feat: add new feature"

# Explicit signed commit
git commit -S -m "feat: add new feature"
```

### Verifying Signatures

```bash
# Verify a commit
git verify-commit HEAD

# Show signature in log
git log --show-signature

# Check all commits in branch
git log --pretty=format:"%h %G? %s" --abbrev-commit
```

## GitHub Integration

### Verified Commits

Signed commits display a "Verified" badge on GitHub:

- **Green "Verified"**: Signature valid and trusted
- **Unverified**: Signature present but key not added to GitHub
- **No badge**: Commit not signed (reported as a non-blocking CI warning on `main`/`dev`)

### Enforcement Status

There is currently NO hard rejection of unsigned commits. The
`commit-signature-check.yml` workflow reports unsigned commits in a push
to `main` or `dev` as warnings and always exits 0. Adding blocking
enforcement (branch protection "require signed commits") is a maintainer
decision, not a documented current state.

## Emergency Procedures

### Lost GPG Key

If you lose your GPG private key:

1. **Revoke the old key immediately**
   ```bash
   gpg --gen-revoke KEY_ID
   gpg --send-keys KEY_ID  # Send to keyservers
   ```

2. **Generate a new key**
   ```bash
   ./scripts/utils/setup-gpg.sh
   ```

3. **Update GitHub**
   - Remove old key from GitHub settings
   - Add new public key

4. **Update local Git config**
   ```bash
   git config --global user.signingkey NEW_KEY_ID
   ```

### Temporary Bypass

In emergencies, repository admins can:

1. Temporarily disable branch protection (Settings > Branches)
2. Merge unsigned commit
3. Re-enable protection immediately

**Note**: This requires explicit admin approval and should be logged.

## Agents and Automation

There is **no bot GPG key** in this repository, and CI does not create
signed commits. AI agents running without a TTY cannot complete GPG
pinentry: the correct behavior is to stage the changes, provide the exact
`git commit` command, and hand signing to the human operator -- never
disable signing, never use `--no-gpg-sign`, never use `--no-verify`.

If automated signing is ever introduced (bot key in CI), it requires a
separate key with a distinct bot identity, storage in a secret vault, and
an audit trail -- treat it as a `[SECURITY]`-flagged change requiring
explicit maintainer approval.

## Troubleshooting

### "gpg failed to sign the data"

```bash
# Set TTY for GPG
export GPG_TTY=$(tty)

# Or add to .bashrc/.zshrc
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
```

### "No secret key"

```bash
# List available keys
gpg --list-secret-keys --keyid-format LONG

# Ensure key is in keyring
gpg --import /path/to/private-key.asc
```

### "Bad signature" on GitHub

1. Verify key is added to GitHub
2. Check email matches commit author
3. Ensure key hasn't expired

```bash
# Check key details
gpg --list-keys --keyid-format LONG

# Update expiration
gpg --edit-key KEY_ID
# > expire
# > save
```

## Best Practices

1. **Key Backup**
   - Export private key: `gpg --export-secret-keys KEY_ID > backup.gpg`
   - Store securely (encrypted password manager)
   - Never commit keys to repository

2. **Key Rotation**
   - Set expiration to 1-2 years
   - Generate new key before expiration
   - Update GitHub and Git config

3. **Email Consistency**
   - Ensure GPG key email matches Git config email
   - Use same email for GitHub commits

4. **Passphrase Protection**
   - Always set passphrase on GPG keys
   - Use strong, unique passphrase
   - Store in password manager

## References

- [GitHub: Managing commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification)
- [Git: Signing commits with GPG](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work)
- [GPG: Mini howto](https://www.gnupg.org/documentation/howtos.html)

## Support

If you have issues with GPG setup:

1. Run `./scripts/utils/setup-gpg.sh --verify`
2. Check [GitHub documentation](https://docs.github.com/en/authentication/managing-commit-signature-verification)
3. Open an issue labeled "question"

---

**Note**: GPG-signed commits are mandatory for `main` and `dev` branches as of Phase 2 security hardening.
