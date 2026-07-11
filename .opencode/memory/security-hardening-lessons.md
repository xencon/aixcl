# Security Hardening Session -- Key Findings (2026-07-10)

## Container Security Hardening -- What Worked

**Successfully applied to 23 services:**
- CPU/memory/pids resource limits via `deploy.resources` -- prevents DoS/fork bombs
- `cap_drop: ALL` + minimal `cap_add` -- reduced privilege surface
- `no-new-privileges:true` on runtime core (ollama, vault) and observability (prometheus, loki, grafana)
- `read_only: true` + `tmpfs` on vault, loki -- immutable rootfs
- cadvisor removed from `sys` profile (retained in `bld` for dev)
- All hardening done WITHOUT changing `network_mode: host` invariant

## Entrypoint Compatibility -- Critical Lesson

**Services that CANNOT use `read_only` + `tmpfs /tmp:noexec`:**
| Service | Root Cause |
|---------|------------|
| **ollama** | Entrypoint starts as root, `chown`s `/home/ubuntu` on rootfs, then drops to ubuntu user via `setpriv` |
| **open-webui** | Entrypoint starts as root, sets up dirs, then `setpriv` drops to UID 1000 |
| **pgadmin** | Entrypoint starts as root, `su -m` drops to pgadmin user; also starts postfix mail system |

**Services that WORK with `read_only` + hardening:**
- vault, loki, prometheus, alertmanager, exporters (all start as non-root)

## pgAdmin -- Special Case

pgAdmin requires **no capability restrictions** (`cap_drop: ALL` breaks it) because:
1. Entrypoint uses `su -m` for user transition
2. Starts postfix mail system (needs `SYS_RESOURCE`, `DAC_OVERRIDE`, etc.)
3. Original compose had comment: "Security hardening removed -- cap_drop/no-new-privileges breaks su authentication"

**Resolution:** Remove all hardening from pgadmin; let it run with default capabilities. Other services retain full hardening.

## Stack Status CLI Bug

**Bug:** `./aixcl stack status` exited early on curl failures due to `set -e` in main script.
**Fix:** Added `|| health_result="000"` to all curl calls in status() function.

## Verification Protocol

**Live verification required** (CI only validates syntax):
- `./aixcl stack start --profile sys` completes without timeout
- `./aixcl stack status` shows all services healthy
- **Inference round-trip**: `curl POST /v1/chat/completions` with model load + completion
- `podman inspect <service> --format '{{.HostConfig.ReadonlyRootfs}}'` confirms hardening state

## Release v1.1.56 Summary

- Container security hardening across stack
- Runtime core entrypoint compatibility fixes
- Stack status curl failure handling
- pgAdmin postfix compatibility
- Agent queue label renamed to `agent` (previously model-specific)

## Files Modified

- `services/docker-compose.yml` -- hardening + pgadmin fix
- `config/profiles/sys.env` -- cadvisor removed from sys
- `lib/aixcl/commands/stack.sh` -- status curl failure handling
- `CHANGELOG.md` -- v1.1.56 entry
