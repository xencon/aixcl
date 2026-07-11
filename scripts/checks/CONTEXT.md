# CONTEXT: scripts/checks/

Validation and lint scripts. Run in CI (GitHub Actions) and locally before
committing. This directory is the pre-commit safety net.

## Contents

| File | Purpose | When to run |
|------|---------|------------|
| `check-ai-elisions.sh` | **CRITICAL.** Detects AI placeholder text and mass deletions in staged diffs. An AI-assisted edit once replaced a 639-line module with a stub -- this script catches that. | Before EVERY commit: `./scripts/checks/check-ai-elisions.sh --staged` |
| `check-agents.sh` | Validates agent and skill file structure (frontmatter, required fields). | After editing `.claude/skills/` or `.opencode/skills/`. |
| `check-environment.sh` | Full host prerequisite check (container runtime, Python3-yaml, jq, curl, GPG). | Before first stack start; on new dev machine setup. |
| `check-generated-files.sh` | Verifies gitignored generated files are not tracked in git. | Part of CI; run locally if you added a new generated file. |
| `check-paths.sh` | Validates all relative links in markdown files resolve to real paths. | After adding or moving markdown files. |
| `check-profiles.sh` | Reconciles PROFILE_SERVICES in `config/profiles/*.env` against the enumerations in `docs/architecture/governance/02_profiles.md`. Caught the bld/alertmanager drift on its first run. | After editing a profile env file or 02_profiles.md. |

## The Elision Guard -- Do Not Skip

`check-ai-elisions.sh --staged` is enforced by the `bash-ci.yml` workflow on
every PR. Skipping it locally means CI catches the error and the session is
wasted. Run it before every commit.

Override for intentional large rewrites only:
```bash
AIXCL_ALLOW_MASS_DELETE=1 ./scripts/checks/check-ai-elisions.sh --staged
```
State the intent explicitly in the commit message when using the override.

## Agent Guidance

**You MAY:**
- Add new validation scripts following the existing pattern
- Extend existing scripts

**You MUST NOT:**
- Remove or weaken `check-ai-elisions.sh` -- it protects the repository from a
  class of AI-specific corruption that is otherwise invisible until production

## Cross-References

- `.github/workflows/bash-ci.yml` -- runs check-ai-elisions and check-paths
- `.github/workflows/documentation-checks.yml` -- runs check-paths, check-generated-files, and check-profiles
- `.github/workflows/security.yml` -- runs ShellCheck
- `.claude/rules/ci-checks.md` -- full CI workflow summary
