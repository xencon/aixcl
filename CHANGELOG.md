# Changelog

All notable changes to the AIXCL project will be documented in this file.

## [Unreleased]

## [v1.1.34] - 2026-06-15

### Summary

Release v1.1.34 -- Platform hardening, CI/CD governance, and profile-service
authoritative sourcing. Fourteen PRs covering runtime fixes, CI pinning,
agentic workflow standards, and expanded unit test coverage.

### Added

- [x] **Agent Identification Block Standard**: `AGENTS.md` Section 9.5 and
  rule mirrors define a required identification block for every agent-authored
  GitHub comment or PR body. Closes #1429.
- [x] **Profile Services from Env Files**: Profile service lists are now
  loaded authoritatively from `config/profiles/*.env` at runtime, replacing
  hard-coded arrays. Fallback lists retained for safety. Closes #1415.
- [x] **Runtime Vault Bootstrap Agent Discovery**: `_get_vault_bootstrap_agents()`
  derives the active bootstrap agent list by intersecting compose-file services
  with the active profile, eliminating the stale hardcoded array and the latent
  bld-profile bug. Explicit PyYAML availability check added. Closes #1421.
- [x] **Stack Helper Unit Tests**: `tests/lib/tests/test-03-stack-helpers.sh`
  adds 13 assertions for `_print_stopped_status` and
  `_load_vault_token_for_stack` (env-var shortcut and missing-file paths).
  Closes #1417 step 1.
- [x] **Lib Tests in CI**: `quick-tests.yml` now runs the lib test category
  on every push to dev, catching profile and helper regressions early.
  Closes #1414.
- [x] **Workflow Concurrency Controls**: All GitHub Actions workflows gain
  `concurrency` groups and timeout-minutes limits, preventing queue pile-ups
  on rapid pushes. Closes #1426.
- [x] **check-ai-elisions in CI**: `bash-ci.yml` runs
  `check-ai-elisions.sh --range` on every PR to detect AI-elision placeholders
  before merge. Rule mirrors updated. Closes #1428.

### Fixed

- [x] **Vault Image Version**: `stack.sh` five manual vault run commands now
  use `vault:2.0.2` matching `docker-compose.yml`, removing the version skew
  introduced by the default `vault:1.18` tag. Closes #1423.
- [x] **Hardcoded Podman Calls**: `vault-status.sh` `is_container_running`
  replaced with inline `${DOCKER_BIN:-docker} ps` so the runtime honours the
  podman/docker detection already in place. Closes #1423.
- [x] **GPU Overlay Entrypoints**: `services/docker-compose.gpu.yml` ollama
  and vllm inline entrypoints now match their primary scripts
  (`ollama-entrypoint.sh`, `vllm-entrypoint.sh`). PARITY REQUIREMENT comments
  added. Closes #1416.
- [x] **App Parser eval Removed**: `_app_load_manifest` and
  `_app_load_manifest_from_path` replace `eval "$exports"` with
  `bash -c "$exports"` indirect expansion, removing an injection vector.
  Closes #1420.
- [x] **Release Changelog Parser**: `release.yml` parser now handles standard
  markdown headings (`### Added`, `### Fixed`) in addition to the old format.
  Closes #1425.
- [x] **Stale Volume References**: `docker-compose.secrets.yml` references to
  removed named volumes cleaned up. Closes #1427.
- [x] **Vault Bootstrap Status Labels**: Case statement added for Open WebUI
  and pgAdmin so status display shows correct mixed-case labels instead of
  awk-titlecased "Openwebui" / "Pgadmin". Closes #1421.

### Changed

- [x] **Actions Pinned to SHA**: All third-party GitHub Actions in
  `ci.yml`, `bash-ci.yml`, `security.yml`, `documentation-checks.yml`, and
  `quick-tests.yml` pinned to commit SHAs with version comments. Closes #1413,
  #1445.

### Maintenance

- [x] **Remove Stale Draft Agents and Security README**: Outdated draft agent
  files and a superseded `.claude/security-README.md` removed. Closes #1411.
- [x] **Remove Stale Agent Refs**: Non-existent agent names removed from
  `docs/architecture/governance/compensating-controls.md`. Closes #1442.
- [x] **Move AIXCL.png**: Repository root `AIXCL.png` moved to
  `docs/assets/AIXCL.png`; all references updated. Closes #1419.
- [x] **Update Tests README**: `tests/README.md` updated to match the actual
  test suite structure, categories, and helper functions. Closes #1410.
- [x] **Remove Duplicate wait_for_api**: Duplicate function definition in
  `tests/lib/test-framework.sh` removed. Closes #1418.
- [x] **ASCII CI Output**: Unicode checkmark in `bash-ci.yml` step summary
  replaced with `[PASS]` for cross-platform compatibility. Closes #1424.

## [v1.1.33] - 2026-06-15

### Summary

Release v1.1.33 -- Two bug fixes: Prometheus scrape target generation for
externally registered apps, and Unicode icon output in app build.

### Fixed

- [x] **Prometheus Target for External Apps**: `_app_generate_prometheus_targets`
  now uses `_app_resolve_dir` (same as the sibling `_app_wire_grafana`) so
  `prometheus/file_sd/<app>.json` is correctly written when starting an
  externally registered app. Previously all observations went missing from
  Grafana dashboards. Closes #1402.
- [x] **App Build Icon Output**: `app_cmd_build` hardcoded `[x]` / `[ ]`
  instead of `${ICON_SUCCESS:-[x]}` / `${ICON_ERROR:-[ ]}`. Build success and
  failure now display Unicode glyphs on UTF-8 terminals with ASCII fallback.
  Closes #1404.

## [v1.1.32] - 2026-06-15

### Summary

Release v1.1.32 -- Bash completion extended to cover registered external apps for all app subcommands.

### Added

- [x] **External App Completion**: `_aixcl_app_names()` helper reads both built-in `apps/*/app.yaml` and `~/.config/aixcl/registry` (externally registered apps). All app subcommands (`start`, `stop`, `restart`, `status`, `build`, `remove`, `secrets`, `provision`, `unregister`) now complete registered external app names. Closes #1396.

### Fixed

- [x] **Completion for app remove**: `./aixcl app remove <TAB>` now suggests app names (both built-in and registered external). Previously the `remove` case had no completion handler, leaving both built-in and external apps invisible. Closes #1396.
- [x] **Completion for app secrets/provision**: `./aixcl app secrets <TAB>` and `./aixcl app provision <TAB>` now suggest app names. Closes #1396.
- [x] **Completion for app register/unregister**: `./aixcl app register <TAB>` now suggests directories; `./aixcl app unregister <TAB>` suggests registered app names. Closes #1396.

## [v1.1.31] - 2026-06-14

### Summary

Release v1.1.31 -- Fix for Loki container healthcheck failing on distroless image.

### Fixed

- [x] **Loki Container Healthcheck**: Removed broken `wget`-based healthcheck from the Loki service in `services/docker-compose.yml`. The Loki 3.7.2 image is distroless and contains no shell, wget, or curl. The healthcheck was permanently failing (exit 127), causing Loki to show as unhealthy in podman and as a warning in stack status despite serving requests normally. Stack status already performs an external curl check against `http://127.0.0.1:3100/ready` which correctly reflects Loki readiness. Closes #1384.

## [v1.1.30] - 2026-06-14

### Summary

Release v1.1.30 -- Bug fixes for vault cold start failure and misleading bootstrap container status display, with regression tests for both.

### Fixed

- [x] **Cold Start VAULT_TOKEN Bug**: `_load_vault_token_for_stack` now accepts `--force`, bypassing the env-var early-return on the post-init path. A stale `VAULT_TOKEN` in the shell no longer poisons bootstrap containers after a cold vault init, which previously caused all vault-dependent services to fail to start. Closes #1376.
- [x] **Bootstrap Container Status Display**: `check_service_status` gains a `one-shot` health_check_type that treats containers exited with code 0 as healthy (shown as `complete`). The four `vault-agent-*-bootstrap` entries now use this type, fixing the misleading `15/19 healthy` count on a fully healthy stack. Closes #1377.

### Tests

- [x] **test-00a-stack-token-reload.sh**: Three assertions covering the `--force` flag behaviour -- env var preserved without `--force`, bypass confirmed with `--force`, disk token loaded when GPG available. Closes #1376.
- [x] **test-02-stack-status.sh**: Extended with six assertions -- each bootstrap container must show healthy with `(complete)` annotation, and total healthy count must equal total service count. Closes #1377.

## [v1.1.29] - 2026-06-14

### Summary

Release v1.1.29 -- Agent intelligence package for agentic navigation.

### Added

- [x] **Agent Cold Start Sequence**: `AGENTS.md` section 0 defines exactly four files to read in order for full orientation, eliminating the previous 5-hop document chain. Closes #1371.
- [x] **Fork Workflow Documentation**: `AGENTS.md` and `agent-context.md` now document the two-remote setup (`origin` = upstream, `fork` = personal) and SSH requirement, preventing the push failures that affected previous agent sessions. Closes #1371.
- [x] **12 CONTEXT.md Files**: High-traffic directories now have agent-readable index files covering purpose, key behavioural notes, agent guidance, and cross-references. Directories covered: `lib/aixcl/commands/`, `lib/core/`, `lib/cli/`, `scripts/checks/`, `scripts/vault/`, `scripts/runtime/`, `scripts/security/`, `services/`, `vault/agent-config/`, `tests/command-tests/`, `.claude/rules/`, `etc/app-scaffold/`. Closes #1371.
- [x] **5 Architectural Decision Records**: `docs/architecture/decisions/` documents the five decisions agents repeatedly question or revert: `network_mode: host` (001), one-shot bootstrap containers (002), `VAULT_TOKEN` escape hatch (003), topological sort for `depends_on` (004), and Python3 for YAML parsing (005). Closes #1371.
- [x] **Service Map**: `docs/reference/service-map.md` provides a single table of all 21 platform services with profile membership, port, entrypoint, and health check -- replacing the need to parse `docker-compose.yml` for an overview. Closes #1371.
- [x] **add-service Skill**: `.claude/skills/add-service/SKILL.md` (and `.opencode` mirror) provides a 9-step guided checklist for adding a platform service while preserving all invariants. Closes #1371.
- [x] **cut-release Skill**: `.claude/skills/cut-release/SKILL.md` (and `.opencode` mirror) encodes the full release workflow with dynamic version computation. Closes #1371.
- [x] **Agent Pitfalls Guide**: `docs/developer/agent-pitfalls.md` documents 12 common agent mistakes with corrections -- covering workflow, architecture, vault, and versioning errors. Closes #1371.

### Changed

- [x] **docker-compose.yml Invariant Comment**: Header comment block explicitly states that `network_mode: host` and `restart: on-failure` on bootstrap containers are intentional invariants, with ADR references, to stop repeated reviewer questions. Closes #1371.
- [x] **agent-context.md Extended**: `.opencode/agents/agent-context.md` gains the cold-start sequence, fork remote table, elision check reminder, and references to new ADRs and skills -- while retaining the full context OpenCode agents require. Closes #1371.

### Fixed

- [x] **check-agents.sh Arithmetic Bug**: `((WARNINGS++))` caused the script to exit on the first warning under `set -e` (arithmetic expression evaluating to 0 is falsy in bash). Changed to `WARNINGS=$((WARNINGS + 1))` so warnings accumulate correctly and only errors cause non-zero exit. Closes #1371.

## [v1.1.28] - 2026-06-13

### Summary

Release v1.1.28 -- App CLI robustness, vault bootstrap security hardening, and developer documentation improvements.

### Added

- [x] **Manifest depends_on Ordering**: `app start` now performs a topological sort of manifest services and starts dependencies first, honoring health checks before starting dependents. Platform services named in `depends_on` (e.g. `ollama`) are verified running; unresolvable names and cycles fail with actionable errors. Closes #1332.
- [x] **Compose Diagnostics on Failure**: A failing `app start` or build-on-start now dumps the raw compose output to stderr. New `--verbose` flag on `app start` shows full compose and build output on success too. Closes #1337.
- [x] **GPG Signature CI Report**: New `commit-signature-check.yml` workflow reports unsigned or unverified commits pushed to `main` or `dev` as non-blocking `::warning::` annotations. Enforcement remains maintainer discipline per DEVELOPMENT.md. Closes #1347.

### Changed

- [x] **Vault Bootstrap Agents -- One-Shot**: All four `vault-agent-*-bootstrap` containers converted from `restart: unless-stopped` with an infinite polling loop to `restart: on-failure` one-shot containers. Bootstrap scripts exit 0 after a successful secret write; Docker retries only on genuine failure. Root token is no longer held in a long-running container environment after stack startup. Closes #1338.

### Fixed

- [x] **Stale Manifest Variables**: `_app_load_manifest` now clears all `APP_*` variables before applying a new manifest's exports. Previously, loading a second manifest in the same process left stale list entries (services, secrets) from the first, corrupting `_app_service_count` and service iteration. Closes #1341.
- [x] **Missing TTY for Vault Token Decrypt**: `_load_vault_token_for_stack` short-circuits when `VAULT_TOKEN` is already set (CI/agent escape hatch). On decrypt failure without a TTY, it now prints actionable options (`export VAULT_TOKEN`, `gpg --pinentry-mode loopback`) instead of a hint that cannot work without a terminal. Also fixed a latent bug where `GPG_TTY` was being set to the literal string `not a tty` in non-interactive sessions. Closes #1339.
- [x] **Silent Build Skip**: Both `app build` and the build-on-start path now warn when a service declares build configuration (`build_context`) but `built: true` is not set, explaining how to enable the build. Closes #1340.

### Documentation

- [x] **cap_drop: ALL Crash-Loop Pattern**: Added "Hardened images and cap_drop: ALL" subsection to `docs/developer/adding-apps.md` documenting the failure mode (official images chown data dirs as root on every startup; fails under `cap_drop: ALL` after first boot), the fix (`user: "UID:GID"`), and how to find the correct UID. Closes #1342.
- [x] **depends_on Field Semantics**: Updated `docs/developer/adding-apps.md` to document the actual implemented semantics for `depends_on` (ordering, platform service check, error on unresolvable, cycle detection).

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

## [v1.1.27] - 2026-06-13

### Summary

Release v1.1.27 -- Declarative app provisioning contract for BYO apps, governance consistency fixes, and AI elision guard.


### Added

- [x] **App Provisioning Contract**: New declarative `provision:` block in `app.yaml`. The platform idempotently seeds Vault secrets under `kv/apps/<name>`, renders them to a per-app secrets volume, and creates the PostgreSQL role and database. New `./aixcl app provision` and `./aixcl app secrets` subcommands; scaffold template includes a commented provision block. (Fixes #1331)
- [x] **App Healthcheck Dispatcher**: `http`, `cmd`, and `container_running` healthcheck types declared in `app.yaml` are now honored by app status reporting. (Fixes #1336)
- [x] **AI Elision Guard**: New `scripts/checks/check-ai-elisions.sh` detects placeholder text standing in for preserved content and suspicious mass deletions; enforced in CI on every PR and documented in the pre-commit checklist. (Fixes #1346)
- [x] **Rules and Skills Mirror Parity Check**: `check-agents.sh` now verifies `.claude/` and `.opencode/` rules and skills directories are byte-identical. (Fixes #1348)
- [x] **Fork Workflow Documentation**: New DEVELOPMENT.md section covering fork remotes, local-only overrides, upstream defect capture, and pre-upstream scrub checklist. (Fixes #1349)

### Changed

- [x] **Per-App Secret Isolation**: Apps no longer mount the shared platform secrets volume; each app receives its own `aixcl-app-<name>-secrets` volume rendered by the platform. Apps never hold Vault tokens. (Fixes #1333)
- [x] **App and Platform Demarcation**: Removed app-specific bootstrap scripts, Vault agent config, and Prometheus metrics-path hardcoding from platform files; app metrics paths are declared in `app.yaml` and emitted as `__metrics_path__`. (Fixes #1334, #1335)
- [x] **Escalation Policy Consolidated**: DEVELOPMENT.md escalation defers to AGENTS.md Section 7; agents do not create issues unilaterally. (Fixes #1344)
- [x] **Label Taxonomy Canonicalized**: DEVELOPMENT.md and issue templates aligned to the canonical AGENTS.md taxonomy (Bug/Feature/Task plus required component labels). (Fixes #1343)
- [x] **Governance Drift Fixes**: ASCII rule scoped to git/CI/web artifacts with Unicode-with-fallback allowance for terminal output; workflow-guard skill corrected; issue templates carry canonical labels. (Fixes #1350)

### Fixed

- [x] **Static Compliance Self-Attestation Removed**: Deleted `GOVERNANCE_COMPLIANCE.md`; compliance is now enforced mechanically by CI checks instead of asserted in a document. (Fixes #1345)
- [x] **Trailing Blank Lines in alerts.yml**: Removed trailing blank lines that failed repo-wide yamllint on every PR. (Fixes #1353)

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

## [v1.1.26] - 2026-06-10

### Summary

Release v1.1.26 -- Documentation overhaul, CLI alignment, and username leak remediation.

### Added

- [x] **App Framework User Guide**: Created `docs/user/apps.md` for the BYO application framework. (Fixes #1323)
- [x] **Threat Model Document**: Created `docs/security/threat-model.md` covering threat actors, attack vectors, MITRE ATT&CK mapping, and compensating control cross-references. (Fixes #1323)

### Changed

- [x] **CLI Help Alignment**: Added missing `vault` command with all 10 subcommands to `help_menu()`. Renamed `utils clean` to `utils prune` and added `prune --all`. (Fixes #1323)
- [x] **AGENTS.md Section Numbering**: Fixed broken numbering (now sequential 1-11). (Fixes #1323)
- [x] **DEVELOPMENT.md Version Reference**: Corrected "AGENTS.md v1.5" to "AGENTS.md v2.0" and fixed Section 8 reference for Emergency Workflow Override. (Fixes #1323)
- [x] **Unicode to ASCII Conversion**: Replaced all [x]/[ ]/[!]/In Progress/Future Unicode symbols with markdown checkboxes or plain text across SECURITY.md, modes, and operations docs. (Fixes #1323)

### Fixed

- [x] **README Step Numbering**: Corrected broken Step 4/5 ordering in Quick Start. (Fixes #1323)
- [x] **Stale Command References**: Replaced non-existent `aixcl-setup` with `./aixcl stack init`, fixed `vault passwords` to `vault credentials`, and removed non-existent `aixcl security` command references. (Fixes #1323)
- [x] **Manifest Example**: Fixed `docs/developer/adding-apps.md` YAML example to match actual `app_parser.sh` flat key format and corrected Prometheus file_sd path. (Fixes #1323)
- [x] **Profile Docs**: Added missing Alertmanager to bld/sys profile service lists and corrected nvidia-gpu-exporter port from 9400 to 9445. (Fixes #1323)
- [x] **Username Leakage**: Removed hardcoded `sbadakhc` references from SECURITY.md, CONTRIBUTING.md, and script usage examples. (Fixes #1323)

### Verification

- [x] CHANGELOG updated
- [ ] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

## [v1.1.25] - 2026-06-10

### Summary

Release v1.1.25 -- Major version bumps for Ollama, Vault, PostgreSQL, Grafana, Alertmanager, Loki, and cAdvisor.

### Changed

- [x] **Ollama 0.30.7**: Bumped inference engine from 0.20.5 to 0.30.7. (Fixes #1314)
- [x] **Vault 2.0.2**: Bumped secret management from 1.18 to 2.0.2. (Fixes #1314)
- [x] **PostgreSQL 18.4**: Bumped database from 17.9 to 18.4 with updated mount path (`/var/lib/postgresql` per 18+ Docker image requirement). (Fixes #1314)
- [x] **Grafana 13.0.2**: Bumped observability UI from 12.4.2 to 13.0.2. (Fixes #1314)
- [x] **Alertmanager v0.32.2**: Bumped alerting from v0.28.0 to v0.32.2. (Fixes #1314)
- [x] **Loki 3.7.2**: Bumped log aggregation from 3.3.0 to 3.7.2. (Fixes #1314)
- [x] **cAdvisor v0.55.1**: Attempted bump to v0.57.0 (not available on GCR); reverted to v0.55.1. (Fixes #1314)

### Added

- [x] **Prometheus v3.12.0**: Bumped metrics collection from v3.11.1. (Fixes #1313)
- [x] **Open WebUI v0.9.6**: Bumped web interface from v0.9.5. (Fixes #1313)
- [x] **NVIDIA GPU Exporter 1.4.1**: Bumped GPU metrics from 1.3.2. (Fixes #1313)
- [x] **vLLM v0.22.1**: Bumped inference engine alternative from v0.19.0 (version-only, pull_policy: missing). (Fixes #1313)
- [x] **Llama.cpp b9585**: Bumped inference engine alternative from b8334 (version-only, pull_policy: missing). (Fixes #1313)

### Fixed

- [x] **PostgreSQL 18 Mount Path**: Changed volume mount from `/var/lib/postgresql/data` to `/var/lib/postgresql` to satisfy PostgreSQL 18+ Docker image layout requirements. (Fixes #1315)

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

---

### Summary

Release v1.1.24 -- Vault bootstrap reliability, multi-agent CLI support, and agent governance consolidation.

### Added

- [x] **Multi-Agent CLI Support**: Created `.claude/` directory with Claude Code compatibility files (`CLAUDE.md`, rules, skills, commands, settings). Documented multi-agent CLI support (OpenCode + Claude Code) in docs/README.md. (Fixes #1291, #1299)

### Changed

- [x] **AGENTS.md Consolidation**: Refactored `AGENTS.md` from ~350 lines to ~207 lines, removing redundant content and consolidating the canonical agent operating contract. (Fixes #1300)

### Fixed

- [x] **Vault Bootstrap Reliability**: Fixed Vault init and stack start reliability issues, resolving race conditions between Vault initialization, bootstrap agents, and PostgreSQL startup. (Fixes #1289, #1290)
- [x] **Deprecated Profile References**: Removed stale references to deprecated `usr` and `dev` profiles from `docs/developer/adding-services.md`. (Fixes #1298)
- [x] **Workflow Guard Skill**: Corrected dead references to `workflow-governance.md` in `.opencode/skills/workflow-guard/SKILL.md`. (Fixes #1297)

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

---

## [v1.1.23] - 2026-06-08

### Summary

Release v1.1.23 -- Vault bootstrap reliability improvements, Podman auto-configuration, Vault agent token refresh, and CI/test fixes.

### Added

- [x] **Podman Auto-Configuration**: `stack init` now auto-configures Podman, alias, `DOCKER_HOST`, and volumes. Improves out-of-the-box experience for Podman users. (Fixes #1277)

### Changed

- [x] **Vault Unseal Documentation**: Documented Vault unseal requirement after stack restart in README.md and QUICKSTART.md. (Fixes #1248)

### Fixed

- [x] **Vault Bootstrap Reliability**: Fixed Vault init and stack start reliability issues, resolving race conditions between Vault initialization, bootstrap agents, and PostgreSQL startup. (Fixes #1289, #1290)
- [x] **Vault Agent Anonymous Volumes**: Fixed anonymous volumes from Vault agent containers and token refresh. (Fixes #1276, #1288)
- [x] **Engine Detection**: `is_vault_running()` now uses `DOCKER_BIN` or active engine detection for container engine portability. (Fixes #1275)
- [x] **Compose Pull Optimization**: `run_compose pull` now passes profile services to avoid pulling all images. (Fixes #1274)
- [x] **Email Defaults**: Corrected `admin@localhost` to `admin@example.com` in security test for first-start compatibility. (Fixes #1278)
- [x] **CI Compliance Rules**: Added CI compliance rules for agents and contributors. (Fixes #1278)
- [x] **ShellCheck**: Added ShellCheck version check and installation instructions. (Fixes #1281)
- [x] **JSON Escaping Test**: Fixed JSON escaping validation in security test using subprocess capture and Python verification. (Fixes #1278)

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

---

## [v1.1.21] - 2026-05-19

### Summary

Release v1.1.21 -- Podman rootless compatibility, Vault credential isolation, service startup resilience, and fork workflow documentation.

### Added

- [x] **Fork Sync Workflow Documentation**: Added upstream remote setup, branch sync, and rebase instructions to CONTRIBUTING.md for external contributors. (Fixes #1246)

### Changed

- [x] **Email Defaults**: Reverted all service email defaults from localhost and test domains to `admin@example.com` for first-start compatibility. Affects init-secrets.sh, README.md, CI workflows. (Fixes #1243)
- [x] **Localhost Refactor**: Replaced `aixcl.local` references with `localhost` across docs, tests, and config for consistency. (Fixes #1245)

### Fixed

- [x] **Podman Autodetect**: Added `set_compose_cmd()` call to `status()` in stack.sh, mirroring start/stop/restart behavior. Fixes Docker socket errors on Podman-only systems. (Fixes #1242)
- [x] **Podman Rootless Compatibility**: Added rootless directory setup, GPG_TTY handling, and token decrypt fixes for Podman environments. (Fixes #1242)
- [x] **Vault Credential Isolation**: Bootstrap agents now write both password and email secrets from Vault KV to `/run/secrets/`, removing sensitive identity from `.env`. Fixes rootless restart loops. (Fixes #1242)
- [x] **Grafana/pgAdmin Startup Race**: Added 60-second wait-and-retry loops for Vault bootstrap secrets, preventing fail-fast exits on fresh deployments. (Fixes #1244)
- [x] **POSIX Compliance**: Replaced `local` keyword with underscore-prefixed variables in bootstrap-password scripts to satisfy ShellCheck SC3043. (Fixes #1242)
- [x] **Loki Documentation**: Clarified in README that Loki has no web UI and Grafana should be used for log browsing.

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

## [v1.1.20] - 2026-05-14

### Summary

Release v1.1.20 -- follow-up to v1.1.19, includes the vault-status.sh hotfix that was merged to main and dev after v1.1.19 was tagged.

### Fixed

- [x] **Vault Status Unknown State**: Fixed `check_vault_health()` in `lib/aixcl/commands/vault-status.sh` to correctly parse `"sealed": false` from Vault health API. Same jq `//` false handling bug as #1229, but in a different file. Also fixed false "[!] Vault needs initialization" warning caused by `check_credentials()` returning 1 when no generated credential files were present yet. (Fixes #1234, #1235)

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

---

## [v1.1.19] - 2026-05-14

### Summary

Release v1.1.19 -- critical Vault bug fix, merge conflict prevention, and House Keeping workflow hardening.

### Fixed

- [x] **Vault jq False Handling**: Fixed `vault_status()` in `scripts/vault/vault-commands.sh` to correctly parse `"sealed": false` from Vault health API. jq's `//` operator treats JSON `false` as falsy, causing all password/credential commands to silently exit with empty output. Changed query to use `has("sealed")` with explicit boolean stringification. (Fixes #1229)
- [x] **CHANGELOG Conflict Markers**: Removed git conflict markers (`<<<<<<< HEAD`, `=======`, `>>>>>>> origin/main`) accidentally committed during v1.1.18 dev->main promotion PR. (Fixes #1224)
- [x] **Stack Status Under-reporting**: Fixed `lib/aixcl/commands/stack.sh` to include missing Alertmanager and 6x Vault Agent sidecars in `stack status` output. Status now correctly reports all 19 services for the `sys` profile. (Fixes #1219)
- [x] **Body Pre-population Rule Accuracy**: Corrected AGENTS.md to state that `create-issue.sh` does not support `--body-file` and that raw `gh issue create --body-file` should be used for pre-populated issues. (Fixes #1217)

### Changed

- [x] **House Keeping Section**: Added Section 11 to AGENTS.md with release metadata standardization, RC naming conventions, body pre-population rules, merge conflict prevention, and "Do Not Close Issues That PRs Will Auto-Close" rule. (Fixes #1215, #1226, #1227, #1228)
- [x] **Release Template Standardization**: Updated `.github/RELEASE_TEMPLATE.md` to v3.0 with standard categories (Added, Changed, Fixed, Removed), removed redundant Installation block, and updated link paths. Release workflow now enforces `AIXCL vX.Y.Z` title format. (Fixes #1213)
- [x] **AGENTS.md Version**: Bumped from 1.5 to 1.6, last_updated to 2026-05-14. (Fixes #1215)

### Related Issues

- [x] Fixes #1213 - Remove redundant installation block from release template
- [x] Fixes #1215 - Add House Keeping section to AGENTS.md
- [x] Fixes #1217 - Correct Body Pre-population Rule in AGENTS.md
- [x] Fixes #1219 - Stack status under-reports services and restart has dependency conflicts
- [x] Fixes #1224 - Add merge conflict prevention to AGENTS.md
- [x] Fixes #1229 - vault_passwords and vault_credentials return empty output

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [ ] All CI checks passing on main
- [ ] Release signed and published

---

## [v1.1.18] - 2026-05-14

### Summary

Release v1.1.18 -- stack status reporting fix, AGENTS.md housekeeping, and release template standardization.

### Added

- [x] **House Keeping Section**: Added Section 11 to AGENTS.md with release metadata standardization, RC naming conventions, release template compliance checklist, and clean house verification. (Fixes #1215)
- [x] **Stack Status Services**: Expanded `stack status` to report all 19 services for `sys` profile, including Alertmanager and 6x Vault Agent sidecars. (Fixes #1219)

### Changed

- [x] **AGENTS.md Version**: Bumped from 1.5 to 1.6, last_updated to 2026-05-14. (Fixes #1215)

### Fixed

- [x] **Body Pre-population Rule**: Corrected AGENTS.md to accurately state that `create-issue.sh` does not support custom body files. Directs to `gh issue create --body-file` for pre-populated items. (Fixes #1217)
- [x] **Stack Status Under-reporting**: Fixed `lib/aixcl/commands/stack.sh` to include missing Alertmanager and vault agent checks. (Fixes #1219)

### Related Issues

- [x] Fixes #1215 - Add House Keeping section to AGENTS.md
- [x] Fixes #1217 - Correct Body Pre-population Rule in AGENTS.md
- [x] Fixes #1219 - Stack status under-reports services and restart has dependency conflicts

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [x] All CI checks passing on main
- [x] Release signed and published

---

## [v1.1.17] - 2026-05-13

### Summary

Release v1.1.17 -- pgAdmin version bump, release workflow fixes, and changelog policy documentation.

### Added

- [x] **Changelog Update-at-Release Policy**: Documented in `development-workflow.md` that CHANGELOG updates happen at release time, not merge time. The `[Unreleased]` section is a placeholder; individual PRs must not edit CHANGELOG.md. (Fixes #1208)

### Fixed

- [x] **Release Changelog Extraction**: Fixed release workflow `awk` regex to use `index()` literal matching for version headers, preventing bracket interpretation issues. (Fixes #1204)

### Changed

- [x] **pgAdmin Upgrade**: Bumped pgAdmin from 9.14.0 to 9.15.0 in `services/docker-compose.yml`. (Fixes #1206)

### Related Issues

- [x] Fixes #1204 - Fix release workflow changelog extraction
- [x] Fixes #1206 - Bump pgAdmin to 9.15.0
- [x] Fixes #1208 - Document CHANGELOG update at release time policy

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [x] All CI checks passing on main
- [x] Release signed and published

---

## [v1.1.16] - 2026-05-13

### Summary

Release v1.1.16 -- Open WebUI update, rootless Podman verification, and workflow documentation hardening.

### Added

- [x] **Rootless Podman Verification**: `./aixcl utils check-env` now automatically displays the Podman rootless status during environment checks, mirroring the manual verification step in README.md. (Fixes #1181)
- [x] **Emergency Workflow Override Protocol**: Documented explicit authorization mechanism for proceeding without a pre-existing issue. Requires human operator instruction, retroactive documentation, and `[OVERRIDE]` commit prefix. (Fixes #1193)
- [x] **Human in the Loop Policy**: Formalized that Agent fills `[x]` for agent-completed checklist items, while human fills `[x]` for manual verification items. The checklist serves as a gate, not passive decoration. (Fixes #1193)

### Changed

- [x] **Open WebUI Upgrade**: Bumped Open WebUI from v0.9.4 to v0.9.5 in `services/docker-compose.yml`. (Fixes #1185)
- [x] **Agent Terminology**: Replaced "AI" with "Agent" across all workflow documentation for clarity and precision. (Fixes #1193)
- [x] **Wrapper Scripts as Standard**: Elevated `create-issue.sh` and `create-pr.sh` from "recommended" to canonical usage in workflow documentation. (Fixes #1193)

### Fixed

- [x] **Dead Code Removal**: Removed the unused `PROFILE_SERVICES` associative array from `lib/cli/profile.sh`. (Fixes #1179)

### Removed

- [x] **`.ai-context/` from `.gitignore`**: Removed exclusion for `.ai-context/` directory. All agent work goes to `/tmp` to prevent repository noise. (Fixes #1193)

### Related Issues

- [x] Fixes #1179 - Remove dead PROFILE_SERVICES associative array
- [x] Fixes #1181 - Add rootless Podman verification to check-env
- [x] Fixes #1185 - Bump Open WebUI to v0.9.5
- [x] Fixes #1189 - Update README for automatic rootless verification
- [x] Fixes #1193 - Update workflow documentation for Human in the Loop model

### Verification

- [x] CHANGELOG updated
- [x] All CI checks passing on dev
- [x] All CI checks passing on main
- [x] Documentation updated
- [x] Workflow templates updated

---

### Summary

Release v1.1.15 -- Vault production mode hardening, health check fixes, and documentation corrections.

### Security

- [x] **Vault Production Mode**: Migrated Vault from dev mode to production mode with proper initialization, unseal keys, and GPG-encrypted root token storage. (Fixes #1159)

### Fixed

- [x] **Vault Init Hardening**: Hardened Vault initialization script to correctly create database engine roles, policies, and AppRole authentication. Fixed health checks and agent token provisioning. (Fixes #1170)
- [x] **GPG Terminal Setup**: Corrected SECURITY.md factual errors regarding security posture documentation. (Fixes #1157)

### Changed

- [x] **OpenCode Configuration**: Added `opencode.json` to `.gitignore` and shipped a vanilla configuration template to prevent accidental commits of personal settings. (Fixes #1154)

### Related Issues

- [x] Fixes #1154 - Gitignore opencode.json and ship vanilla config template
- [x] Fixes #1157 - Correct factual errors in SECURITY.md posture documentation
- [x] Fixes #1159 - Migrate Vault from dev mode to production mode
- [x] Fixes #1170 - Fix Vault init not creating database engine roles policies or AppRole auth

---

## [v1.1.14] - 2026-05-11

### Fixed

- **vault_status jq false/unreachable bug**: `vault_status` used `.sealed // "unreachable"` which always evaluated to `"unreachable"` when Vault was unsealed (jq treats `false` as falsy in the `//` alternative operator). This silently caused `vault passwords` and `vault credentials` to exit without output. Fixed by replacing `//` with `if has("sealed") then (.sealed | tostring) else "unreachable" end`. (Fixes #1159)

### Related Issues

- [x] Fixes #1159 - vault_status jq treats false as unreachable

---

## [v1.1.13] - 2026-05-11

### Security

- [x] **Vault Production Mode**: Migrated Vault from ephemeral dev mode to production file-storage backend with persistent secrets across restarts. Unseal keys (5-of-5, threshold 3) and root token are GPG-encrypted and stored in `.security/` (gitignored). Stack start auto-unseals using the operator's GPG key. (Fixes #1159)
- **Dynamic Credential Revocation Hardening**: Vault database roles now include `revocation_statements` (`REASSIGN OWNED BY`, `DROP OWNED BY`, `DROP ROLE`) preventing SQLSTATE 2BP01 shutdown loops when dynamic roles own PostgreSQL objects. (Fixes #1159)
- **Postgres Connection Config Sync**: Vault database engine always re-POSTs the current PostgreSQL password on init, preventing authentication failures after password changes. Previously skipped if config already existed. (Fixes #1159)

### Fixed

- **Bootstrap Agent Cascade Seal**: Bootstrap agent refresh no longer seals Vault via `depends_on` restart cascade -- `--no-deps` flag added to agent recreate. (Fixes #1159)
- **Shell Script Execute Bits**: Restored execute permissions on `vault-init.sh`, `completion/aixcl.bash`, and all runtime shell scripts stripped by editor tooling. (Fixes #1159)

### Changed

- **Bash Autocomplete**: Added missing vault subcommands (`start`, `stop`, `restart`, `unseal`, `logs`) to `completion/aixcl.bash`. (Fixes #1159)

### Related Issues

- [x] Fixes #1159 - Vault production mode

---

## [v1.1.12] - 2026-05-10

### Removed

- **Dead Script Cleanup**: Deleted `scripts/setup-rootless-env.sh` (duplicate of `setup-podman-rootless.sh` with bugs), `scripts/runtime/openwebui-v2.sh` (unreferenced), and `scripts/runtime/openwebui.sh` (mounted but never executed). Removed dead volume mount from `docker-compose.yml`. Rewrote `scripts/README.md` to reflect actual directory structure. (Fixes #1144)

### Fixed

- **Shell Script Bugs**: Removed macOS `sed -i ''` dead code from `stack.sh`; fixed profile display bug in `get_profile_services`; corrected startup message; added missing services to `ALL_SERVICES` in `common.sh` (`vault-agent-postgres`, `vault-agent-openwebui`, `vault-agent-grafana-bootstrap`, `alertmanager`); removed leading whitespace from function definitions; removed premature `COMPOSE_CMD` initialisation before `set_compose_cmd()` runs; removed deprecated `config` command from bash completion. (Fixes #1145)

### Changed

- **Duplicate Logic Elimination**: Extracted triplicated stopped-status output block in `stack.sh` into `_print_stopped_status()` helper. Extracted duplicated `opencode.json` model-clearing block in `engine.sh` into `_clear_opencode_model()` helper. (Fixes #1146)

### Related Issues

- Fixes #1144 - Dead script removal
- Fixes #1145 - Shell script bugs
- Fixes #1146 - Duplicate logic elimination

---

## [v1.1.11] - 2026-05-10

### Added

- **check-ascii-markdown CI Job**: New CI job blocks non-ASCII Unicode punctuation (em dashes, smart quotes, non-breaking spaces) in markdown files. Replaced all such characters with ASCII equivalents across 16 files. (Fixes #1127)

### Fixed

- **CI Workflow Hardening**: Replaced non-existent `actions/checkout@v6` with `@v4` across all 7 workflow files; added `.yamllint.yml` config making YAML validation blocking; removed duplicate `check-env` and `check-line-endings` jobs from `integration-tests.yml`; fixed `./aixcl --help` to `./aixcl help` in `quick-tests.yml`. (Fixes #1143)
- **Vault Image Short-Name Resolution**: Qualified all Vault image references with `docker.io/hashicorp/vault:1.18` to fix pull failure after `prune --all`. (Fixes #1140)
- **prune --all Reliability**: Added `stack stop` before force-removing containers in `prune --all` to prevent orphaned volumes. Added `PURGE` confirmation prompt with clear summary of destructive actions. Fixed bash completion script path after `prune --all` restores pre-install state. (Fixes #1133, #1130)

### Changed

- **Quick Start Reordering**: Moved bash completion install into Quick Start Step 2 alongside shell reload and renumbered subsequent steps. (Fixes #1136)

### Related Issues

- Fixes #1127 - check-ascii-markdown CI job
- Fixes #1130 - prune --all state restoration
- Fixes #1133 - prune --all orphaned volumes
- Fixes #1136 - bash completion Quick Start placement
- Fixes #1140 - vault image short-name resolution
- Fixes #1143 - CI workflow audit

---

## [v1.1.10] - 2026-05-09

### Added

- **NVIDIA CDI Auto-Configuration on Stack Start**: `stack start` now automatically generates the NVIDIA CDI spec if NVIDIA hardware and `nvidia-ctk` are present but no CDI devices are registered. Tries `/etc/cdi/nvidia.yaml` (system-level) first, falls back to `~/.config/cdi/nvidia.yaml`. Non-fatal -- stack start continues with a warning if generation fails. (Fixes #1123)

### Related Issues

- Fixes #1123 - Auto-configure NVIDIA CDI on stack start

## [v1.1.9] - 2026-05-09

### Fixed

- **GPU Support Restored for Podman**: Restored full GPU support broken by the Docker-to-Podman migration. Root causes: podman-compose silently ignores `deploy.resources.reservations.devices` (Docker Swarm syntax); NVIDIA CDI was never configured; wrong exporter image (DCGM incompatible with WSL2). (Fixes #1118)
- **NVIDIA CDI Auto-Configuration**: Added `setup_nvidia_cdi()` to `setup-podman-rootless.sh` to generate the NVIDIA CDI spec (`/etc/cdi/nvidia.yaml`) required for Podman GPU device allocation. CDI status now verified by `--verify` flag. (Fixes #1118)
- **Podman GPU Compose Overlay**: Added `docker-compose.gpu-podman.yml` with CDI device entries for all GPU services. Restructured `set_compose_cmd()` to detect the container runtime before applying GPU overlays, loading the correct overlay per runtime. (Fixes #1118)
- **GPU Metrics Exporter Replaced**: Replaced DCGM exporter (requires NVML, incompatible with WSL2) with `utkuozdemir/nvidia_gpu_exporter` (nvidia-smi based, WSL2 compatible) on port 9445. (Fixes #1118)
- **Grafana GPU Dashboard Corrected**: Fixed `gpu-metrics.json` utilization expression (`nvidia_smi_utilization_gpu_ratio * 100`) and aligned all panel queries to exporter metric names. (Fixes #1118)
- **Stack Status Health Check Port**: Updated `stack.sh` GPU exporter health check from port 9400 (DCGM) to 9445. (Fixes #1118)
- **Grafana Duplicate Dashboard Folder**: Fixed provisioning mismatch that created an empty `AIXCL` folder and a populated `AIXCL Dashboards` folder. Dashboard provider now matches the folder name used by alert rules. (Fixes #1116)

### Related Issues

- Fixes #1116 - Grafana dashboard provisioning creates duplicate folders
- Fixes #1118 - GPU not available to Podman after Docker migration CDI not configured

## [v1.1.7] - 2026-05-07

### Security

- **Eliminated Baked-In Credential Defaults**: Removed all hardcoded password fallbacks from Docker Compose and service entrypoints. Services now fail fast if Vault secrets are missing. (Fixes #1076)
- **Restart-Safe Password Preservation**: Grafana and pgAdmin entrypoints now detect first-start vs restart, preserving user-changed passwords across container restarts. (Fixes #1079)
- **Vault Single-Source-of-Truth**: Unified credential sync across all services with Vault KV storage as the sole password authority. (Fixes #1051, #1052)
- **Vault Bootstrap Race Condition Fixed**: Replaced static 5s sleep with active Vault KV polling loop (up to 30s), preventing services from starting with empty password files. (Fixes #1055)

### Infrastructure

- **Auto-Run Vault Init**: `stack start` now automatically triggers `vault init` to prevent bootstrap race conditions. (Fixes #1054)
- **Grafana Entrypoint Permissions**: Restored correct file permissions and corrected CLI log message in Grafana entrypoint. (Fixes #1053)

### Governance and Workflow

- **PR Creation Governance**: Tightened workflow to prevent label-assignee race conditions. (Fixes #1068)
- **PR Validation Reliability**: Fixed silent failures in PR validation workflow by adding proper GitHub CLI authentication and error visibility. (Fixes #1073, #1080)
- [x] **GPG Terminal Setup**: Documented terminal configuration requirements and added `configure_terminal` helper to `setup-gpg.sh`. (Fixes #1071)
- **Security Documentation**: Created missing security documentation referenced by SECURITY.md. (Fixes #1064)

### Configuration

- **Cloud Provider Agnostic**: Made `opencode.json` provider-agnostic and removed hardcoded `small_model` to enable cloud provider fallback. (Fixes #1058, #1062)
- **Environment Variable Hardening**: Replaced hardcoded Vault dev token and PostgreSQL fallback with proper environment variable configuration. (Fixes #998)

### Documentation

- **Agent Context Update**: Updated `agent-context.md` with latest conventions and references. (Fixes #1057)

### Related Issues

- Fixes #998 - Replace hardcoded Vault dev token
- Fixes #1051 - Vault single-source-of-truth credential sync
- Fixes #1053 - Grafana entrypoint permissions
- Fixes #1054 - Auto-run vault init after stack start
- Fixes #1055 - Poll Vault KV for bootstrap passwords
- Fixes #1057 - Update agent-context.md
- Fixes #1058 - Remove hardcoded small_model
- Fixes #1062 - Make opencode.json provider-agnostic
- Fixes #1064 - Create missing security documentation
- Fixes #1068 - Tighten PR creation governance
- Fixes #1071 - Document GPG terminal setup
- Fixes #1073 - Fix PR validation race condition
- Fixes #1076 - Remove baked-in credential defaults
- Fixes #1079 - Respect user-changed passwords after first start
- Fixes #1080 - PR validation workflow authentication

---

## [v1.1.6] - 2026-05-05

### Configuration

- **OpenCode Schema Alignment**: Enhanced opencode.json with official schema features including shell, logLevel, snapshot, share, autoupdate, username, and watcher ignore patterns (Fixes #1041)
- **Small Model Support**: Added small_model configuration for fast lightweight tasks like title generation
- **Artifact Prevention**: Updated .gitignore to prevent accidental commits of npm artifacts (node_modules, package-lock.json, bun.lock)

### Documentation

- **README Access Points**: Added missing observability services to Access Points table (Loki port 3100, Alertmanager port 9093) and simplified Vault credentials notes (Fixes #1030)

### Related Issues

- Fixes #1041 - Release v1.1.6
- Fixes #1030 - Refresh README service list and access points

---

## [v1.1.5] - 2026-05-05

### Governance

- **Consolidated OpenCode governance**: Eliminated `ai/` directory duplication by moving all agent definitions, skills, and rules into `.opencode/` per the canonical OpenCode layout (Fixes #1033)
- **Removed stale references**: Cleaned up `ai/` and `.opencode/commands/` references from `AGENTS.md`, `opencode.json`, and documentation (Fixes #1035)

### Documentation

- **Documentation overhaul**: Restructured `docs/` for clarity, aligned `opencode.json` with `.opencode/` conventions, and added `.opencode/rules/` for workflow, formatting, and security constraints (Fixes #1031)

### Related Issues

- Fixes #1031 - Docs overhaul and opencode.json alignment
- Fixes #1033 - Consolidate OpenCode governance and eliminate ai/ duplication
- Fixes #1035 - Remove stale ai/ and .opencode/commands/ references

---

## [v1.1.4] - 2026-05-05

### Security

- **Eliminated PostgreSQL Password Fallback**: Removed `POSTGRES_PASSWORD` and `POSTGRES_PASSWORD_FILE` from postgres service in `docker-compose.yml`. Entrypoint now polls Vault bootstrap agent and fails hard if secret unavailable (Fixes #1019)
- **Postgres Exporter Vault Hardening**: Fixed binary path and removed password leak from compose (Fixes #1017, #1025)

### Fixed

- **Bash Completion Drift**: Added missing `restart`, `config`, `init`, and `export-quadlet` commands (Fixes #1021)
- **Postgres Exporter Startup**: Corrected binary path from `/postgres_exporter` to `/bin/postgres_exporter` (Fixes #1025)

### Documentation

- **README Quick Start**: Added `./aixcl stack init` step and `utils bash-completion` / `utils prune` commands (Fixes #1020)

### Related Issues

- Fixes #1019 - Remove hardcoded postgres password from docker-compose.yml
- Fixes #1020 - Update README with missing init step and utils commands
- Fixes #1021 - Fix bash completion script drift
- Fixes #1025 - Fix postgres-exporter binary path in vault entrypoint

---

## [v1.1.3] - 2026-05-05

### Summary

Hotfix release -- Vault credential management hardening. Fixes critical clean build failures where `stack start` silently exited, and four service startup issues (Open WebUI, pgAdmin, Grafana, Postgres exporter) caused by environment variable handling in non-root entrypoint wrappers.

### Fixed

- **Clean Build Silent Failure**: `stack start` silently exited with code 1 on fresh installations because `.env.example` was missing `PROFILE=` and `grep | sed` pipelines failed under `set -e` (Fixes #1008)
- **PostgreSQL Password Sync**: Entrypoint script syncs admin password from Vault on restart using temporary `pg_ctl` start (Fixes #993)
- **Service Credential Leaks**: Vault manages all service passwords. This release removes last traces of password fallbacks from compose and entrypoints (Fixes #1010)

### Security

- **Vault Credential Isolation**: Eliminated `POSTGRES_PASSWORD` fallback in `docker-compose.yml`. Passwords now exclusively from `/run/secrets/postgres-password` (Fixes #1010)
- **Entrypoint Environment Hardening**: Open WebUI and pgAdmin entrypoints now preserve Vault credentials across `su` user switches (Fixes #1012)

### Infrastructure

- **Grafana Vault Entrypoint**: `grafana-entrypoint.sh` reads admin password from `/run/secrets/grafana-password` (Fixes #1005)
- **Vault Bootstrap Agents**: Agent sidecars for Open WebUI, pgAdmin, Grafana, and PostgreSQL fetch static passwords from Vault KV (Fixes #998)

### Related Issues

- Fixes #1005 - Grafana container fails to start due to missing entrypoint volume mount
- Fixes #1008 - Stack start fails silently on clean build due to missing PROFILE and pipefail
- Fixes #1010 - Open WebUI, pgAdmin, and Grafana fail on clean build after Vault credential migration
- Fixes #1012 - Open WebUI and pgAdmin still fail after PR 1011 due to su env issues
- Part of #998 - Add Vault bootstrap passwords for all services
- Part of #1000 - Interactive first-run init with Vault-only credentials

---

## [v1.1.2] - 2026-05-03

### Added

- **Shared Container Lifecycle Utilities**: New `lib/core/service_utils.sh` module with `container_start()`, `container_stop()`, `container_restart()` (#968)
- **Vault Lifecycle Commands**: `./aixcl vault start|stop|restart` now available, using same code path as `stack service` (#968)

### Refactored

- **Stack Service Delegation**: `start_service()` and `stop_service()` in `lib/aixcl/commands/stack.sh` now delegate to shared `service_utils.sh` (#968)

### Documentation

- **Issue Creation Safety**: Templates updated with `--body-file` warnings; DEVELOPMENT.md shows safe `--body-file` patterns; `workflow-guard` skill validates issue body cleanliness (#970)
- **PR Validation Race Condition**: DEVELOPMENT.md updated to always pass `--assignee` to `gh pr create` and warn about the race condition (#972)

## [v1.1.1] - 2026-05-03

### Summary

Simplification release -- Vault is now optional in `usr` and `dev` profiles. Documentation cleaned up per lean repository policy.

### Changed

- **Profile-Gated Vault**: Vault and bootstrap containers are no longer started in `usr` and `dev` profiles (#960)
  - `usr`: ollama, postgres only (2 services)
  - `dev`: ollama, open-webui, postgres, pgadmin only (4 services)
  - `ops` and `sys`: still include full Vault stack
- **Vault CLI Commands**: `./aixcl vault <cmd>` now shows "Vault not enabled" message when profile lacks Vault

### Fixed

- **Grafana Comment**: Removed stale Alloy reference from log-alerts.yml (#962)

### Documentation

- **Docs Audit**: Deleted 17 stale, dated, or generated files (#961)
  - Removed: reports, test plans, compliance analyses, agent templates, monitoring assessments
  - Removed all Alloy references from remaining docs
  - No Alloy mentions remain in docs/ directory

## [v1.1.0] - 2026-05-03

### Summary

Release v1.1.0 - Vault integration hardening and observability cleanup. This release includes 9 commits focusing on Vault secrets volume mounting, Alpine container compatibility, and removal of deprecated Alloy service.

### Added

- **Vault Secrets Volume Mounting**: Mount Vault secrets volume into open-webui and pgadmin containers (#953)
  - Open WebUI and pgAdmin now read credentials from /run/secrets/ via aixcl-vault-secrets volume
  - Entrypoint scripts persist passwords to /var/lib/pgadmin for non-root user (UID 5050)
- **Vault CLI Logs Subcommand**: Add ./aixcl vault logs [n] for viewing Vault init/bootstrap output (#949)

### Fixed

- **POSIX/Alpine Compatibility**: Change vault bootstrap scripts from bash to sh (#950, #951)
  - Alpine-based hashicorp/vault:1.18 image does not include bash
  - Changed shebang from bash to sh, removed unsupported local variables
- **Bootstrap Container Permissions**: Add DAC_OVERRIDE capability (#952)
  - Allows bootstrap containers to write to aixcl-vault-secrets volume (owned by UID 999)

### Changed

- **Remove Deprecated Alloy Service**: Clean up alloy from docker-compose.yml (#955, #956)
  - Removed alloy service definition (~38 lines) and aixcl-alloy-data volume
  - Eliminates noisyy errors on stack stop/restart for non-existent container

### Deprecated

- Alloy service removed entirely. Use Loki+Promtail for log aggregation instead.

## [v1.0.0] - 2026-04-30

### Summary

**Official v1.0.0 Release** - Production-ready AIXCL platform. This release finalizes 9 release candidates with comprehensive infrastructure improvements, devcontainer fixes, and repository governance. Key achievements include complete Codespaces compatibility, proper CODEOWNERS configuration, and robust branch protection.

### Added

- **Devcontainer Simplification**: Consolidated lifecycle scripts and fixed Codespaces compatibility (#888)
  - Merged 4 scripts into 1 post-attach script with first-run detection
  - Removed external volume requirement for automatic Codespaces provisioning
  - Renamed devcontainer to 'codespace devcontainer' for clarity
  - Fixed docker-compose paths for correct file resolution

### Changed

- **CODEOWNERS Configuration**: Updated to reflect sole maintainer ownership (#893)
  - Set @sbadakhc as default owner for entire repository
  - Simplified from 10-line multi-owner to 3-line single-owner configuration
  - Added documentation comment explaining ownership model

### Infrastructure

- **Branch Protection**: Configured active rulesets for main and dev branches
  - Main: Requires 1 review + CODEOWNERS approval
  - Dev: Requires PR with CODEOWNERS approval (0 reviews for flexibility)
  - Code scanning and quality checks enforced on both branches

- **CI/CD Improvements**: Split tests into quick and integration workflows
  - Updated docker/setup-buildx-action to v4 for Node.js 24 compatibility
  - All CI checks passing consistently

### Contributors

Special thanks to all contributors across 9 release candidates who helped achieve this production-ready release.

---

## [v1.0.0-rc9] - 2026-04-30

### Summary

Release Candidate 9 for v1.0.0. This release includes 25+ commits since RC8 with major improvements to engine stability, volume management, and CI/CD infrastructure. Key highlights include GPU startup fixes for llama.cpp, standardized volume naming across contexts, and comprehensive CI tests for all three inference engines.

### Added

- **CI/CD Testing**: Comprehensive devcontainer engine tests for all three engines (Ollama, llama.cpp, vLLM) (#882)
  - Automated testing in CPU-only mode for GitHub Actions
  - Volume persistence validation
  - Engine switching tests
  - Volume consistency validation script

### Fixed

- **llama.cpp GPU Support**: Fixed container startup error by properly configuring volumes and entrypoint in GPU compose (#884)
  - Removed broken shell entrypoint override
  - Added proper volume mounts for models and entrypoint script
  - Container now starts successfully with GPU support

### Changed

- **Volume Management**: Standardized volume naming across local Docker, devcontainer, and GitHub Codespaces (#883)
  - Renamed all volumes to use `aixcl-*` prefix (e.g., `aixcl-ollama-data`, `aixcl-llamacpp-data`)
  - Volumes now marked as `external: true` for persistence across contexts
  - Added `init-volumes.sh` script for one-time volume initialization
  - Stack start automatically checks and initializes volumes

### Infrastructure

- **llama.cpp Model Format**: Fixed default INFERENCE_MODEL to use full HuggingFace path format (#879)
  - Changed from filename-only to full path: `Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf`
  - Aligns with README documentation
  - Fixes model download issues in devcontainer workflows

### Contributors

Thanks to all contributors who helped improve engine stability, volume management, and testing infrastructure.

---

## [v1.0.0-rc8] - 2026-04-22

### Summary

Release Candidate 8 for v1.0.0. This release includes 12 commits since RC7 with focus on documentation accuracy and transparency. Major improvements include correcting Podman support claims, fixing documentation inconsistencies, and enhancing README completeness.

### Documentation

- **Podman Support**: Corrected claims to reflect experimental status (#864)
- **README**: Added missing CLI commands to Quick Start table (#862)
- **Documentation**: Fixed orphaned links, outdated paths, and formatting issues (#857-#861)

### Contributors

Thanks to all contributors who helped improve documentation clarity and accuracy.

## [v1.0.0-rc7] - 2026-04-22

### Summary

Release Candidate 7 for v1.0.0. This release includes 35 commits since RC6 with significant additions including the new `/release` automation command, improved slash command infrastructure with context-aware execution, Alertmanager service integration, Open WebUI upgrade to v0.9.1, and enhanced Grafana dashboards.

### Added

- **Release Automation**: New `/release` slash command to automate the complete release process from version detection to GitHub Release publication (#845)
- **Release Templates**: Standardized release note templates in `ai/templates/release/` and `.github/RELEASE_TEMPLATE.md` (#843)
- **Alertmanager Service**: Integrated Alertmanager for observability stack alerting (#822)
- **Platform Commands**: New slash commands for comprehensive platform health reporting:
  - `/platform` - Live platform health report with models, ports, volumes, firing alerts
  - `/status` - Quick triage command for inference, postgres, webui, docker
  - `/report` - Workflow progress reporting
- **Context-Aware Execution**: Enhanced `/workflow`, `/commit`, `/pr`, `/branch` commands with automatic state detection

### Changed

- **Open WebUI Upgrade**: Updated from v0.8.12 to v0.9.1 incorporating latest security fixes and features (#839)
- **Grafana Dashboard**: Updated docker-containers dashboard to include all 13 services including vllm, alertmanager, nvidia-gpu-exporter, alloy, loki, cadvisor, node-exporter, postgres-exporter (#841)

### Fixed

- Security hardening compatibility fixes for vLLM entrypoint (#836)
- Removed security hardening from pgAdmin due to su authentication failure (#837)
- Added security hardening to postgres container (#835)
- Added security hardening to nvidia-gpu-exporter container (#825)

### Documentation

- Service addition checklist and references documentation
- AGENTS.md v1.5 alignment and output formatting guidance
- Comprehensive security hardening documentation

### Related Issues

- Fixes #844 - Release automation command
- Fixes #842 - Release note templates
- Fixes #840 - Grafana dashboard updates
- Fixes #838 - Open WebUI upgrade
- Fixes #836 - vLLM security hardening compatibility
- Fixes #837 - pgAdmin security reversion
- Fixes #835 - PostgreSQL container security
- Fixes #825 - nvidia-gpu-exporter security
- Fixes #822 - Alertmanager service
- Part of #802 - Context-aware slash commands

---

## [v1.0.0-rc6] - 2026-04-20

### Summary

Release Candidate 6 for v1.0.0. This release includes 15+ commits since RC5 focusing on container security hardening with Linux capability restrictions and defense-in-depth controls for all observability services.

### Security

- **Container Capability Restrictions**: Implemented comprehensive security hardening for 6 observability services (prometheus, grafana, loki, postgres-exporter, node-exporter, alloy) with the following controls:
  - `cap_drop: ALL` - Remove all Linux capabilities
  - `security_opt: no-new-privileges:true` - Prevent privilege escalation
  - `read_only: true` - Read-only root filesystem (where applicable)
  - `tmpfs` mounts - Writable temporary space with noexec,nosuid
  - `:ro` bind mounts - Read-only configuration mounts
  
- **Service Security Matrix**: Each hardened service now runs with minimal privileges:
  | Service | User | cap_drop | no-new-priv | read_only |
  |---------|------|----------|-------------|-----------|
  | prometheus | default | ALL | [x] | [x] |
  | grafana | default | ALL | [x] | [ ]* |
  | loki | default | ALL | [x] | [ ]* |
  | postgres-exporter | 65534:65534 | ALL | [x] | [x] |
  | node-exporter | 65534:65534 | ALL | [x] | [x] |
  | alloy | 12345:12345 | ALL | [x] | [x] |
  
  *\*Requires data volume writes*

- **Security Documentation**: Added comprehensive Section 6 to `docs/operations/security.md` covering:
  - Container security hardening overview
  - Service security matrix with all 9 services
  - Verification commands for container inspection
  - Troubleshooting guide for restricted containers

### Added

- Capability restrictions Phase 1: prometheus, grafana, loki, postgres-exporter (#784, #785)
- Capability restrictions Phase 2: node-exporter, alloy (#786, #787)
- Security options Phase 3: no-new-privileges, read_only, tmpfs mounts (#788, #789)
- Documentation Phase 4: Complete security hardening documentation (#790, #791)
- AGENTS.md output formatting guidance for consistent tabular reports (#782, #783)

### Related Issues

- Fixes #705 - Container Capability Restrictions Implementation (all 4 phases complete)
- Part of #698 - Container Security Hardening Initiative

---

## [v1.0.0-rc5] - 2026-04-20

### Summary

Release Candidate 5 for v1.0.0. This release includes 27 commits since RC4 with critical bug fixes, llamacpp model pre-flight checks, and continued non-root container migrations.

### Added

- **Llamacpp Pre-flight Check**: Added validation to prevent stack start when no llamacpp model is configured (#775)

### Changed

- Preserved DATABASE_URL environment variable when Open WebUI switches to non-root user (#773)
- Moved PostgreSQL wait logic to entrypoint script for better startup handling (#771)
- Pre-created logs directory to prevent root ownership issues (#770)
- Added PostgreSQL readiness check to Open WebUI startup sequence (#768)
- Ensured CLI profile flag updates .env on fresh installations (#766)

### Fixed

- Added network_mode and fixed permissions for pgAdmin container (#764)
- Fixed pgAdmin servers.json import permission issues (#759)
- Fixed docker-compose.yml corruption from models add command (#744)
- Fixed three critical issues: model selection, pgadmin connection, OpenCode token limit (#740)
- Fixed pgAdmin permission errors with entrypoint script (#737)
- Removed database deletion from engine switch command (#736)
- Fixed environment variable consistency issues (#733)
- Fixed vLLM command syntax in docker-compose.yml (#732)
- Fixed llamacpp model name handling for full HF path API calls (#729)
- Fixed Ollama volume permissions with entrypoint script (#728)
- Fixed Open WebUI configuration for non-Ollama engines (#723)
- Fixed llama.cpp model configuration synchronization (#720)

### Security

- Run Open WebUI as non-root user (#721)
- Run vLLM as non-root user via entrypoint script
- Run llama.cpp as non-root user
- Run nvidia-gpu-exporter as non-root user
- Run node-exporter as non-root user (#718)
- Run Ollama as non-root user (#717)
- Hardened Alloy container security configuration with read_only and tmpfs (#716, #715)
- Run postgres-exporter as non-root user (#714)
- Run pgAdmin container as non-root user (#703)
- Run Loki container as non-root user (#702)
- Run Grafana container as non-root user (#701)
- Run Prometheus container as non-root user (#700)
- Run PostgreSQL container as non-root user (#699)

---

## [v1.0.0-rc4] - 2026-04-20

### Summary

Release Candidate 4 for v1.0.0. This release includes critical bug fixes for Open WebUI PostgreSQL support, pgAdmin integration, and engine management.

### Added

- PostgreSQL readiness check to Open WebUI entrypoint
- Pre-create logs directory with correct ownership
- Environment configuration documentation

### Changed

- Improved pgAdmin servers.json import handling
- Enhanced CLI profile flag behavior on fresh install
- Updated default vLLM model from 7B to 0.5B

### Fixed

- Fixed pgAdmin connection and permission issues
- Fixed Open WebUI SQLite fallback when PostgreSQL unavailable
- Fixed root-owned logs directory creation
- Fixed CLI profile persistence
- Fixed docker-compose.yml corruption from models add
- Fixed vLLM command syntax
- Fixed llamacpp model validation

### Documentation

- Added Open WebUI Direct Connections documentation for vLLM/llama.cpp setup
- Updated environment configuration guide

---

## [v1.0.0-rc3] - 2026-04-10

### Summary

Release Candidate 3 for v1.0.0. This release includes 35+ commits since RC2 focusing on rootless/Podman support, multi-registry model pulls, vLLM stability fixes, and infrastructure improvements.

### Added

- **Rootless & Podman Support**: Code support for running AIXCL in rootless environments with both Docker and Podman. Docker rootless is verified; Podman support is implemented but experimental. Includes automated socket detection and permission handling for volumes (Fixes #498).
- **Native Multi-Registry Pulls**: Support for `hf.co/` and `huggingface.co/` URIs in the `models add` command, enabling direct pulls from Hugging Face for all supported engines (Fixes #497).
- **Podman Quadlet Generation**: New `stack export-quadlet` command to generate native Systemd unit files for robust, headless deployments. Note: Quadlet generation is functional but not fully tested with Podman (Fixes #499).
- **Integrated Model Inference Testing**: Merged prompt/response verification into the main `platform-tests.sh` suite for end-to-end reliability.

### Changed

- Renamed service/container from `openwebui` to `webui` across codebase and documentation (Fixes #433). Directory `webui/` and volume path `webui-data/`; display name "Open WebUI". Service contract file `webui.md` renamed to `webui.md`; script `build_and_push_openwebui.sh` renamed to `build_and_push_webui.sh`.
- Updated Open WebUI to v0.8.0 (Fixes #454)
- Updated Grafana to 12.4.2 (latest stable) (Fixes #680)
- Updated various service container images to latest versions (Fixes #677)

### Fixed

- **vLLM Token Limit Error**: Fixed vLLM compatibility issues with OpenCode using `--enforce-eager` flag to disable CUDA graph capture (Fixes #685, #682, #682)
- **ShellCheck SC2168**: Resolved ShellCheck errors in test infrastructure (Fixes #678)
- **Profile Services**: Fixed PROFILE_SERVICES to use current INFERENCE_ENGINE from .env (Fixes #675)
- **Grafana Version**: Corrected Grafana image tag to use valid stable version

### Infrastructure

- Added HuggingFace cache volume to vLLM service
- Improved vLLM test error handling for long startup times
- Enhanced workflow documentation with plain text formatting guidelines
- Added assignee requirements to issue and PR templates

### Documentation

- Updated workflow report format with consistent markdown tables (Fixes #688)
- Added documentation for test suite fixes (Fixes #670)

---

## [v1.0.0-rc2] - 2026-02-07

### Summary

Release Candidate 2 for v1.0.0. This release includes 58 commits since RC1 covering refactoring, bug fixes, feature enhancements, dependency updates, and documentation improvements.

### Added

- Token usage reporting with actual Ollama counts for accurate model usage tracking
- OpenCode orchestrator YAML configuration replacing legacy agent config
- Commercial licensing documentation (`COMMERCIAL.md`)
- Explicit timeouts to platform test script API calls
- orchestrator members test timeout increase to prevent false failures

### Changed

- Consolidated duplicated code between `aixcl` CLI and lib modules
- Replaced DEBUG print statements with proper logging throughout codebase
- Removed hardcoded confidence penalty heuristics from orchestrator
- Aligned primary model confidence wording and stage 2 ranking criteria
- Defaulted orchestrator to plain text responses
- Updated Open WebUI to v0.7.2
- Bumped `wheel` dependency from 0.45.1 to 0.46.2
- Updated README with privacy emphasis and profile testing options
- Improved documentation consistency across project

### Fixed

- Guarded interactive prompts against `set -e` on EOF
- Removed duplicate database save in non-streaming chat completions path
- Aligned platform test profile messaging
- Updated command references in help messages and error output
- Removed temporary `pr-body-temp.md` file

### Documentation

- Clarified OpenCode plugin omission from `RUNTIME_CORE_SERVICES`
- Added assignee and PR labeling requirements to development workflow
- Improved overall documentation consistency

---

## [v1.0.0-rc1] - 2025-12-26

### Added

#### Governance Model and Architecture Documentation
- **Governance Framework**: Added comprehensive architectural governance model in `docs/architecture/governance/`
  - Runtime Core vs Operational Services separation
  - Service contracts defining dependencies and boundaries
  - Profile definitions (core, dev, ops, full)
  - AI guidance for preserving architectural invariants
  - Stack status specification
- **Documentation Updates**: Updated README.md, docs, and manpage to reflect governance model
- **Bash Completion**: Updated completion script to reflect service categorization

#### Database Persistence for orchestrator
- **PostgreSQL Integration**: Added automatic PostgreSQL-based storage for orchestrator conversations
  - Automatic schema creation on startup via `ensure_schema()` function
  - Migration system with `001_create_chat_table.sql` for initial schema setup
  - Support for both Open WebUI and OpenCode plugin conversations via `source` field
  - Conversation tracking with unique IDs generated from message hashes
  - Full message history preservation with stage data (Stage 1, 2, 3 responses)

- **Database Storage Module** (`orchestrator/backend/db_storage.py`):
  - `create_opencode_conversation()` - Create new OpenCode conversations
  - `get_opencode_conversation()` - Retrieve conversations by ID
  - `add_message_to_conversation()` - Add messages to existing conversations
  - `list_opencode_conversations()` - List all OpenCode conversations
  - `delete_conversation()` - Delete conversations
  - `find_conversation_by_messages()` - Find conversations by message content

- **Database Connection Management** (`orchestrator/backend/db.py`):
  - Connection pool management with asyncpg
  - Automatic schema verification and creation
  - Graceful degradation when database is unavailable
  - Environment-based configuration (ENABLE_DB_STORAGE flag)

- **Conversation Tracker** (`orchestrator/backend/conversation_tracker.py`):
  - Deterministic conversation ID generation from message hashes
  - Message entry creation with proper formatting
  - Integration with database storage

- **API Endpoints**:
  - Conversation deletion endpoint: `DELETE /v1/chat/completions/{conversation_id}`
  - Automatic conversation persistence on chat completion requests
  - Conversation ID returned in API responses

#### Testing Infrastructure
- **Test Scripts** (moved to `orchestrator/scripts/test/`):
  - `test_db_connection.py` - Comprehensive database connection and operation tests
  - `test_db_in_container.sh` - Container-based test wrapper
  - `test_api.sh` - API endpoint integration tests
  - `test_request.json` - Sample API request for testing

#### Database Utilities
- **Utility Scripts** (organized in `scripts/db/`):
  - `002_add_source_column.sql` - Migration script for adding source column to existing databases
  - `query_opencode_chats.sql` - Query script for OpenCode conversations
  - `query_all_chats.sql` - Query script for all conversations
  - `check_db.sh` - Quick database inspection script
  - `README.md` - Documentation for database utilities

#### Documentation
- Updated main `README.md` with database persistence features
- Created `orchestrator/scripts/test/README.md` with test script documentation
- Created `scripts/db/README.md` with database utility documentation
- Updated `orchestrator/TESTING.md` with new script paths and testing procedures

### Changed

#### Repository Organization
- **Script Organization**:
  - Moved SQL utility files from root to `scripts/db/` directory
  - Moved test scripts from `orchestrator/` to `orchestrator/scripts/test/` directory
  - Created logical directory structure for better maintainability

- **File Cleanup**:
  - Removed duplicate `check_opencode.sql` file (consolidated with `check_opencode_chats.sql`)
  - Organized temporary test files into appropriate directories
  - Updated all script paths in documentation

#### Configuration
- Added `ENABLE_DB_STORAGE` environment variable (default: `true`)
- Database connection uses same PostgreSQL instance as Open WebUI
- Automatic migration execution on service startup

### Technical Details

#### Database Schema
The `chat` table structure:
- `id` (UUID) - Primary key, auto-generated
- `title` (TEXT) - Conversation title
- `chat` (JSONB) - Full conversation data with messages array
- `meta` (JSONB) - Additional metadata
- `source` (TEXT) - Source identifier ('openwebui' or 'opencode')
- `created_at` (TIMESTAMP) - Creation timestamp
- `updated_at` (TIMESTAMP) - Auto-updated on changes
- `user_id` (TEXT) - Optional user identifier

Indexes created for performance:
- `idx_chat_source` - Index on source field
- `idx_chat_created_at` - Index on creation timestamp (DESC)
- `idx_chat_meta` - GIN index on metadata JSONB
- `idx_chat_user_id` - Partial index on user_id

#### Migration System
- Migrations are automatically executed on startup via `ensure_schema()`
- Migration files located in `orchestrator/backend/migrations/`
- Uses `IF NOT EXISTS` clauses for idempotent execution
- Graceful error handling for existing schemas

### Migration Guide

For existing installations upgrading to include database persistence:

1. **Automatic Migration**: The system will automatically create the schema on next startup if `ENABLE_DB_STORAGE=true`

2. **Manual Migration** (if needed):
   ```bash
   docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < orchestrator/backend/migrations/001_create_chat_table.sql
   ```

3. **Adding Source Column** (for databases created before source column was added):
   ```bash
   docker exec -i postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DATABASE} < scripts/db/002_add_source_column.sql
   ```

### Breaking Changes

None - This is a backward-compatible addition. Existing functionality remains unchanged.

### Deprecated

None

### Removed

- Removed duplicate `check_opencode.sql` file (functionality preserved in `check_opencode_chats.sql`)

### Fixed

- Fixed script paths in test scripts after reorganization
- Updated documentation references to reflect new script locations

### Security

- Database credentials are managed via environment variables
- Connection pooling with configurable pool size
- Graceful degradation when database is unavailable (service opencodes without persistence)

