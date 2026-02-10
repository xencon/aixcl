# Plan: Complete Continue CLI Model List (Ollama + Plugin Alignment)

**Goal:** When selecting models in the Continue CLI, the list must be complete: at least all models available in Ollama, and preferably match the Continue (VS Code) plugin config including Council and other entries.

**Current behavior:** `./aixcl continue config` generates `.continue/cli-ollama.yaml` from `get_available_models()`, which runs `docker exec <ollama> ollama list` and parses column 1. The plugin config (`.continue/council/config.yaml`) can include Council (openai + apiBase), AUTODETECT, and embeddings (e.g. nomic-embed-text) that are not in the CLI config.

**Problems:**
1. **Ollama list may be incomplete** – `ollama list` table parsing (awk NR>1 {print $1}) can miss models if output format varies or has multiple columns with spaces.
2. **CLI list does not match plugin** – Plugin has Council, AUTODETECT, and embedding models; CLI config is Ollama-only, so users see a different (smaller) set in the CLI.

---

## 1. Requirements

| Requirement | Description |
|-------------|-------------|
| **Ollama complete** | The CLI config must include **every** model reported by Ollama (no omissions). Prefer a reliable source (Ollama API or robust parsing). |
| **Prefer plugin alignment** | The CLI model list should preferably match the plugin: include Council (Multi-Model), AUTODETECT if desired, and any other plugin entries that the Continue CLI supports. |
| **Backward compatible** | Existing Ollama-only usage remains valid; we only add or fix sources. |

---

## 2. Data Sources

### 2.1 Ollama models (primary – must be complete)

- **Option A (current):** `get_available_models()` → `docker exec <container> ollama list` then `awk 'NR>1 {print $1}'`.
- **Option B (recommended):** Use Ollama API from host or container: `GET http://localhost:11434/api/tags` (or equivalent via container). Response: `{"models":[{"name":"model:tag",...},...]}`. Extract `models[].name` for a definitive list. This avoids table-format parsing issues.
- **Implementation:** Prefer Option B when Ollama is reachable (e.g. curl from host to localhost:11434, or docker exec + curl inside network). Fall back to Option A if API fails. Ensure no duplicates (e.g. same base name with different tags).

### 2.2 Plugin config (alignment)

- **File:** `.continue/council/config.yaml` (plugin config).
- **Contents of interest:**
  - **Council (Multi-Model):** `provider: openai`, `model: council`, `apiBase: http://localhost:8000/v1`, `apiKey: local`. Add to CLI config if Continue CLI supports openai with custom apiBase.
  - **AUTODETECT:** `provider: ollama`, `model: AUTODETECT`. Optional: add to CLI so “Autodetect” appears in the list.
  - **Embeddings (e.g. nomic-embed-text):** Plugin has `roles: [embed]`. CLI may or may not list these for chat; include only if they are useful in the CLI model selector (or skip to avoid noise).
- **Decision:** Add Council entry to `.continue/cli-ollama.yaml` when generating if (1) plugin config exists and contains a Council model and (2) Continue CLI supports openai provider with apiBase. Add AUTODETECT if we want parity with the plugin. Document any provider/role limitations.

---

## 3. Implementation Outline

### 3.1 Reliable Ollama model list

- Add a helper (e.g. in `lib/council_utils.sh` or in aixcl) that:
  - Tries Ollama API first: `curl -s http://localhost:11434/api/tags` (from host; ensure Ollama port is mapped). Parse JSON for `models[].name`.
  - If API is unreachable (e.g. no curl or non-zero exit), fall back to `get_available_models()` (existing `ollama list` parsing).
- Use this helper in `continue_config()` so the generated YAML includes every Ollama model.

### 3.2 Merge plugin config into CLI config

- In `continue_config()`:
  1. Build the list of models as today: all Ollama models (using the new reliable list).
  2. If `.continue/council/config.yaml` exists, parse it (grep/sed or similar for `provider:`, `model:`, `apiBase:`, `name:` under `models:`).
  3. For each plugin entry:
     - **Council (openai + apiBase):** If CLI supports it, append one block: name “Council (Multi-Model)”, provider openai, model council, apiBase, apiKey local.
     - **AUTODETECT (ollama):** Optionally append so the CLI shows “Autodetect” like the plugin.
     - **Embedding-only models:** Optional; skip unless we want them in the CLI picker.
  4. Emit YAML: Ollama models first (with provider ollama, capabilities, roles as today), then the added plugin-origin entries. Preserve schema (name, version, schema, models, context).

### 3.3 Continue CLI compatibility

- Verify in Continue CLI docs or schema whether `provider: openai` with `apiBase` is supported. If not, do not add Council to the CLI config; document that Council is plugin-only. If yes, add Council so the list matches the plugin.

### 3.4 Docs and UX

- Update `docs/developer/continue-cli-setup.md`: state that “continue config” now includes all Ollama models (via API when available) and, when present, Council (and optionally AUTODETECT) from the plugin config so the CLI list matches the plugin where possible.
- In `continue_config()` success message, optionally mention “including Council from plugin config” when Council was merged.

---

## 4. Acceptance

- [ ] `./aixcl continue config` runs without error when Ollama is running and has models.
- [ ] Generated `.continue/cli-ollama.yaml` contains at least every model returned by Ollama (compare with `curl -s http://localhost:11434/api/tags` or `ollama list`).
- [ ] If `.continue/council/config.yaml` exists and contains Council (openai + apiBase), and CLI supports it, the generated CLI config includes a Council entry so “Council (Multi-Model)” appears in the CLI model list.
- [ ] Optional: AUTODETECT from plugin config appears in CLI config when desired.
- [ ] Docs updated to describe the combined list (Ollama + plugin alignment).

---

## 5. Files to Touch

| File | Change |
|------|--------|
| `lib/council_utils.sh` | Optional: add helper to get Ollama model list via API; or keep get_available_models and add API fallback in aixcl. |
| `aixcl` | `continue_config()`: (1) use reliable Ollama list (API first, then ollama list); (2) parse `.continue/council/config.yaml` and merge Council (and optionally AUTODETECT) into generated YAML. |
| `docs/developer/continue-cli-setup.md` | Describe that config includes all Ollama models and aligns with plugin (Council, optional AUTODETECT). |
| `docs/reference/continue-cli-model-list-plan.md` | This plan. |

---

## 6. Risks / Notes

- **Council in CLI:** If the Continue CLI does not support custom openai apiBase, adding Council to the YAML could cause errors or be ignored. Need to confirm CLI schema (or test) before adding.
- **Duplicate names:** Ensure we do not add an Ollama model that already exists under the same name in the plugin; prefer “Ollama list + plugin-only entries” merge strategy.
- **Order:** Emit Ollama models first, then Council, then AUTODETECT (or keep a consistent order documented in the plan).
