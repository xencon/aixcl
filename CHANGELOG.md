# Changelog

All notable changes to the AIXCL project will be documented in this file.

## [Unreleased]

## [v1.1.10] - 2026-05-09

### Added

- **NVIDIA CDI Auto-Configuration on Stack Start**: `stack start` now automatically generates the NVIDIA CDI spec if NVIDIA hardware and `nvidia-ctk` are present but no CDI devices are registered. Tries `/etc/cdi/nvidia.yaml` (system-level) first, falls back to `~/.config/cdi/nvidia.yaml`. Non-fatal — stack start continues with a warning if generation fails. (Fixes #1123)

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
- **GPG Terminal Setup**: Documented terminal configuration requirements and added `configure_terminal` helper to `setup-gpg.sh`. (Fixes #1071)
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

Hotfix release — Vault credential management hardening. Fixes critical clean build failures where `stack start` silently exited, and four service startup issues (Open WebUI, pgAdmin, Grafana, Postgres exporter) caused by environment variable handling in non-root entrypoint wrappers.

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

Simplification release — Vault is now optional in `usr` and `dev` profiles. Documentation cleaned up per lean repository policy.

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
  | prometheus | default | ALL | ✅ | ✅ |
  | grafana | default | ALL | ✅ | ❌* |
  | loki | default | ALL | ✅ | ❌* |
  | postgres-exporter | 65534:65534 | ALL | ✅ | ✅ |
  | node-exporter | 65534:65534 | ALL | ✅ | ✅ |
  | alloy | 12345:12345 | ALL | ✅ | ✅ |
  
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

