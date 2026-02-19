# Plan: Rename "llm-council" to "council"

**Goal:** Change all references to "llm-council" / "LLM-Council" / "LLM Council" to "council" / "Council" in code and documentation.

**Scope:** Service/container names, image names, volume names, profile definitions, documentation prose, file paths, script names, and (optionally) the component directory name.

---

## 1. Complexity assessment

| Category | Count (approx) | Risk | Notes |
|----------|----------------|------|--------|
| **Docker Compose** | 1 service block + 1 override | High | Service name becomes container name; all scripts assume `llm-council`. Must change in one coordinated pass. |
| **Profile / CLI** | profile.sh, aixcl, completion | High | RUNTIME_CORE_SERVICES and PROFILE_SERVICES list service names; aixcl has 30+ references (container checks, build, logs, status, council configure). |
| **Lib / tests** | common.sh, platform-tests.sh, runtime-core, api, db scripts | Medium | Service name in ALL_SERVICES; health checks; paths to `llm-council/`. |
| **Docs** | 20+ files | Low | Text and code-block updates; some link to `llm-council/` or `llm-council.md`. |
| **Component directory** | `llm-council/` | High (if renamed) | Build context, imports, paths in docs/scripts. Renaming to `council/` is optional (see 5.2). |
| **Other** | .gitignore, .env.example, .continue, scripts, service contract file | Low–Medium | Volume name, label, config strings. |

**Overall:** Medium–high. The rename is broad but mechanical. The main risk is missing a reference and breaking runtime (e.g. compose service name vs script still using `llm-council`). Doing the Docker + profile + scripts in one branch/PR, then docs in the same or follow-up, keeps the change coherent.

---

## 2. Definition of "council" usage

| Context | From | To |
|----------|------|-----|
| Docker Compose service name | `llm-council` | `council` |
| Container name | `llm-council` | `council` |
| Docker image name | `llm-council:latest` | `council:latest` |
| Build context path | `../llm-council` | `../council` (only if directory renamed; else keep `../llm-council`) |
| Volume name (host path) | `llm-council-data` | `council-data` |
| Profile / CLI service list | `llm-council` | `council` |
| Display / prose (product name) | LLM-Council, LLM Council | Council |
| Code comments / docstrings | LLM Council, llm-council | Council, council |
| GitHub label | `component:llm-council` | `component:council` |
| Service contract filename | `llm-council.md` | `council.md` |
| Script name | `build_and_push_llm_council.sh` | `build_and_push_council.sh` |
| .gitignore directory | `llm-council-data/` | `council-data/` |
| API response / logging | e.g. "LLM Council API" | "Council API" (or keep as-is in API for backward compatibility; decide per team) |

---

## 3. Inventory by file (implementation order)

### 3.1 Infrastructure (do first — single source of truth)

| File | Changes |
|------|--------|
| `services/docker-compose.yml` | Service key `llm-council` → `council`; `context: ../llm-council` → `../council` if dir renamed (else keep); `image: council:latest`; `container_name: council`; volume `../council-data` (or keep `llm-council-data` until dir/volume rename). |
| `services/docker-compose.gpu.yml` | Service key `llm-council` → `council`. |
| `cli/lib/profile.sh` | `RUNTIME_CORE_SERVICES=(ollama council)`; `PROFILE_SERVICES` every `llm-council` → `council`. |
| `lib/common.sh` | In `ALL_SERVICES`, `"llm-council"` → `"council"`. |

### 3.2 Main CLI and completion

| File | Changes |
|------|--------|
| `aixcl` | All `llm-council` (container/service name) → `council`; all "LLM-Council" / "LLM Council" display strings → "Council". Includes: build context path (if dir renamed), `run_compose build/stop/up`, `docker ps` grep, logs, status, council configure/status, help text. |
| `completion/aixcl.bash` | `runtime_core_services="ollama council"`; comments "llm-council" → "council". |

### 3.3 Scripts

| File | Changes |
|------|--------|
| `scripts/build_and_push_llm_council.sh` | Rename to `build_and_push_council.sh`; `IMAGE_NAME="council"`; echo "Council"; any path to `llm-council` → `council` if dir renamed. |
| `scripts/db/create_databases.sh` | "LLM Council" → "Council" in message. |
| `scripts/setup_fast_recovery.sh` | Replace any `llm-council` (container/service) and "LLM Council" text with `council` / "Council". |
| `scripts/db/count_continue_conversations.py` | If it references `llm-council` (e.g. in comments or strings), update to `council`. |

### 3.4 Tests

| File | Changes |
|------|--------|
| `tests/platform-tests.sh` | `LLM_COUNCIL_DIR` → `COUNCIL_DIR` and path `llm-council` → `council` if dir renamed; container/service name `llm-council` → `council`; "LLM-Council" → "Council" in messages. |
| `tests/runtime-core/*.py` and `*.md` | "LLM Council" / "llm-council" (container) → "Council" / "council". |
| `tests/api/test_continue_integration.py` | Comments and messages "LLM Council" → "Council"; if any container/service name, → `council`. |
| `tests/api/README.md`, `tests/database/*`, `tests/README.md` | Prose and examples: LLM Council → Council; container name llm-council → council. |

### 3.5 Component: `llm-council/` (or `council/` after rename)

| File | Changes |
|------|--------|
| `llm-council/Dockerfile` | Comment "Council" (no "LLM-"). |
| `llm-council/backend/main.py` | `title="Council API"`; logger/return "Council API"; `"owned_by": "council"`. |
| `llm-council/backend/config.py`, `council.py`, `config_manager.py`, `ollama_adapter.py`, `__init__.py` | Docstrings "LLM Council" → "Council" (or "council" where referring to the service). |
| `llm-council/pyproject.toml` | description = "Council" (or similar). |
| `llm-council/README.md`, `TESTING.md`, `PERFORMANCE_OPTIMIZATIONS.md`, `COUNCIL_*.md`, `EVALUATION_LEARNINGS.md` | Prose and headings: "LLM Council" → "Council"; any path or container name `llm-council` → `council`. |
| `llm-council/tests/*`, `llm-council/scripts/test/*` | Same: prose and code examples. |
| `llm-council/uv.lock` | Only if project name in pyproject.toml changes and lock is regenerated. |

### 3.6 Documentation (outside component)

| Area | Changes |
|------|--------|
| `docs/architecture/governance/00_invariants.md` | "LLM-Council" → "Council"; note about Docker-managed runtime core. |
| `docs/architecture/governance/02_profiles.md` | "LLM-Council" → "Council"; "llm-council" in profile mappings only if profile.sh already uses `council` (doc should match code). |
| `docs/architecture/governance/03_stack_status.md` | Example line `llm-council` → `council`. |
| `docs/architecture/governance/service_contracts/runtime/llm-council.md` | Rename file to `council.md`; title and body "LLM-Council" → "Council". |
| `docs/developer/development-workflow.md` | "LLM-Council", `component:llm-council` → "Council", `component:council`. |
| `docs/developer/contributing.md` | "llm-council" in runtime core list → "council". |
| `docs/developer/continue-cli-setup.md` | "LLM-Council" → "Council". |
| `docs/operations/ollama-*.md`, `model-recommendations.md` | "LLM Council" / "LLM-Council" → "Council". |
| `docs/user/setup.md`, `docs/user/usage.md` | All references; paths like `llm-council/backend/migrations` → `council/...` if dir renamed. |
| `docs/reference/manpage.txt` | "llm-council" (service name) → "council"; "LLM Council" → "Council". |
| `docs/reference/cli-docs-alignment-*.md` | Examples and checklist text. |
| `docs/README.md` | "LLM-Council", `llm-council/` links. |
| `README.md` | All "LLM-Council" / "LLM Council"; links to `llm-council/` → `council/` if dir renamed. |
| `CHANGELOG.md` | Historical entries can stay; new entry for rename can say "Renamed llm-council to council". |

### 3.7 Config and repo metadata

| File | Changes |
|------|--------|
| `.env.example` | Comment "# Council Configuration" (was "LLM Council"). |
| `.gitignore` | `llm-council-data/` → `council-data/`. |
| `.continue/cli-ollama.yaml` | Comment "no Council" (was "no LLM-Council"). |
| `.continue/agents/agent-developer-workflow.md` | `component:llm-council` → `component:council`. |
| `.continue/council/config.yaml` | "Council" in model name/title if present. |

### 3.8 GitHub

| Item | Change |
|------|--------|
| Label | Rename label `component:llm-council` to `component:council` in repo (or add `component:council` and deprecate the old one). |

---

## 4. Directory rename: `llm-council/` → `council/`

**Option A — Rename directory:**  
- Rename `llm-council/` to `council/`.  
- Update: `docker-compose.yml` build context `context: ../council`; `aixcl` build context; `tests/platform-tests.sh` `COUNCIL_DIR`; every doc and script that references path `llm-council/` (e.g. migrations path, README links, setup.md, CHANGELOG).  
- **Pro:** Single consistent name everywhere. **Con:** Large diff; external references (forks, bookmarks, old docs) may break.

**Option B — Keep directory name `llm-council/`:**  
- Do not rename the directory.  
- Only change: service/container/image/volume names, profile and CLI references, and all user-facing/documentation text to "council" / "Council".  
- **Pro:** Smaller change; paths and build context stay the same. **Con:** Directory still called `llm-council` while the product is "Council".

**Recommendation:** Decide explicitly. If the goal is "all references to llm-council to simply council", Option A is consistent but higher risk; Option B is safer and still satisfies "council" in the CLI and docs. Plan below assumes **Option B** (no directory rename) unless the team chooses Option A.

---

## 5. Execution plan

### Phase 1: Infrastructure and runtime (one branch/PR)

1. **Compose and profile**
   - In `services/docker-compose.yml`: service `council`, `image: council:latest`, `container_name: council`. Keep `context: ../llm-council` and volume `../llm-council-data` if directory/volume not renamed; otherwise switch to `../council` and `../council-data`.
   - In `services/docker-compose.gpu.yml`: service `council`.
   - In `cli/lib/profile.sh`: `council` in RUNTIME_CORE_SERVICES and in all PROFILE_SERVICES.
   - In `lib/common.sh`: `"council"` in ALL_SERVICES.

2. **CLI and completion**
   - In `aixcl`: replace every use of the service/container name `llm-council` with `council` (compose commands, docker ps/logs, status, build path if applicable); replace display strings "LLM-Council" / "LLM Council" with "Council".
   - In `completion/aixcl.bash`: `council` in runtime core list and comments.

3. **Scripts and tests**
   - Update `scripts/build_and_push_llm_council.sh` (or renamed `build_and_push_council.sh`) to use image name `council` and any container references.
   - Update `scripts/db/create_databases.sh`, `scripts/setup_fast_recovery.sh`, `scripts/db/count_continue_conversations.py` for "Council" and container/service `council`.
   - Update `tests/platform-tests.sh` and all test scripts/docs under `tests/` for service/container `council` and "Council" in messages.

4. **Smoke check**
   - After merge: `./aixcl stack start --profile usr` (or dev), then `./aixcl stack status` and `./aixcl council status`; confirm container name `council` and no references to `llm-council` in CLI output.

### Phase 2: Documentation and config

5. **Docs**
   - Apply the documentation inventory in 3.6 and 3.5 (component docs): all "LLM-Council" / "LLM Council" / "llm-council" (where it means the product or service) → "Council" / "council"; update service contract filename to `council.md` and its content; fix any links that pointed to `llm-council.md`.

6. **Config and repo**
   - `.env.example`, `.gitignore`, `.continue/*`, and (if desired) CHANGELOG entry.
   - GitHub label: create/rename to `component:council`, update workflow/contributing if they reference the label.

### Phase 3 (optional): Directory and volume rename

7. **If Option A chosen**
   - Rename `llm-council/` → `council/`.
   - Update every path in 3.1–3.6 that points at `llm-council` (compose context, aixcl, platform-tests, docs, scripts, .gitignore).
   - Rename volume host path `llm-council-data` → `council-data` and update compose and .gitignore.
   - Re-run tests and a quick manual run.

---

## 6. Order of operations (checklist)

- [ ] **Decision:** Directory rename (A) or not (B). If (A), add path/volume updates to Phase 1.
- [ ] **Phase 1.1** — docker-compose.yml, docker-compose.gpu.yml, profile.sh, common.sh.
- [ ] **Phase 1.2** — aixcl, completion/aixcl.bash.
- [ ] **Phase 1.3** — scripts (build_and_push, db, setup_fast_recovery), tests (platform-tests, runtime-core, api, database, READMEs).
- [ ] **Phase 1.4** — llm-council/ backend strings (main.py, docstrings, pyproject.toml) and component docs (README, TESTING, etc.).
- [ ] **Phase 1.5** — Run stack and council status; fix any missed references.
- [ ] **Phase 2.1** — docs/ (governance, developer, operations, user, reference).
- [ ] **Phase 2.2** — README.md, CHANGELOG.md, .env.example, .gitignore, .continue.
- [ ] **Phase 2.3** — Service contract rename llm-council.md → council.md; GitHub label.
- [ ] **Phase 3 (if Option A)** — Directory and volume rename; full path pass.

---

## 7. Rollback

- Revert the branch(es) that perform the rename.
- If volume was renamed, existing data lives in the old volume name; restore compose and .gitignore to the old volume name if rollback is needed.

---

*Document generated for the llm-council → council rename. Update this plan if scope or decisions change.*
