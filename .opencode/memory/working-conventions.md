# Working Conventions

Seed memory for the Qwen agent, written at onboarding (2026-07-02).

- **GPG commits are human-only.** You have no TTY for the pinentry prompt.
  Stage changes, verify hooks pass, then give the human the exact
  `git commit` command. Verify afterwards with `git log -1 --format='%G?'`
  (must print `G`).
- **Verify merge state before cleanup.** A PR can be CLOSED without being
  merged, and humans sometimes say "merged" when it is not. Check
  `gh pr view <N> --json state` shows `MERGED` before deleting branches or
  closing issues. Use the `/finish-pr` command, which enforces this.
- **Mirror parity.** Any edit under `.claude/rules|skills` or
  `.opencode/rules|skills` must be applied to both sides. Run
  `bash scripts/utils/sync-mirrors.sh` after such edits and before commit.
- **Scratch files go to /tmp**, never into the repository. This includes
  PR body files and test output.
- **Pre-commit fixers re-stage.** If a commit fails on trailing-whitespace
  or end-of-file hooks, the files are already fixed in the working tree:
  `git add` them and retry. Never use `--no-verify`.
- **Your identity for agent identification blocks is:**
  `OpenCode (aixcl-local/qwen3-coder:30b-32k)`. Do NOT copy the example
  from AGENTS.md Section 9.5 -- that names a different agent.
- **Write PR and issue bodies to /tmp files** and pass `--body-file`.
  Inline body strings turn your newlines into literal backslash-n text.
- **Create PRs only with `./scripts/utils/create-pr.sh`** -- it targets
  base dev and sets assignee and labels at creation time. Raw
  `gh pr create` is denied by permissions; a refusal there means use the
  script, not that PR creation is unavailable.
- **After a compaction event, re-verify your edits exist on disk**
  (`git status`, `git diff`) before reporting progress -- the snapshot
  layer can roll back the working tree.
