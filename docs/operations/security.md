# Rootless Container Operations

> **Podman Support Status**: Experimental/Beta
> Podman support is implemented in code but has not been fully tested. Docker rootless mode is verified and recommended. See [#864](https://github.com/xencon/aixcl/issues/864) for current status.

AIXCL supports running on rootless container engines (Docker fully verified, Podman experimental) to provide enhanced security isolation. This document outlines the operational considerations, benefits, and configuration details for rootless deployments.

## 1. Overview

By default, Docker runs as a root-level daemon, which poses a security risk if a container is compromised. Rootless mode allows running the container engine and containers as a non-privileged user, significantly reducing the platform's attack surface.

### 1.1 Benefits
- **Enhanced Security**: Compromised containers cannot easily gain root access to the host.
- **Per-User Isolation**: Each user can run their own independent AIXCL stack.
- **No Sudo Required**: Once set up, all `./aixcl` commands run without elevated privileges.

## 2. Detection and Support

AIXCL automatically detects if your container engine is running in rootless mode during environment validation:

```bash
./aixcl utils check-env
```

If rootless mode is detected, the CLI will prioritize appropriate configurations (e.g., using user-specific socket paths).

## 3. Operational Considerations

### 3.1 Socket Paths

In rootless mode, the Docker socket is located in a user-writable directory rather than `/var/run/docker.sock`. AIXCL automatically detects these paths:
- **Docker** (verified): `${XDG_RUNTIME_DIR}/docker.sock`
- **Podman** (experimental): `${XDG_RUNTIME_DIR}/podman/podman.sock`

The CLI exports this as `DOCKER_SOCK` for use within the container stack.

### 3.2 Volume Ownership and UID Mapping
Rootless engines use UID remapping (via `subuid` and `subgid`). 
- **Inside Container**: UID 0 (root)
- **Outside Host**: Your current user UID

This means that bind-mounted volumes (like `./pgadmin-data` or `./postgres-data`) are naturally owned by your host user, and the container's "root" user has full access to them.

### 3.3 Specific Service Notes

#### pgAdmin
pgAdmin is configured to run as UID 5050. In rootless mode, the AIXCL stack ensures that the internal `chown` logic is compatible with rootless remapping, ensuring the web interface can always write to its storage directory.

#### Prometheus, Grafana, and Loki
These services are configured to run as `user: root` within their containers. In a rootless environment, this is the safest and most compatible configuration for bind-mounted configuration files and data directories.

#### cAdvisor
**Note**: cAdvisor requires extensive access to host `/sys` and `/proc` filesystems. In rootless mode, cAdvisor may have limited visibility into host-level metrics or may fail to start depending on your kernel configuration.

## 4. Migration Guide

> **Podman Migration**: The following guide is theoretical and has not been tested end-to-end. Use with caution and report issues to [#864](https://github.com/xencon/aixcl/issues/864).

### 4.1 From Rootful Docker to Rootless Podman (Experimental)

1. Stop the existing stack: `./aixcl stack stop`
2. Install Podman and `podman-compose` (see [Podman installation guide](https://podman.io/getting-started/installation))
3. Ensure your user is configured for rootless (check `/etc/subuid`)
4. Run `./aixcl utils check-env` to verify detection
5. Start the stack: `./aixcl stack start`

**Note**: Podman support is experimental. Some features may not work as expected.

**Note**: Volumes created in rootful Docker are owned by host root and will not be accessible to rootless Podman without manual `chown`. It is recommended to start with a clean stack or manually adjust permissions:
```bash
sudo chown -R $USER:$USER ./pgadmin-data ./postgres-data ./prometheus ./grafana ./loki
```

## 5. Troubleshooting

If services fail to start in rootless mode:
1. Verify `DOCKER_SOCK` is correctly identified: `./aixcl stack status` (it logs the socket path).
2. Check if `slirp4netns` or `pasta` is installed for rootless networking.
3. Ensure your user's lingering is enabled for persistent services: `loginctl enable-linger $USER`

---

## 6. Container Security Hardening

AIXCL implements defense-in-depth security controls for all observability services. This section documents the container hardening measures applied to minimize attack surface.

### 6.1 Security Controls Overview

The following security controls are applied to services where applicable:

| Control | Purpose | Services |
|---------|---------|----------|
| `cap_drop: ALL` | Remove all Linux capabilities | 6 observability services |
| `no-new-privileges:true` | Prevent privilege escalation | 6 observability services |
| `read_only: true` | Make root filesystem read-only | 4 services |
| `tmpfs` mounts | Writable temporary space | 4 services |
| `:ro` bind mounts | Read-only config mounts | All services |

### 6.2 Service Security Matrix

| Service | User | cap_drop | no-new-priv | read_only | tmpfs | :ro Mounts |
|---------|------|----------|-------------|-----------|-------|------------|
| **prometheus** | default | ALL | ✅ | ✅ | ✅ | 2 |
| **grafana** | default | ALL | ✅ | ❌* | - | 1 |
| **loki** | default | ALL | ✅ | ❌* | - | 2 |
| **postgres-exporter** | 65534:65534 | ALL | ✅ | ✅ | ✅ | 0 |
| **node-exporter** | 65534:65534 | ALL | ✅ | ✅ | ✅ | 3 |
| **cadvisor** | root | - | - | - | - | 5 |
| **open-webui** | root** | - | - | - | - | 0 |
| **pgadmin** | root** | - | - | - | - | 1 |

*\*Requires data volume writes*
*\*\*Entrypoint switches to non-root user*

### 6.3 Rationale for Controls

#### Capability Restrictions (cap_drop: ALL)

Linux capabilities grant specific privileges to processes. Most observability services only need to:
- Read configuration files
- Listen on network ports (unprivileged)
- Write to data volumes
- Read from /proc and /sys (already world-readable)

None require elevated capabilities, so `cap_drop: ALL` is applied.

#### No-New-Privileges

Prevents processes from gaining additional privileges through:
- setuid/setgid binaries
- file capabilities
- exec calls

#### Read-Only Root Filesystem

Prevents runtime modifications to:
- System binaries
- Configuration files
- Libraries

Services with writable volumes (grafana-data, loki-data) cannot use read_only.

### 6.4 Verification Commands

Check container security settings:

```bash
# View container capabilities
docker inspect <container> --format='{{.HostConfig.CapDrop}}'

# Check security options
docker inspect <container> --format='{{.HostConfig.SecurityOpt}}'

# Verify read-only status
docker inspect <container> --format='{{.HostConfig.ReadonlyRootfs}}'

# View all Prometheus targets (should all be 'up')
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'
```

### 6.5 Troubleshooting Restricted Containers

| Issue | Cause | Solution |
|-------|-------|----------|
| Service fails to start | Missing write access | Add tmpfs mount or remove read_only |
| Permission denied on config | Missing :ro mount | Add explicit read-only bind mount |
| Cannot bind to port <1024 | Requires root | Use unprivileged ports (default) |
| cAdvisor no metrics | cgroup access | Requires privileged (by design) |

### 6.6 Related Issues

- [#698](https://github.com/xencon/aixcl/issues/698) - Container Security Hardening Initiative
- [#705](https://github.com/xencon/aixcl/issues/705) - Capability Restrictions Implementation
- [#784](https://github.com/xencon/aixcl/issues/784) - Phase 1: Non-privileged services
- [#786](https://github.com/xencon/aixcl/issues/786) - Phase 2: Post-migration services
- [#788](https://github.com/xencon/aixcl/issues/788) - Phase 3: Security options
