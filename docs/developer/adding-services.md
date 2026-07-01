# Adding New Services to AIXCL

When adding a new service to AIXCL, you must update **two** files to ensure the service is properly managed and started by the stack.

## Required Files to Update

### 1. `services/docker-compose.yml`

Define the service configuration:

```yaml
  new-service:
    image: org/image:tag
    container_name: new-service
    pull_policy: if_not_present  # REQUIRED - aligns with other services
    volumes:
      - new-service-data:/data
    network_mode: host
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:port/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Security hardening (when applicable):**

```yaml
    cap_drop:
      - ALL
    cap_add:  # Only if entrypoint needs privilege dropping
      - SETUID
      - SETGID
    security_opt:
      - no-new-privileges:true
    read_only: true  # Only if service supports it
    tmpfs:
      - /tmp:noexec,nosuid,size=50m
```

### 2. `lib/cli/profile.sh`

Add the service to **all applicable profile mappings** in `get_profile_services_for_profile()`:

```bash
get_profile_services_for_profile() {
    local profile="$1"
    local engine="${INFERENCE_ENGINE:-ollama}"
    
    case "$profile" in
        bld)
            echo "$engine vault postgres prometheus grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter NEW-SERVICE"
            ;;
        sys)
            echo "$engine vault open-webui postgres pgadmin prometheus alertmanager grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter NEW-SERVICE"
            ;;
    esac
}
```

## Profile Selection Guide

| Profile | Purpose | Include Service If... |
|---------|---------|----------------------|
| **bld** | Builder-focused (observability) | Monitoring/logging service (e.g., prometheus, grafana, cadvisor) |
| **sys** | System-oriented (complete stack) | All services including UI and admin tools |

## Verification Checklist

Before submitting a PR, verify:

- [ ] Service defined in `services/docker-compose.yml`
- [ ] `pull_policy: if_not_present` included
- [ ] Health check configured
- [ ] Security hardening applied (if compatible)
- [ ] Service added to `get_profile_services_for_profile()` for each applicable profile
- [ ] Volume created in `volumes:` section (if needed)
- [ ] Test with `./aixcl stack start --profile sys` - service starts
- [ ] Test with `./aixcl stack status` - service shows as healthy
- [ ] Test with `/platform` or `./aixcl stack status` - health endpoint responds

## Common Mistakes

1. **Forgetting profile mappings** - Service defined in docker-compose but never started
2. **Inconsistent profiles** - Added to some profiles but not all applicable ones
3. **Missing volumes** - Service expects volume not defined in volumes section
4. **No health check** - Service runs but cannot be verified healthy

## Example: Adding Alertmanager

**docker-compose.yml:**
```yaml
  alertmanager:
    image: prom/alertmanager:v0.28.0
    container_name: alertmanager
    pull_policy: if_not_present
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
    volumes:
      - ../prometheus/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager-data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.listen-address=127.0.0.1:9093'
    network_mode: host
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:9093/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**lib/cli/profile.sh (sys profile):**
```bash
        sys)
            echo "$engine open-webui postgres pgadmin prometheus alertmanager grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter"
            ;;
```

**volumes section in docker-compose.yml:**
```yaml
volumes:
  # ... other volumes ...
  alertmanager-data:
```

## Compose Overlay Files

Some profiles and hardware configurations use overlay files (for example, `services/docker-compose.gpu.yml`, `services/docker-compose.arm.yml`, `services/docker-compose.gpu-podman.yml`, `services/docker-compose.postgres-ssl.yml`, and `services/docker-compose.secrets.yml`). These files are not valid Docker Compose projects on their own; they extend or override services defined in `services/docker-compose.yml`. Validate them by combining the base file and the overlay:

```bash
docker compose -f services/docker-compose.yml -f services/docker-compose.gpu.yml config > /dev/null
```

## Related Documentation

- [Profiles Documentation](../architecture/governance/02_profiles.md) - Profile definitions and service composition
- [Service Contracts](../architecture/governance/service_contracts/) - Service dependency rules
- [Security Hardening](../operations/security-runbook.md) - Container security controls
