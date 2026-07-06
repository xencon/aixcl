# OpenCode Integration for AIXCL

OpenCode is the recommended AI coding assistant for AIXCL. It connects to any provider via the OpenAI-compatible API and provides chat, autocomplete, and agentic workflows.

## Quick Start

```bash
# Ensure the stack is running (for local provider)
./aixcl stack start --profile sys
./aixcl stack status

# Start OpenCode from the repo root
opencode

# Connect to a provider
/connect
```

The `agent-context` agent and governance rules load automatically from `opencode.json`.

## Configuration (`opencode.json`)

The repo-root `opencode.json` is **gitignored runtime config**. The canonical template is `config/opencode.json.example` -- do not restate its contents anywhere (including this doc); read the template itself. Set it up with:

```bash
cp config/opencode.json.example opencode.json
```

Every durable config change goes to BOTH files: edit the template (tracked, reviewed) and apply the same change to your local copy.

Key facts (see the template for the full source of truth):

- `instructions` auto-loads `AGENTS.md`, `.opencode/rules/*.md`, and `.opencode/memory/MEMORY.md` into every session. Keep this set lean -- it costs context tokens every session.
- No `model` is pinned in the template. Connect via `/connect`, or use `./aixcl models add <name>` which syncs the local `opencode.json`.
- `snapshot: true` enables OpenCode's undo layer. Be aware it has been observed rolling back working-tree edits around compaction events.

### Permission Guardrails

Permissions follow deny/ask/allow patterns (last match wins). The default for `bash` and `edit` is `ask`; read-only inspection commands are allowlisted. The **deny set** is the security boundary humans should audit -- these are hard-blocked for the local agent:

| Denied pattern | Why |
|----------------|-----|
| `rm -rf*` | Destructive filesystem operation |
| `git push --force*` | Destroys remote history |
| `git push upstream*` | Never push to the canonical repo directly -- PRs only |
| `git reset --hard*` | Destroys local work |
| `git commit*--no-verify*` | Bypasses pre-commit checks |
| `git commit*--no-gpg-sign*` | Bypasses the signing requirement |
| `gh pr merge*` | Merging is a human (or supervising-agent) decision |
| `gh pr create*` | PRs must go through `scripts/utils/create-pr.sh` (validation, labels, assignee) |
| `gh release*` | Releases are human-driven |
| `./aixcl release tag*` | Tagging is human-driven |
| `./aixcl utils prune*` | Destructive cleanup |

If a change to this table is proposed, treat it as a `[SECURITY]` change: update `config/opencode.json.example` and this table in the same PR, with explicit maintainer approval.

## Extending OpenCode

Custom agents, skills, and rules can be added to the repo without modifying `opencode.json`:

- **Custom agents:** `.opencode/agents/<name>.md`
- **Custom skills:** `.opencode/skills/<name>/SKILL.md`
- **Custom rules:** `.opencode/rules/<topic>.md`

## Troubleshooting

- **Connection refused**: Ensure `./aixcl stack status` shows the engine as healthy.
- **Model not found**: Verify the model name matches `./aixcl models list`.
- **Agent not following rules**: Confirm `AGENTS.md` and `DEVELOPMENT.md` exist at the repo root and are listed in `opencode.json`.

## References

- [OpenCode Agents](https://opencode.ai/docs/agents/)
- [OpenCode Skills](https://opencode.ai/docs/skills/)
- [OpenCode Permissions](https://opencode.ai/docs/permissions/)
