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

### 2. Set Up Development Environment

Follow the [README.md](README.md) Quick Start guide to install prerequisites (Podman, Git).

**Note:** GPG signing is **not required** for contributors submitting via Pull Request. GPG-signed commits are only required for:
- Direct pushes to `main` or `dev` branches (maintainers only)
- Merges performed by CODEOWNERS

### 3. Create a Branch

```bash
# Ensure you're on dev branch
git checkout dev

# Pull latest changes
git pull origin dev

# Create feature branch
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

### 6. Create Pull Request

1. Go to https://github.com/xencon/aixcl
2. Click "New Pull Request"
3. Select your fork and branch
4. Target: `xencon/aixcl:dev`
5. Fill in the PR template
6. Submit for review

## Workflow for Maintainers

If you are a CODEOWNER (@sbadakhc):

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
