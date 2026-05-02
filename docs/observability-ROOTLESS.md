# Observability in Rootless Mode

## GPU Metrics Exporter

In rootless mode, the standard DCGM exporter cannot access the NVML library. Instead, we provide a custom GPU exporter that runs as a user service.

### Setup GPU Exporter

```bash
# Install systemd service
cp scripts/exporters/gpu-exporter.service.template ~/.config/systemd/user/gpu-exporter.service

# Update the path in the service file to point to your repo
sed -i "s|/home/sbadakhc/src/github.com/xencon/aixcl|$(pwd)|g" ~/.config/systemd/user/gpu-exporter.service

# Start the service
systemctl --user daemon-reload
systemctl --user enable gpu-exporter.service
systemctl --user start gpu-exporter.service

# Verify it's working
curl http://localhost:9445/metrics
```

### Metrics Available

- `nvidia_smi_utilization_gpu` - GPU utilization percentage
- `nvidia_smi_memory_used_bytes` - GPU memory used
- `nvidia_smi_memory_total_bytes` - Total GPU memory
- `nvidia_smi_temperature_gpu` - GPU temperature in Celsius
- `nvidia_smi_power_draw_watts` - Power consumption in Watts

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
