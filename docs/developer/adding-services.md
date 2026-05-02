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
        usr)
            echo "$engine postgres"
            ;;
        dev)
            echo "$engine open-webui postgres pgadmin"
            ;;
        ops)
            echo "$engine postgres prometheus grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter NEW-SERVICE"
            ;;
        sys)
            echo "$engine open-webui postgres pgadmin prometheus alertmanager grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter NEW-SERVICE"
            ;;
    esac
}
```

Also update the deprecated `PROFILE_SERVICES` array for backward compatibility:

```bash
declare -A PROFILE_SERVICES=(
    [usr]="INFERENCE_ENGINE_PLACEHOLDER postgres"
    [dev]="INFERENCE_ENGINE_PLACEHOLDER open-webui postgres pgadmin"
    [ops]="INFERENCE_ENGINE_PLACEHOLDER postgres prometheus grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter NEW-SERVICE"
    [sys]="INFERENCE_ENGINE_PLACEHOLDER open-webui postgres pgadmin prometheus alertmanager grafana loki cadvisor node-exporter postgres-exporter nvidia-gpu-exporter NEW-SERVICE"
)
```

## Profile Selection Guide

| Profile | Purpose | Include Service If... |
|---------|---------|----------------------|
| **usr** | Minimal footprint | Required for basic runtime (e.g., postgres for persistence) |
| **dev** | Developer workstation | Developer/admin tool (e.g., pgadmin, Open WebUI) |
| **ops** | Observability | Monitoring/logging service (e.g., prometheus, grafana, cadvisor) |
| **sys** | Complete stack | All services except excluded (privileged or incompatible) |

## Verification Checklist

Before submitting a PR, verify:

- [ ] Service defined in `services/docker-compose.yml`
- [ ] `pull_policy: if_not_present` included
- [ ] Health check configured
- [ ] Security hardening applied (if compatible)
- [ ] Service added to `get_profile_services_for_profile()` for each applicable profile
- [ ] Service added to `PROFILE_SERVICES` array (backward compatibility)
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

## Related Documentation

- [Profiles Documentation](../architecture/governance/02_profiles.md) - Profile definitions and service composition
- [Service Contracts](../architecture/governance/service_contracts/) - Service dependency rules
- [Security Hardening](../operations/security.md) - Container security controls
