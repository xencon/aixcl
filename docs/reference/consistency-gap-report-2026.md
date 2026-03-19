# Consistency Gap Report (March 2026)

This report details the discrepancies found between the documentation, actual functionality, and test coverage for the AIXCL project, based on the **Project Consistency & Coverage Review** plan.

## 1. Documentation vs CLI Drift
The actual CLI implementation in the root `aixcl` script has drifted significantly from earlier documentation and tracking checklists (e.g., `docs/reference/archive/cli-docs-alignment-report.md` and `docs/reference/cli-docs-alignment-checklist.md`).

**Gaps Found:**
- **Removed Commands:** The commands `continue` and `dashboard` were referenced in older documentation and PR checklists but **no longer exist** in the `aixcl` CLI parsing block. They appear to have been deprecated or consolidated.
- **Outdated Checklists:** The `cli-docs-alignment-checklist.md` contains unmerged items (M1: add `continue` command) that are no longer valid for the current architecture.
- **Engine Support:** `docs/user/usage.md` does mention `config engine auto` and `config engine set vllm`, but deep references and manpage entries need to be fully verified against the newest automated engine configurations (e.g., `vllm` and `llamacpp` integration recently added to the `add` model command).

## 2. Test Coverage Gaps
The `tests/platform-tests.sh` is robust, leveraging profiles (`--profile`) and components (`--component`), and iterating over the engines array (`ollama`, `vllm`, `llamacpp`). 

**Gaps Found:**
- **Happy-Path Bias:** The tests primarily check for successful responses (`check-env`, `curl` to endpoints). There is a lack of edge-case testing, such as:
  - Behavior when `.env` is entirely missing or corrupted.
  - Verification of failure states (e.g., what happens if `POSTGRES_PASSWORD` is omitted, simulating the recent bug #523).
- **Security Coverage:** `tests/security/` only contains `test_openwebui_json.sh`. It does not explicitly test that container ports are not inadvertently exposed to the public internet (validating the `network_mode: host` invariant's boundary logic).

## 3. Governance and Invariant Validation
- **Two-Tier Strategy:** The separation of `/ai/governance/` (generic) and `/docs/architecture/` (repository-specific) remains intact.
- **Invariants:** The invariant of `network_mode: host` and the strict requirement of the Core Runtime are respected in the `docker-compose.yml` file.
- **Recent Issues:** Bug #523 highlighted that while the architecture expects seamless service interactions, operational scripts sometimes lack defensive boundaries (e.g., assuming `admin` passwords).

## Action Items
1. **[TASK] Document Cleanup:** Archive `cli-docs-alignment-checklist.md` as it references deprecated commands, and rewrite a fresh checklist based on the current `aixcl --help` output.
2. **[TASK] Expand Test Edge Cases:** Introduce negative testing into `platform-tests.sh` to validate failure recoveries (e.g., database connection drops, invalid environment variables).
3. **[TASK] Security Test Augmentation:** Add automated network binding verification to `tests/security/` to explicitly validate the "local-first" `network_mode: host` invariant and ensure no unauthorized interfaces are exposed.

---
*Generated via automated Project Consistency & Coverage Review.*