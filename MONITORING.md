# AIXCL Monitoring Guide

This guide provides detailed information about the monitoring and metrics capabilities integrated into AIXCL.

## Overview

AIXCL includes a comprehensive monitoring stack consisting of:
- **Prometheus**: Time-series database for metrics collection
- **Grafana**: Visualization and analytics platform
- **cAdvisor**: Container-level metrics
- **Node Exporter**: System-level metrics
- **Postgres Exporter**: Database performance metrics

## Quick Start

```bash
# Start all services including monitoring
./aixcl start

# Open Prometheus
./aixcl metrics

# Open Grafana dashboards
./aixcl dashboard
```

## Architecture

### Metrics Collection Flow

```
┌─────────────────┐
│  System Metrics │ ──► Node Exporter (port 9100)
└─────────────────┘                │
                                   │
┌─────────────────┐                │
│Container Metrics│ ──► cAdvisor (port 8081)
└─────────────────┘                │
                                   │      ┌──────────────┐
┌─────────────────┐                ├────► │  Prometheus  │
│Database Metrics │ ──► Postgres Exporter│  (port 9090) │
└─────────────────┘     (port 9187)       └──────┬───────┘
                                                  │
                                                  │
                                           ┌──────▼───────┐
                                           │   Grafana    │
                                           │  (port 3000) │
                                           └──────────────┘
```

## Services Details

### Prometheus (Port 9090)

**Purpose**: Collects and stores metrics from all exporters

**Configuration**: `prometheus/prometheus.yml`

**Key Features**:
- 15-second scrape interval for real-time monitoring
- Persistent storage in Docker volume `prometheus-data`
- HTTP API for querying metrics
- Web UI for ad-hoc queries and exploration

**Useful Queries**:
```promql
# CPU usage percentage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Container CPU usage
rate(container_cpu_usage_seconds_total{name="ollama"}[5m]) * 100

# Database active connections
pg_stat_database_numbackends
```

### Grafana (Port 3000)

**Purpose**: Visualizes metrics with customizable dashboards

**Configuration**: `grafana/provisioning/`

**Default Credentials**: 
- Username: `admin`
- Password: `admin` (change on first login)

**Pre-built Dashboards**:
1. **AIXCL - System Overview** (UID: `aixcl-system`)
2. **AIXCL - Docker Containers** (UID: `aixcl-docker`)
3. **AIXCL - PostgreSQL Performance** (UID: `aixcl-postgres`)
4. **AIXCL - GPU Metrics** (UID: `aixcl-gpu`)

**Accessing Dashboards**:
- Navigate to http://localhost:3000
- Login with credentials
- Click "Dashboards" → "Browse" → "AIXCL" folder

### cAdvisor (Port 8081)

**Purpose**: Exports container-level resource usage metrics

**Metrics Provided**:
- CPU usage per container
- Memory usage and limits
- Network I/O (bytes sent/received)
- Filesystem usage
- Container status and health

**Use Cases**:
- Identify resource-hungry containers
- Monitor Ollama resource usage during inference
- Track container health and uptime

### Node Exporter (Port 9100)

**Purpose**: Exports host system metrics

**Metrics Provided**:
- CPU usage (per core and total)
- Memory usage (RAM and swap)
- Disk I/O and usage
- Network traffic and errors
- System load averages
- File system statistics

**Use Cases**:
- Monitor overall system health
- Track resource availability
- Identify system bottlenecks

### Postgres Exporter (Port 9187)

**Purpose**: Exports PostgreSQL database metrics

**Metrics Provided**:
- Active connections and connection limits
- Query execution times
- Transaction rates (commits/rollbacks)
- Cache hit ratios
- Database size
- Table and index statistics

**Use Cases**:
- Monitor database performance
- Track Open WebUI conversation storage
- Identify slow queries
- Optimize database configuration

### NVIDIA DCGM Exporter (Port 9400)

**Purpose**: Exports NVIDIA GPU metrics for monitoring hardware acceleration using NVIDIA Data Center GPU Manager (DCGM)

**Metrics Provided**:
- GPU utilization percentage
- GPU memory usage (used/total)
- GPU temperature (Celsius)
- GPU power consumption (Watts)
- GPU fan speed percentage
- GPU clock speeds (graphics and memory)
- Encoder/decoder utilization
- Number of GPUs detected
- GPU information (model, driver version, CUDA version)

**Use Cases**:
- Monitor GPU utilization during LLM inference with Ollama
- Track GPU memory usage for model loading
- Ensure GPU temperatures stay within safe limits
- Monitor power consumption and efficiency
- Identify when GPU acceleration is being used

**Requirements**:
- NVIDIA GPU hardware
- NVIDIA drivers installed
- Docker configured with NVIDIA Container Toolkit

**Note**: On systems without NVIDIA GPUs, this exporter will fail to start, but all other monitoring services will continue to work normally.

## Dashboard Details

### System Overview Dashboard

**Metrics Displayed**:
- CPU Usage: Real-time CPU utilization
- Memory Usage: RAM consumption and availability
- Disk Usage: Filesystem space utilization
- Network I/O: Traffic by interface

**Best For**:
- Overall system health monitoring
- Resource capacity planning
- Identifying system bottlenecks

### Docker Containers Dashboard

**Metrics Displayed**:
- CPU Usage per Container: Individual container CPU consumption
- Memory Usage per Container: Container memory utilization
- Network I/O per Container: Traffic by service
- Container Status: Health checks and running status

**Best For**:
- Identifying resource-hungry containers
- Monitoring Ollama during model inference
- Troubleshooting container issues
- Capacity planning for services

### PostgreSQL Performance Dashboard

**Metrics Displayed**:
- Active Connections: Current database connections
- Database Size: Storage usage
- Transaction Rate: Commits and rollbacks per second
- Query Operations: Inserts, updates, deletes
- Cache Hit Ratio: Database cache efficiency
- Connection Pool: By database

**Best For**:
- Database performance optimization
- Monitoring Open WebUI conversation storage
- Identifying database bottlenecks
- Query performance analysis

### GPU Metrics Dashboard

**Metrics Displayed**:
- GPU Utilization: Real-time GPU compute usage percentage
- GPU Memory Usage: VRAM consumption and allocation
- GPU Temperature: Thermal monitoring in Celsius
- GPU Power Usage: Current power consumption in Watts
- GPU Fan Speed: Cooling fan RPM percentage
- GPU Clock Speeds: Graphics and memory clock frequencies
- Encoder/Decoder Utilization: Video encode/decode engine usage
- GPU Information: Model name, driver version, CUDA version
- Number of GPUs: Total GPUs detected in the system

**Best For**:
- Monitoring LLM model inference performance
- Tracking GPU resource usage during Ollama operations
- Ensuring adequate cooling and power management
- Identifying when GPU acceleration is active
- Multi-GPU workload distribution analysis
- Capacity planning for GPU-intensive workloads

**Requirements**:
- NVIDIA GPU hardware with compatible drivers
- NVIDIA Container Toolkit configured in Docker
- GPU access enabled via docker-compose.gpu.yml

**Note**: Dashboard will show "No Data" on systems without NVIDIA GPUs. This is expected behavior and does not affect other monitoring features.

## Monitoring LLM Performance

While Ollama doesn't natively expose Prometheus metrics, you can monitor LLM performance through:

### 1. Container Resource Usage
Monitor Ollama container CPU and memory usage during inference:
- High CPU usage indicates active model processing
- Memory spikes correlate with large model loading
- Track resource patterns for different models

### 2. Database Query Patterns
Open WebUI stores conversations in PostgreSQL:
- Monitor query rates when saving conversations
- Track database growth as conversations accumulate
- Identify slow queries affecting UI responsiveness

### 3. PostgreSQL Logs
PostgreSQL is configured to log all statements:
```bash
# View query logs
./aixcl logs postgres

# Filter for slow queries
./aixcl logs postgres | grep "duration:"
```

### 4. Manual Timing
Time LLM responses at the application level:
- Use Open WebUI interface to interact with models
- Observe response times in the UI
- Compare performance across different models

## Customization

### Adjusting Scrape Intervals

Edit `prometheus/prometheus.yml`:
```yaml
global:
  scrape_interval: 15s  # Change to 5s for faster updates or 30s for lower overhead
```

### Adding Custom Metrics

1. Add a new exporter to `docker-compose.yml`
2. Configure the exporter endpoint
3. Add scrape configuration to `prometheus/prometheus.yml`
4. Create or modify Grafana dashboards

### Creating Custom Dashboards

1. Log into Grafana (http://localhost:3000)
2. Click "+" → "Dashboard"
3. Add panels with PromQL queries
4. Save dashboard
5. Export JSON and place in `grafana/provisioning/dashboards/`

### Setting Up Alerts (Advanced)

1. Create `prometheus/alerts.yml`:
```yaml
groups:
  - name: aixcl_alerts
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
```

2. Add to `prometheus/prometheus.yml`:
```yaml
rule_files:
  - "alerts.yml"
```

3. Configure Alertmanager (requires additional setup)

## Troubleshooting

### Prometheus Not Scraping Metrics

1. Check service health:
```bash
./aixcl status
```

2. View Prometheus targets:
http://localhost:9090/targets

3. Check container logs:
```bash
./aixcl logs prometheus
```

### Grafana Not Showing Data

1. Verify Prometheus datasource:
   - Grafana → Configuration → Data Sources
   - Test connection to Prometheus

2. Check dashboard time range (top-right corner)

3. Verify metrics exist in Prometheus:
   - Navigate to http://localhost:9090
   - Run test query: `up{job="node-exporter"}`

### High Resource Usage

If monitoring services consume too much resources:

1. Increase scrape intervals in `prometheus/prometheus.yml`
2. Reduce Prometheus retention:
```yaml
command:
  - '--storage.tsdb.retention.time=7d'  # Reduce from default 15d
```

3. Disable unused exporters in `docker-compose.yml`

### Metrics Not Available

Some metrics may not be available depending on:
- Container runtime (some cAdvisor metrics require specific permissions)
- PostgreSQL version (postgres_exporter compatibility)
- System configuration (some node_exporter metrics require host access)

## Best Practices

### Security

1. **Change Grafana Password**: Always change default password on first login
2. **Network Isolation**: Consider using a separate monitoring network in production
3. **Authentication**: Add authentication to Prometheus via reverse proxy if exposed
4. **HTTPS**: Use HTTPS for Grafana in production environments

### Performance

1. **Scrape Intervals**: Balance between data freshness and overhead
2. **Retention**: Adjust Prometheus retention based on disk space
3. **Dashboards**: Avoid too many panels on single dashboard
4. **Queries**: Use recording rules for frequently-used complex queries

### Maintenance

1. **Regular Backups**: Backup Grafana dashboards and Prometheus data
2. **Updates**: Keep monitoring stack images updated
3. **Cleanup**: Periodically review and remove unused dashboards
4. **Documentation**: Document custom metrics and alert rules

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [cAdvisor GitHub](https://github.com/google/cadvisor)
- [Node Exporter GitHub](https://github.com/prometheus/node_exporter)
- [Postgres Exporter GitHub](https://github.com/prometheus-community/postgres_exporter)

## Support

For issues or questions:
1. Check service status: `./aixcl status`
2. Review logs: `./aixcl logs <service>`
3. Verify configuration files
4. Consult official documentation

## Summary

The AIXCL monitoring stack provides comprehensive visibility into:
- ✅ System resource utilization
- ✅ Container performance
- ✅ Database health and performance
- ✅ LLM inference resource usage (indirect)

Use this monitoring data to:
- Optimize resource allocation
- Identify performance bottlenecks
- Plan capacity upgrades
- Troubleshoot issues
- Track usage patterns

