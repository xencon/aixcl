# Rootless Container Operations

AIXCL supports running on rootless container engines (Podman or Docker) to provide enhanced security isolation. This document outlines the operational considerations, benefits, and configuration details for rootless deployments.

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
In rootless mode, the Docker/Podman socket is located in a user-writable directory rather than `/var/run/docker.sock`. AIXCL automatically detects these paths:
- **Podman**: `${XDG_RUNTIME_DIR}/podman/podman.sock`
- **Docker**: `${XDG_RUNTIME_DIR}/docker.sock`

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

### 4.1 From Rootful Docker to Rootless Podman
1. Stop the existing stack: `./aixcl stack stop`
2. Install Podman and `podman-compose`.
3. Ensure your user is configured for rootless (check `/etc/subuid`).
4. Run `./aixcl utils check-env` to verify detection.
5. Start the stack: `./aixcl stack start`

**Note**: Volumes created in rootful Docker are owned by host root and will not be accessible to rootless Podman without manual `chown`. It is recommended to start with a clean stack or manually adjust permissions:
```bash
sudo chown -R $USER:$USER ./pgadmin-data ./postgres-data ./prometheus ./grafana ./loki
```

## 5. Troubleshooting

If services fail to start in rootless mode:
1. Verify `DOCKER_SOCK` is correctly identified: `./aixcl stack status` (it logs the socket path).
2. Check if `slirp4netns` or `pasta` is installed for rootless networking.
3. Ensure your user's lingering is enabled for persistent services: `loginctl enable-linger $USER`
