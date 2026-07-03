# Formatting and Conventions

## Titles
- **Issues**: `[TYPE] Description` (e.g., `[TASK] Setup agent`, not `[TASK]: Setup agent`)
- **PRs**: `Description (#<number>)` (e.g., `Setup agent template (#42)`, not `Setup: agent template (#42)`)
- NO colons in issue or PR titles

## Text
- Use plain ASCII. No Unicode checkmarks, no emoji.
  - **Exception**: Release notes may use the green checkmark emoji (U+2705) for visual checkbox indicators in GitHub release pages, where markdown `- [x]` does not render interactively.
- Use markdown checkboxes: `- [x]` for completed, `- [ ]` for incomplete (for issues, PRs, and documentation)
- Use Unix line endings (LF) -- CRLF is rejected by CI

### Scope of the ASCII rule
The ASCII mandate applies to markdown files, issues, PRs, commit messages,
and documentation -- artifacts that travel through git, CI, and web UIs.
Interactive terminal output (CLI status icons) MAY use Unicode glyphs
provided every glyph has an ASCII fallback (the `${ICON_*:-[x]}` pattern
in lib/) so non-UTF-8 terminals degrade gracefully.

## Labels
**Issue Types** (select exactly one): `Bug`, `Feature`, `Task`
**Component Labels** (required): `component:runtime-core`, `component:ollama`, `component:persistence`, `component:observability`, `component:ui`, `component:cli`, `component:infrastructure`, `component:testing`
**Priority** (optional): `P1`, `P2`, `P3`
**Profile** (optional): `profile:bld`, `profile:sys`
**Category** (optional): `Fix`, `Enhancement`, `Refactor`, `Maintenance`
**Agent queue** (optional): `agent:qwen` -- marks an issue as queued for a named agent

## Commits
- Allowed types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`, `ci`
- Reference issue: `Fixes #<n>` or `Addresses #<n>`
- First line under 72 characters

## Issue and Pull Request Bodies
- Do **not** hard-wrap prose paragraphs at a fixed column width.
- Each paragraph in an issue or PR body should be a single source line, however long.
- List items, headings, code fences, tables, and command examples keep their normal structure.
- Multiple discrete references inside a single list item should be split into separate list entries rather than comma-packed on one line.
- Rationale: GitHub's renderer reflows paragraphs to the viewport anyway, while hard-wrapping creates noisy multi-line diffs whenever a paragraph is edited. Separating discrete references keeps diffs localized to the changed item.
- This convention applies to issue and PR bodies specifically; other markdown files in the repository keep their existing wrapping style unless separately agreed.

## Lazy-Loading
Load files on a need-to-know basis:
- Creating an issue -> Read `.github/ISSUE_TEMPLATE/task.md` first
- Creating a PR -> Read `.github/PULL_REQUEST_TEMPLATE.md` first
- Releasing -> Read `CHANGELOG.md` to extract latest version entry
