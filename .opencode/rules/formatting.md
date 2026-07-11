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
