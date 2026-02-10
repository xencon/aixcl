# CLI vs Documentation Alignment Report

This report compares the **aixcl** CLI implementation (root `aixcl` script and `completion/aixcl.bash`) with all documentation that describes command usage. Use it to create issues and PRs to align the docs with the CLI.

**Report date:** 2025-02-10  
**Scope:** Arguments and options for `aixcl`; no behavioral or governance changes.

---

## 1. Canonical CLI Surface (from `aixcl` script)

### Top-level commands
- `stack` — stack operations
- `service` — single-service control
- `models` — model management
- `council` — LLM Council config
- `dashboard` — open web UIs
- `utils` — check-env, bash-completion
- `continue` — Continue CLI config
- `help` — help menu
- **Top-level aliases (no `utils` prefix):** `check-env`, `bash-completion`

### stack
- `stack start [--profile <profile>]` or `stack start [-p <profile>]` — profile from `.env` if not set; without profile and without PROFILE in .env, script shows profiles and exits.
- `stack stop` — no arguments.
- `stack restart [--profile|-p <profile>] [service1] [service2] ...` — either restart **specific services** (no profile needed) or **entire stack** (profile from CLI or .env).
- `stack status` — no arguments.
- `stack logs` — all services: last 100 lines then follow.
- `stack logs <service> [n]` — one service: last `n` lines (default **50**), then follow; `n` must be 1–10000.
- `stack clean` — no arguments.

### service
- `service start|stop|restart <name>` — one service name.

### models
- `models add <name> [name ...]` — one or more models.
- `models remove <name> [name ...]` — one or more models.
- `models list` — no arguments.

### council
- `council configure` — interactive.
- `council status` — no arguments.

### dashboard
- `dashboard openwebui|grafana|pgadmin` — one target.

### utils
- `utils check-env` — no arguments.
- `utils bash-completion` — no arguments.

### continue
- `continue config` — regenerate Continue CLI config from Ollama models.

### .env location
- `.env` and `.env.example` are read from the **repository root** (directory of the `aixcl` script), not from `~`.

---

## 2. Issues for Review

### 2.1 docs/reference/manpage.txt

| # | Issue | Severity | Detail |
|---|--------|-----------|--------|
| M1 | **Missing `continue` command** | High | CLI has `continue config`; manpage has no `continue` section. |
| M2 | **Missing short option `-p` for profile** | Medium | CLI accepts `-p` as shorthand for `--profile`; manpage only shows `--profile`. |
| M3 | **`stack restart` incomplete** | High | Manpage says "Restart the entire stack" only. CLI also allows `stack restart ollama llm-council` (specific services, no profile). Should document: `stack restart [--profile <profile>] [service1] [service2] ...`. |
| M4 | **`stack logs` missing detail** | Medium | Manpage says "optional line count" but not: default 50, range 1–10000, or that single-service form follows logs after tail. |
| M5 | **`models` synopsis implies single name** | Medium | Manpage shows `models <add\|remove\|list> [name]`. CLI allows multiple: `models add a b c`, `models remove a b`. |
| M6 | **Top-level `check-env` and `bash-completion` not documented** | Low | Users can run `./aixcl check-env` and `./aixcl bash-completion` without `utils`; manpage only documents `utils check-env` and `utils bash-completion`. |
| M7 | **FILES section wrong** | High | Manpage says `~/.env`, `~/.env.example`, `~/.env.local`. CLI uses **project directory** `.env` (same directory as the `aixcl` script), not home. Should state "project directory" or "current working directory when running from repo root". |

---

### 2.2 README.md (project root)

| # | Issue | Severity | Detail |
|---|--------|-----------|--------|
| R1 | **`stack restart` summary incomplete** | Medium | README shows only `./aixcl stack restart [--profile sys]`. Should mention that specific services can be restarted, e.g. `./aixcl stack restart ollama llm-council`. |
| R2 | **`stack logs` line count not mentioned** | Low | README shows `./aixcl stack logs` and `./aixcl stack logs ollama` but not optional line count (e.g. `stack logs ollama 100`). |
| R3 | **`models add`/`remove` multiple models** | Low | README shows single model only. CLI supports multiple: `./aixcl models add a b c`. |
| R4 | **Top-level `check-env` / `bash-completion`** | Low | README only shows `./aixcl utils check-env` and `./aixcl utils bash-completion`. Could note that `./aixcl check-env` and `./aixcl bash-completion` also work. |

---

### 2.3 docs/user/usage.md

| # | Issue | Severity | Detail |
|---|--------|-----------|--------|
| U1 | **`stack restart` optional services** | Medium | Usage shows only `./aixcl stack restart [--profile sys]`. Should document `./aixcl stack restart ollama llm-council` (and that profile is not required when restarting specific services). |
| U2 | **`stack logs` default and range** | Low | Usage shows "last 50 lines" and "last 100 lines"; could explicitly state default 50 and valid range 1–10000. |
| U3 | **`models add`/`remove` multiple** | Low | Examples use multiple models in one line (e.g. setup); synopsis or "Model Management" could state that multiple names are allowed. |

---

### 2.4 docs/user/setup.md

| # | Issue | Severity | Detail |
|---|--------|-----------|--------|
| S1 | **Wrong command: `./aixcl logs`** | High | Line 133: "View logs: `./aixcl logs`". CLI has no top-level `logs`; correct command is `./aixcl stack logs`. |

---

### 2.5 llm-council/TESTING.md

| # | Issue | Severity | Detail |
|---|--------|-----------|--------|
| T1 | **Wrong command: `./aixcl start`** | High | Lines 7, 23, 39: "Services must be running: `./aixcl start`" and "Start services: `./aixcl start`". CLI has no top-level `start`; correct command is `./aixcl stack start`. |

---

### 2.6 Other references (no change required for alignment)

- **docs/operations/ollama-performance-tuning.md**: Uses `./aixcl stack restart ollama` — correct.
- **docs/operations/ollama-tuning-summary.md**: Uses `./aixcl stack restart ollama` — correct.
- **docs/developer/continue-cli-setup.md**: Uses `./aixcl stack start`, `./aixcl models add/list`, `./aixcl continue config` — correct.
- **llm-council/tests/USAGE.md**: Uses `./aixcl stack restart llm-council` — correct.

---

## 3. Summary Table

| Doc | High | Medium | Low |
|-----|------|--------|-----|
| docs/reference/manpage.txt | 3 (M1, M3, M7) | 3 (M2, M4, M5) | 1 (M6) |
| README.md | 0 | 1 (R1) | 3 (R2, R3, R4) |
| docs/user/usage.md | 0 | 1 (U1) | 2 (U2, U3) |
| docs/user/setup.md | 1 (S1) | 0 | 0 |
| llm-council/TESTING.md | 1 (T1) | 0 | 0 |

**Total:** 5 high, 5 medium, 6 low.

---

## 4. Suggested order of work (for issues/PRs)

1. **High priority (wrong or missing critical info)**  
   - S1 (setup.md): fix `./aixcl logs` → `./aixcl stack logs`.  
   - T1 (llm-council/TESTING.md): fix `./aixcl start` → `./aixcl stack start`.  
   - M7 (manpage): FILES section — document project-directory .env, not ~/.  
   - M1 (manpage): add `continue` command.  
   - M3 (manpage): document `stack restart [--profile <profile>] [service1] [service2] ...`.

2. **Medium priority (completeness and accuracy)**  
   - M2, M4, M5 (manpage): -p, logs detail, models multiple.  
   - R1, U1: document `stack restart` with optional service list.  
   - M6 (manpage): document top-level `check-env` and `bash-completion`.

3. **Low priority (nice to have)**  
   - R2, R3, R4 (README); U2, U3 (usage.md): optional line count, multiple models, top-level utils aliases.

---

## 5. Single source of truth

- **CLI behavior:** Root `aixcl` script and `completion/aixcl.bash`.  
- **Reference doc:** `docs/reference/manpage.txt` should be the single place that lists every command, subcommand, option, and alias.  
- **User/README docs:** Should stay consistent with the manpage and CLI; any new option or alias should be added to the manpage first, then reflected in user-facing docs as needed.

---

*This report is for review only. Create issues and PRs per the project's Issue-First Development workflow.*
