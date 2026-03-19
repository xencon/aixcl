# CLI Documentation Alignment Checklist (March 2026)

This checklist tracks the alignment between the **aixcl** CLI implementation and its documentation.

Reference: [Consistency Gap Report (2026)](./consistency-gap-report-2026.md)

---

## 1. High Priority: Foundational Alignment

- [ ] **Archive Deprecated Commands** — Ensure all documentation (Usage, Manpage, README) has removed references to `continue` and `dashboard` as top-level CLI commands.
- [ ] **Sync stack start/restart** — Verify that `stack start` and `stack restart` documentation correctly reflects the `--profile` (`-p`) behavior and the optional service list for restart.
- [ ] **Engine Configuration** — Ensure `config engine <set|auto>` is fully documented in the manpage and usage guide.
- [ ] **Models multiple args** — Verify that `models add` and `models remove` are documented as accepting one or more model names.

---

## 2. Medium Priority: Detailed Usage

- [ ] **stack logs detail** — Document default (50), range (1-10000), and the `engine` alias in all relevant files.
- [ ] **service {start|stop|restart}** — Ensure all three actions for individual services are documented consistently.
- [ ] **utils check-env/bash-completion** — Verify these are correctly documented as subcommands of `utils` (not top-level aliases).

---

## 3. Low Priority: Polish & Aliases

- [ ] **Top-level restart alias** — Ensure the `restart` command is mentioned as a shorthand for `stack restart`.
- [ ] **Manpage SYNOPSIS** — Ensure the SYNOPSIS reflects the current command structure accurately.
- [ ] **Manpage FILES** — Verify that `.env` location is correctly documented as the project root.

---

## Target Files for Review

| File | Status | Notes |
|------|--------|-------|
| `docs/reference/manpage.txt` | [ ] | Primary reference |
| `docs/user/usage.md` | [ ] | User-facing guide |
| `README.md` | [ ] | Quick start reference |
| `docs/user/setup.md` | [ ] | Installation & initialization |

---
*Generated based on the ./aixcl help output in March 2026.*
