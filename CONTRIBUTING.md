# Contributing to AIXCL

Thanks for your interest in making AIXCL better! We love contributions from everyone, regardless of your experience level.

## Development Workflow

**IMPORTANT: We follow an Issue-First Development workflow.**

Before making any changes:
1. **Create an issue** describing the problem or feature
2. **Create a branch** to address the issue
3. **Make changes** and commit with clear messages
4. **Create a Pull Request** that references the issue

See [`DEVELOPMENT_WORKFLOW.md`](./DEVELOPMENT_WORKFLOW.md) for complete workflow documentation, including:
- Step-by-step instructions
- Formatting guidelines (use plain text, avoid Unicode)
- AI assistant instructions
- Quick reference commands

## Quick Start

1. **Fork & Clone**
   ```bash
   git clone https://github.com/YOUR-USERNAME/aixcl.git
   cd aixcl
   ```

2. **Create an Issue**
   - Describe the problem or feature you want to work on
   - Use `gh issue create` or GitHub web interface

3. **Make Your Changes**
   - Create a branch: `git checkout -b issue-<number>/<description>`
   - Make your awesome changes
   - Test thoroughly
   - Commit with messages that reference the issue

4. **Submit Your Contribution**
   - Push to your fork: `git push origin issue-<number>/<description>`
   - Create a pull request that references the issue: `gh pr create`
   - Use plain text formatting (markdown checkboxes `- [x]`, not Unicode)

## Tips for a Great Contribution

- **Keep it focused**: One feature or fix per pull request
- **Test your changes**: Make sure everything works as expected
- **Update docs**: If you change functionality, update the documentation
- **Be clear**: Write clear commit messages and PR descriptions
- **Follow the style**: Match the existing code style
- **Respect the architecture**: Review [`aixcl_governance/`](./aixcl_governance/) before making architectural changes

## Architectural Guidelines

AIXCL maintains strict architectural invariants to preserve platform integrity:

- **Runtime Core** (ollama, llm-council, continue) is non-negotiable and must not be removed or conditionally disabled
- **Operational Services** can be added, modified, or removed based on profiles
- **Service Boundaries**: Runtime core must never depend on operational services
- **Service Contracts**: See [`aixcl_governance/service_contracts/`](./aixcl_governance/service_contracts/) for dependency rules

Before making changes that affect service architecture, dependencies, or the runtime core, please:
1. Review [`aixcl_governance/00_invariants.md`](./aixcl_governance/00_invariants.md)
2. Review [`aixcl_governance/01_ai_guidance.md`](./aixcl_governance/01_ai_guidance.md)
3. Check relevant service contracts in [`aixcl_governance/service_contracts/`](./aixcl_governance/service_contracts/)

Breaking architectural invariants requires explicit maintainer approval.

## Need Help?

- **Questions?** Open an issue labeled "question"
- **Found a bug?** Open an issue with steps to reproduce
- **Feature idea?** Open an issue describing your idea

We aim to respond to all issues and PRs within a few days.

## Code of Conduct

Be kind, respectful, and constructive in all interactions. We're building something cool together!

Thank you for helping make AIXCL better! 🚀