# Observability in Rootless Mode

## Working Dashboards

The following dashboards are fully functional in rootless Podman mode:

1. **AIXCL - System Overview** (Prometheus)
   - CPU, Memory, Disk metrics
   - Network traffic
   - Container resource usage

2. **AIXCL - GPU Metrics** (Prometheus)
   - NVIDIA GPU utilization
   - Memory usage
   - Temperature and power

3. **AIXCL - PostgreSQL Performance** (Prometheus)
   - Query performance
   - Connection stats
   - Database health

## Unavailable in Rootless

The following features require Docker socket access (incompatible with rootless):

- **Container Logs Dashboard** (Loki)
- **Docker Containers Dashboard** (Loki)

### Workaround

Access logs directly via CLI:
```bash
# View specific service logs
./aixcl stack logs <service>

# Examples:
./aixcl stack logs ollama
./aixcl stack logs open-webui
./aixcl stack logs postgres
```

## Why This Happens

- **Alloy** (log shipper) requires Docker socket or journal access
- Rootless Podman uses user-scoped journal (not accessible from containers)
- File-based log collection is limited

## Future Improvements

Consider:
- Running Alloy on host instead of container
- Configuring Podman to use file-based logging
- Using `podman logs` command for log access
