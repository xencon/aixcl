# Formatting and Conventions

**Canonical text: AGENTS.md Section 3 (Label Taxonomy, Formatting Rules),
Section 10 (Quick References -- Lazy-Loading), and DEVELOPMENT.md
Section 4 (Commit message format).** This file is a summary for the rules
set; it adds no policy of its own. If this summary and AGENTS.md/
DEVELOPMENT.md ever disagree, those files win.

## Scope of the ASCII rule

The ASCII mandate applies to markdown files, issues, PRs, commit messages,
and documentation -- artifacts that travel through git, CI, and web UIs.
Interactive terminal output (CLI status icons) MAY use Unicode glyphs
provided every glyph has an ASCII fallback (the `${ICON_*:-[x]}` pattern
in lib/) so non-UTF-8 terminals degrade gracefully.

### ASCII exception: release notes

Release notes may use the green checkmark emoji (U+2705) for visual
checkbox indicators in GitHub release pages, where markdown `- [x]` does
not render interactively.

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
