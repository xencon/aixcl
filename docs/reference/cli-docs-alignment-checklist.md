# CLI Documentation Alignment Checklist

Ordered by priority. Work through one PR at a time; verify and test before merging.

Reference: [cli-docs-alignment-report.md](./cli-docs-alignment-report.md)

---

## High priority

- [ ] **1. docs/user/setup.md (S1)** — Fix wrong command: `./aixcl logs` → `./aixcl stack logs`
- [ ] **2. council/TESTING.md (T1)** — Fix wrong command: `./aixcl start` → `./aixcl stack start`
- [ ] **3. docs/reference/manpage.txt (M7)** — FILES: document project-directory `.env`, not `~/.env`
- [ ] **4. docs/reference/manpage.txt (M1)** — Add `continue` command section (`continue config`)
- [ ] **5. docs/reference/manpage.txt (M3)** — Document `stack restart [--profile <p>] [service1] [service2] ...`

---

## Medium priority

- [ ] **6. docs/reference/manpage.txt (M2)** — Document short option `-p` for `--profile`
- [ ] **7. docs/reference/manpage.txt (M4)** — `stack logs`: document default 50, range 1–10000, follow behavior
- [ ] **8. docs/reference/manpage.txt (M5)** — `models`: document multiple names for add/remove
- [ ] **9. docs/reference/manpage.txt (M6)** — Document top-level `check-env` and `bash-completion`
- [ ] **10. README.md (R1)** — Document `stack restart` with optional service list
- [ ] **11. docs/user/usage.md (U1)** — Document `stack restart` with optional service list

---

## Low priority

- [ ] **12. README.md (R2)** — Mention optional line count for `stack logs <service> [n]`
- [ ] **13. README.md (R3)** — Mention multiple models for `models add`/`remove`
- [ ] **14. README.md (R4)** — Note top-level `check-env` and `bash-completion`
- [ ] **15. docs/user/usage.md (U2)** — State default 50 and range 1–10000 for `stack logs`
- [ ] **16. docs/user/usage.md (U3)** — State multiple names allowed for `models add`/`remove`

---

## PR grouping (for implementation)

| PR | Issue | Scope | Checklist items |
|----|--------|--------|------------------|
| [#424](https://github.com/xencon/aixcl/pull/424) | #423 | docs/user/setup.md + alignment report & checklist | 1 |
| [#426](https://github.com/xencon/aixcl/pull/426) | #425 | council/TESTING.md | 2 |
| [#428](https://github.com/xencon/aixcl/pull/428) | #427 | docs/reference/manpage.txt | 3, 4, 5, 6, 7, 8, 9 |
| [#430](https://github.com/xencon/aixcl/pull/430) | #429 | README.md | 10, 12, 13, 14 |
| [#432](https://github.com/xencon/aixcl/pull/432) | #431 | docs/user/usage.md | 11, 15, 16 |

**Suggested merge order:** 424 (adds checklist and report), then 426, 428, 430, 432. Verify and test each before merging.

---

*After merging each PR, check off the corresponding items above.*
