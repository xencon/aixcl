# Two-Tier Documentation Strategy

## Core Principle
The repository employs a **Two-Tier Strategy** for Artificial Intelligence agents and documentation, distinctly separating generic behavioral guidance from repository-specific domain knowledge.

## Why Two Tiers?
Merging all AI instructions into a single place (e.g., placing workflow constraints inside the repository's `docs/` folder) hampers the portability of AI agents. To ensure generic agents can be "dropped into" any given repository instantly without cross-contamination of complex architectural patterns, we enforce strict separation.

## Tier 1: The `ai/` Folder (The "Employee Handbook")
**Location:** `/ai/` (and its subdirectories like `governance`, `skills`, etc.)
**Scope:** Generic, cross-repository operational behavior.

This directory serves as the runtime operational handbook. It tells any agent **how** to behave regardless of what the code actually does.
- Directs agents to prioritize security.
- Contains instructions on the development workflow (e.g., Issue-First Development).
- Provides standardized templates for PRs and generic CLI usage.
- **Rule:** This folder must not reference repository-specific technical debt, invariant constraints, or unique configurations.

## Tier 2: The `docs/` Folder (The "Engineering Manual")
**Location:** `/docs/` (specifically `docs/architecture/governance/` or similar)
**Scope:** Repository-specific domain knowledge and architectural rules.

This directory instructs agents and developers on **what** the repository is and what immutable constraints exist.
- Defines core invariants.
- Specifies architectural boundaries (e.g., do not merge runtime logic into monitoring tooling).
- Lists what is safe and unsafe to refactor.

## The Bridge: `AGENTS.md`
To make the execution flow seamless, the `AGENTS.md` file in the root acts as the initial entry point. 
1. **Agent Start:** The agent reads `AGENTS.md`.
2. **Behavior Routing:** `AGENTS.md` directs the agent to load the generic workflow constraints found in `ai/governance`.
3. **Context Routing:** `AGENTS.md` (or the agent's specific role) directs the agent to ingest repository-bound constraints from `/docs` before beginning modifications.
