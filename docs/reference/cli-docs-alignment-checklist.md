# CLI Documentation Alignment Checklist (March 2026)

This checklist tracks the alignment between the **aixcl** CLI implementation and its documentation (Manpage, Usage Guide, README).

Reference: [Consistency Gap Report (2026)](./consistency-gap-report-2026.md)

---

## 1. High Priority: Foundational Alignment

- [x] **Archive Deprecated Commands** — References to `opencode` and `dashboard` as top-level CLI commands have been removed from README, Usage, and Manpage.
- [x] **Top-level `restart` alias** — Documented the `aixcl restart [service]` top-level alias in the Manpage.
- [x] **Sync `stack start/restart`** — Manpage and Usage Guide consistently document both `--profile` and `-p` short-form.
- [x] **Engine Configuration** — `config engine <set|auto> [engine]` is fully described in the Manpage.
- [x] **Models multiple args** — `models add` and `models remove` are documented as accepting one or more model names.

---

## 2. Medium Priority: Detailed Usage

- [x] **`stack logs` detail** — Documented default lines (50), range (1-10000), and the `engine` alias in all relevant files.
- [x] **`service {start|stop|restart}`** — All three actions for individual services are documented consistently.
- [x] **`utils {check-env|bash-completion}`** — Correctly documented as subcommands of `utils`.

---

## 3. Low Priority: Polish & Aliases

- [x] **Manpage SYNOPSIS** — Updated SYNOPSIS to reflect current command structure, including top-level aliases like `restart`.
- [x] **Manpage FILES** — Verified that `.env` location is correctly documented as the project root.

---

## Target Files for Review

| File | Status | Notes |
|------|--------|-------|
| `docs/reference/manpage.txt` | [x] | Updated SYNOPSIS and COMMANDS |
| `docs/user/usage.md` | [x] | Verified current aliases and usage |
| `README.md` | [x] | Verified no deprecated CLI commands |
| `docs/user/setup.md` | [x] | Fixed numbering and clarified logs/engines |

---
*Updated based on the ./aixcl help output in March 2026.*
