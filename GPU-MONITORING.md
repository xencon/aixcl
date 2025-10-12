# GPU Monitoring Dashboard

## Overview

A comprehensive GPU metrics dashboard has been added to AIXCL's monitoring stack, providing real-time visibility into NVIDIA GPU performance, resource utilization, and hardware health.

## Features

### Dashboard Panels (10 Total)

The GPU Metrics dashboard (`/d/aixcl-gpu`) includes:

1. **GPU Utilization** - Real-time GPU compute usage percentage across all GPUs
2. **GPU Memory Usage** - VRAM consumption as percentage of total memory
3. **GPU Temperature** - Thermal monitoring with color-coded warnings
4. **GPU Power Usage** - Current power consumption in Watts
5. **GPU Memory (Used/Free)** - Memory allocation tracking in MB
6. **GPU SM Clock Speed** - Streaming Multiprocessor clock frequency
7. **GPU Memory Clock Speed** - Memory clock frequency
8. **GPU Memory Copy Utilization** - Memory copy engine usage percentage
9. **PCIe Throughput** - PCIe transmit and receive bandwidth
10. **GPU Information Table** - Model name, GPU ID, host information

### Key Metrics Tracked

- **GPU Utilization**: Monitor compute workload intensity
- **Memory Usage**: Track VRAM allocation for LLM model loading
- **Temperature**: Ensure GPUs stay within safe thermal limits (< 85°C)
- **Power Consumption**: Monitor power efficiency and usage
- **Clock Speeds**: Verify GPU is running at expected frequencies
- **Fan Speed**: Ensure adequate cooling is maintained

## Architecture

### Components Added

1. **NVIDIA DCGM Exporter** (Port 9400)
   - Image: `nvcr.io/nvidia/k8s/dcgm-exporter:3.3.5-3.4.0-ubuntu22.04`
   - Collects metrics from NVIDIA GPUs using NVIDIA Data Center GPU Manager (DCGM)
   - Exposes Prometheus-compatible metrics endpoint
   - Official NVIDIA exporter for production GPU monitoring

2. **Prometheus Configuration**
   - Added GPU metrics scraping job (`nvidia-gpu`)
   - 15-second scrape interval for real-time monitoring

3. **Grafana Dashboard**
   - Auto-provisioned GPU metrics dashboard
   - 10-second refresh rate for near real-time updates
   - Supports multi-GPU systems

### Files Modified

```
aixcl/
├── docker-compose.yml                                 # Added nvidia-gpu-exporter service
├── docker-compose.gpu.yml                             # GPU device access for exporter
├── prometheus/prometheus.yml                          # GPU metrics scraping config
├── grafana/provisioning/dashboards/gpu-metrics.json   # GPU dashboard (NEW)
├── README.md                                          # Updated dashboard list
└── MONITORING.md                                      # Updated monitoring documentation
```

## Requirements

### Hardware
- NVIDIA GPU (any model supported by NVIDIA drivers)
- Sufficient PCIe power and cooling

### Software
- NVIDIA GPU drivers installed on host
- Docker with NVIDIA Container Toolkit configured
- Docker Compose with GPU support

### Configuration
The GPU exporter requires GPU access, which is configured in `docker-compose.gpu.yml`:

```yaml
services:
  nvidia-gpu-exporter:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

## Usage

### Accessing the Dashboard

1. **Start AIXCL services** (including monitoring stack):
   ```bash
   ./aixcl start
   ```

2. **Open Grafana**:
   ```bash
   ./aixcl dashboard
   ```
   Or navigate to: http://localhost:3000

3. **Login** with default credentials:
   - Username: `admin`
   - Password: `admin` (change on first login)

4. **Navigate to GPU Dashboard**:
   - Click **Dashboards** → **Browse**
   - Open **AIXCL** folder
   - Select **AIXCL - GPU Metrics**
   - Or go directly to: http://localhost:3000/d/aixcl-gpu

### Monitoring LLM Inference

The GPU dashboard is particularly useful for monitoring Ollama LLM operations:

1. **Model Loading**: Watch GPU memory usage spike when loading models
2. **Inference Performance**: Monitor GPU utilization during query processing
3. **Thermal Management**: Ensure GPU temperature stays safe during extended use
4. **Multi-GPU Workloads**: Track which GPUs are being utilized

### Best Practices

- **Set up alerts** for GPU temperature > 80°C
- **Monitor memory usage** to ensure models fit in VRAM
- **Track power consumption** for capacity planning
- **Verify GPU utilization** to ensure hardware acceleration is active
- **Check fan speed** if temperatures are high

## Troubleshooting

### Dashboard Shows "No Data"

**Possible Causes**:
1. **No NVIDIA GPU**: The system doesn't have an NVIDIA GPU
2. **Missing Drivers**: NVIDIA drivers are not installed
3. **Docker Configuration**: NVIDIA Container Toolkit not configured
4. **Service Not Running**: nvidia-gpu-exporter container failed to start

**Solutions**:

1. **Check GPU availability**:
   ```bash
   nvidia-smi
   ```
   If this fails, NVIDIA drivers are not properly installed.

2. **Check Docker NVIDIA runtime**:
   ```bash
   docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
   ```

3. **Check exporter logs**:
   ```bash
   ./aixcl logs nvidia-gpu-exporter
   ```

4. **Verify Prometheus is scraping GPU metrics**:
   - Open http://localhost:9090
   - Go to **Status** → **Targets**
   - Check `nvidia-gpu` job status

### GPU Exporter Container Fails

If the nvidia-gpu-exporter container fails to start on a GPU-enabled system:

1. **Ensure GPU access is configured**:
   ```bash
   # Check if docker-compose.gpu.yml is being used
   docker compose config | grep -A 10 nvidia-gpu-exporter
   ```

2. **Verify NVIDIA Container Toolkit**:
   ```bash
   docker info | grep -i nvidia
   ```

3. **Check container status**:
   ```bash
   docker ps -a | grep nvidia-gpu-exporter
   docker logs nvidia-gpu-exporter
   ```

### CPU-Only Systems

The GPU monitoring dashboard is designed to gracefully handle systems without NVIDIA GPUs:

- ✅ All other monitoring dashboards continue to work normally
- ✅ Prometheus will mark the GPU exporter as "down" but continue operating
- ✅ System, Docker, and PostgreSQL monitoring remain fully functional
- ℹ️ The GPU dashboard will show "No Data" - this is expected behavior

## Metrics Reference

### Core DCGM Metrics

| Metric | Description | Unit | Typical Range |
|--------|-------------|------|---------------|
| `DCGM_FI_DEV_GPU_UTIL` | GPU utilization percentage | % | 0-100 |
| `DCGM_FI_DEV_FB_USED` | GPU framebuffer memory used | MB | 0 to total VRAM |
| `DCGM_FI_DEV_FB_FREE` | GPU framebuffer memory free | MB | 0 to total VRAM |
| `DCGM_FI_DEV_GPU_TEMP` | GPU temperature | °C | 30-85 |
| `DCGM_FI_DEV_POWER_USAGE` | Power consumption | W | 0 to TDP |
| `DCGM_FI_DEV_SM_CLOCK` | SM clock frequency | MHz | Varies by GPU |
| `DCGM_FI_DEV_MEM_CLOCK` | Memory clock frequency | MHz | Varies by GPU |
| `DCGM_FI_DEV_MEM_COPY_UTIL` | Memory copy utilization | % | 0-100 |
| `DCGM_FI_DEV_PCIE_TX_THROUGHPUT` | PCIe transmit throughput | KB/s | Varies |
| `DCGM_FI_DEV_PCIE_RX_THROUGHPUT` | PCIe receive throughput | KB/s | Varies |
| `DCGM_FI_DRIVER_VERSION` | NVIDIA driver version | - | Version string |

### DCGM Metric Labels

Each metric includes labels for multi-GPU systems:
- `gpu`: GPU index/ID (e.g., "0", "1")
- `modelName`: GPU model name (e.g., "NVIDIA RTX 4090")
- `UUID`: Unique GPU identifier
- `Hostname`: Host system name

## Integration with Existing Dashboards

The GPU dashboard complements existing AIXCL monitoring:

- **System Overview**: General CPU, memory, disk, network
- **Docker Containers**: Container-level resource usage (including Ollama)
- **PostgreSQL Performance**: Database metrics for Open WebUI
- **GPU Metrics**: GPU hardware acceleration monitoring (NEW)

### Correlating Metrics

Use multiple dashboards to understand system behavior:

1. **Ollama Container CPU spike** + **GPU at 100%** = Active LLM inference
2. **High GPU memory usage** + **Ollama container active** = Model loaded in VRAM
3. **GPU temperature rising** + **Fan speed increasing** = System adjusting cooling
4. **Database writes** + **GPU activity** = Conversation being saved after LLM response

## Future Enhancements

Potential improvements to GPU monitoring:

- [ ] GPU utilization alerts (email/Slack notifications)
- [ ] AMD GPU support (via additional exporters)
- [ ] Per-process GPU memory breakdown
- [ ] GPU metrics integration with Ollama API
- [ ] Historical GPU usage reports
- [ ] Multi-node GPU cluster support

## Additional Resources

- **NVIDIA DCGM Exporter**: https://github.com/NVIDIA/dcgm-exporter
- **NVIDIA DCGM Documentation**: https://docs.nvidia.com/datacenter/dcgm/latest/
- **Prometheus**: https://prometheus.io/docs/
- **Grafana Dashboards**: https://grafana.com/docs/grafana/latest/dashboards/
- **NVIDIA Data Center GPU Manager**: https://developer.nvidia.com/dcgm

## Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review `./aixcl logs nvidia-gpu-exporter`
3. Verify Prometheus targets: http://localhost:9090/targets
4. Open an issue with logs and system information

## Summary

The GPU Metrics dashboard provides comprehensive visibility into NVIDIA GPU performance, enabling you to:

✅ Monitor LLM inference performance in real-time  
✅ Track GPU resource utilization and memory usage  
✅ Ensure thermal and power management are optimal  
✅ Identify when GPU acceleration is active  
✅ Support multi-GPU configurations  
✅ Correlate GPU metrics with container and system performance  

The dashboard integrates seamlessly with AIXCL's existing monitoring infrastructure and gracefully handles systems without NVIDIA GPUs.

