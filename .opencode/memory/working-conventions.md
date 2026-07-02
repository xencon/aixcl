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
