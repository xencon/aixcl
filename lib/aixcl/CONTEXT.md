# CONTEXT: lib/aixcl/

CLI entry layer for `./aixcl`: help text, argument dispatch, and the
command implementations. The `./aixcl` script at the repository root
sources this layer; it is the single entry point for both runtime and
developer workflow.

## Contents

| Path | Purpose |
|------|---------|
| `cli.sh` | Help menu and CLI surface definition (`help_menu()`); the user-visible command reference |
| `dispatcher.sh` | `main()` -- routes `<group> <action>` arguments to the command functions |
| `commands/` | One file per command group (stack, models, checks, release, ...) -- see `commands/CONTEXT.md` |

## Agent Guidance

**You MAY:**
- Add a new command group: implement it under `commands/`, route it in `dispatcher.sh`, document it in `cli.sh` `help_menu()` and `completion/aixcl.bash` -- all four in the same change
- Improve help text and CLI ergonomics without changing semantics

**You MUST NOT:**
- Change command semantics without an issue (CLI is a documented contract)
- Introduce runtime-core dependencies on operational services (AGENTS.md invariant)
- Let `help_menu()`, the dispatcher, and bash completion drift apart -- they describe the same surface

## Cross-References

- `lib/aixcl/commands/CONTEXT.md` -- per-command-group contract
- `lib/cli/CONTEXT.md` -- lower-level profile loading these commands build on
- `completion/aixcl.bash` -- bash completion that must track the dispatcher
