# CONTEXT: lib/cli/

Low-level CLI infrastructure. This is the foundation that all `./aixcl` commands
build on -- changes here affect the entire CLI.

## Contents

| File | Purpose |
|------|---------|
| `profile.sh` | Loads the active profile env file from `config/profiles/`, exports the service list for the active profile, and provides `get_profile_services_for_profile()`. This is the first thing `stack.sh` calls. |

## Agent Guidance

**IMPORTANT:** Use plan mode (`/mode planning` in Claude Code) before making
architectural changes to `profile.sh`. This is explicitly required by `CLAUDE.md`.

**You MAY:**
- Add helper functions used by profile loading
- Update service lists when adding a profile-registered service

**You MUST NOT:**
- Change the profile loading semantics without updating `docs/architecture/governance/02_profiles.md`
- Add service-specific business logic here -- this is a pure control-plane primitive
- Remove or rename `get_profile_services_for_profile()` -- it is called by `stack.sh`

## Profile System Overview

```
config/profiles/bld.env   --+
config/profiles/sys.env   --+--> lib/cli/profile.sh --> stack.sh --> services/docker-compose.yml
```

Adding a service to a profile requires changes in three places:
1. `config/profiles/<profile>.env` -- add service name to the list
2. `services/docker-compose.yml` -- define the service
3. `docs/architecture/governance/02_profiles.md` -- document the change

Use the `add-service` skill (`.claude/skills/add-service/`) for the full checklist.

## Cross-References

- `config/profiles/` -- env files sourced by this script
- `lib/aixcl/commands/stack.sh` -- primary consumer
- `docs/architecture/governance/02_profiles.md` -- profile semantics
- `.claude/skills/add-service/SKILL.md` -- guided workflow for adding a service
