# AIXCL Documentation

This directory contains all project-wide documentation organized by audience and purpose.

## Documentation Structure

### User Documentation (`user/`)
Documentation for end users and operators:
- [`setup.md`](user/setup.md) - Installation and setup guide
- [`usage.md`](user/usage.md) - Usage guide and examples

### Developer Documentation (`developer/`)
Documentation for contributors and developers:
- [`contributing.md`](developer/contributing.md) - Contribution guidelines
- [`development-workflow.md`](developer/development-workflow.md) - Development workflow and best practices

### Operations Documentation (`operations/`)
Documentation for operations and performance tuning:
- [`ollama-performance-tuning.md`](operations/ollama-performance-tuning.md) - Detailed Ollama performance tuning guide
- [`ollama-tuning-summary.md`](operations/ollama-tuning-summary.md) - Executive summary of Ollama optimizations

### Architecture Documentation (`architecture/`)
Documentation about system architecture and design:
- [`governance/`](architecture/governance/) - Governance model, invariants, profiles, and service contracts
- [`build/`](architecture/build/) - Build and deployment architecture documentation

### Reference Documentation (`reference/`)
Reference materials and specifications:
- [`manpage.txt`](reference/manpage.txt) - Command-line reference
- [`security.md`](reference/security.md) - Security policy and practices

## Component-Specific Documentation

Component-specific documentation remains with their respective components:
- **LLM-Council**: `llm-council/README.md`, `llm-council/TESTING.md`, etc.
- **Tests**: `tests/README.md` and component-specific test docs
- **Scripts**: `scripts/*/README.md` files

## Root-Level Documentation

The following files remain at the project root (standard practice):
- `README.md` - Main project overview and quick start
- `CHANGELOG.md` - Project changelog

## Quick Links

- **Getting Started**: Start with [`user/setup.md`](user/setup.md)
- **Contributing**: See [`developer/contributing.md`](developer/contributing.md)
- **Architecture**: Explore [`architecture/governance/`](architecture/governance/)
- **Performance**: Check [`operations/ollama-performance-tuning.md`](operations/ollama-performance-tuning.md)

