# Contributing to AIXCL

Thank you for your interest in contributing to AIXCL! This document outlines the workflow for external contributors.

## Quick Start for Contributors

### 1. Fork the Repository

1. Visit https://github.com/xencon/aixcl
2. Click the "Fork" button in the top right
3. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/aixcl.git
   cd aixcl
   ```

### 2. Sync Your Fork with Upstream

Before creating any branch, ensure your fork is synchronized with the upstream repository. This prevents merge conflicts and ensures you are building on the latest code.

```bash
# Add upstream remote (one-time)
git remote add upstream https://github.com/xencon/aixcl.git

# Fetch upstream state
git fetch upstream

# Sync main
git checkout main
git reset --hard upstream/main
git push origin main --force-with-lease

# Sync dev
git checkout -B dev upstream/dev
git push -u origin dev
```

**Important:** Never commit directly to `main` or `dev` on your fork. Always create feature branches from `dev`.

### 3. Create a Branch

```bash
# Ensure you're on the latest dev
git checkout dev
git pull upstream dev

# Create feature branch from upstream dev
git checkout -b issue-XXX/short-description
```

### 4. Make Changes

- Follow existing code style
- Update documentation if needed
- Test your changes locally

### 5. Commit Changes

```bash
# Standard commit (no GPG required for forks)
git add .
git commit -m "type: description

- Change details

Fixes #XXX"

# Push to your fork
git push -u origin issue-XXX/short-description
```

### 6. Keep Your Branch Updated

If upstream `dev` moves while your PR is open, rebase your branch to keep it conflict-free:

```bash
# Fetch latest upstream dev
git fetch upstream

# Rebase your feature branch
git checkout issue-XXX/short-description
git rebase upstream/dev

# Force-push to update PR (safe on feature branches)
git push origin issue-XXX/short-description --force-with-lease
```

### 7. Create Pull Request

```bash
# Create PR targeting upstream dev branch
gh pr create --repo xencon/aixcl \
  --base dev \
  --head YOUR-USERNAME:issue-XXX/short-description \
  --title "description (#XXX)" \
  --body "Fixes #XXX"
```

**Required:** All PRs must target `xencon/aixcl:dev`. Never open a feature PR directly to `main`.

## Workflow for Maintainers

If you are a CODEOWNER (@sbadakhc):

### Consuming Upstream Changes

After a PR is merged to `xencon/dev`, pull those changes back into your fork:

```bash
# Fetch and merge upstream dev
git fetch upstream
git checkout dev
git merge upstream/dev
git push origin dev

# Update main when upstream main advances
git checkout main
git reset --hard upstream/main
git push origin main --force-with-lease
```

### GPG Signing (Required)

All commits to `main` and `dev` must be GPG-signed:

```bash
# Configure Git (one-time)
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_KEY_ID

# All commits automatically signed
git commit -m "feat: add new feature"

# Verify signature
git log --show-signature -1
```

### Review Process

1. All PRs must be reviewed by CODEOWNER
2. CI checks must pass
3. Merge with GPG-signed merge commit

## Issue-First Development

**Always create an issue before starting work:**

1. Check existing issues: https://github.com/xencon/aixcl/issues
2. Create new issue with appropriate template
3. Wait for assignment/approval
4. Create branch referencing issue number

## Code Style

- Shell scripts: POSIX-compliant where possible
- Documentation: Clear, concise, accurate
- Commits: Conventional commit format (`type: description`)

## Security

- Never commit secrets or credentials
- Use Vault for sensitive data
- Follow security guidelines in [SECURITY.md](SECURITY.md)

## Questions?

- Open an issue: https://github.com/xencon/aixcl/issues
- Check [docs/](docs/) for detailed guides

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
