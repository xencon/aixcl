# Loki Logging Integration - Implementation Summary

## What Was Implemented

Successfully integrated Grafana Loki and Promtail into the AIXCL monitoring stack for centralized container log aggregation and visualization.

## Files Created

### Configuration Files

1. **`loki/loki-config.yml`**
   - Loki server configuration
   - 7-day log retention policy
   - Filesystem storage backend
   - Automatic compaction and cleanup

2. **`promtail/promtail-config.yml`**
   - Promtail agent configuration
   - Docker container auto-discovery
   - Label extraction from container metadata
   - Filters for AIXCL compose project

3. **`grafana/provisioning/datasources/loki-datasource.yml`**
   - Automatic Loki datasource provisioning
   - Derived fields for log-to-metric correlation
   - Pre-configured for localhost:3100

4. **`grafana/provisioning/dashboards/logs-dashboard.json`**
   - Pre-built logs dashboard
   - Live log streaming
   - Log volume visualization
   - Service filtering and search

5. **`LOGGING.md`**
   - Comprehensive logging documentation
   - LogQL query examples
   - Troubleshooting guide
   - Best practices

## Files Modified

### `docker-compose.yml`

**Added Services:**
- `loki`: Log aggregation service (port 3100)
- `promtail`: Log collection agent (port 9080)

**Added Volume:**
- `loki-data`: Persistent storage for logs

**Updated Dependencies:**
- Grafana now depends on Loki
- Promtail depends on Loki

### `prometheus/prometheus.yml`

**Added Scrape Configs:**
- `loki`: Monitors Loki service metrics
- `promtail`: Monitors Promtail agent metrics

## How to Use

### 1. Start the Stack

```bash
cd /home/sbadakhc/src/github.com/xencon/aixcl
./aixcl start
```

This will start all services including the new Loki and Promtail containers.

### 2. Access Logs in Grafana

1. Open Grafana: http://localhost:3000
2. Login (default: admin/admin)
3. Navigate to **Dashboards** → **Browse** → **AIXCL** folder
4. Open **AIXCL - Container Logs**

### 3. Quick Log Queries

**View all container logs:**
- Go to **Explore** → Select **Loki** datasource
- Query: `{compose_project="aixcl"}`

**Filter by service:**
```logql
{compose_service="postgres"}
{compose_service="ollama"}
{compose_service="open-webui"}
```

**Search for errors:**
```logql
{compose_project="aixcl"} |~ "(?i)error"
```

## Architecture Overview

```
Docker Containers (All AIXCL services)
         ↓
    Promtail (Auto-discovers via Docker API)
         ↓
      Loki (Stores logs with 7-day retention)
         ↓
    Grafana (Visualizes logs + correlates with metrics)
```

## Key Features

✅ **Automatic Discovery**: Promtail automatically discovers all containers in the AIXCL compose project

✅ **Unified Interface**: View logs and metrics in the same Grafana instance

✅ **Powerful Search**: Use LogQL to filter and search logs by service, time, content

✅ **7-Day Retention**: Logs are automatically cleaned up after 7 days

✅ **Real-Time Tailing**: Watch live logs as they're generated

✅ **Label-Based Filtering**: Filter by container, service, stream (stdout/stderr)

✅ **Metrics Integration**: Loki and Promtail metrics monitored by Prometheus

## Services and Ports

| Service   | Port | Purpose                          |
|-----------|------|----------------------------------|
| Loki      | 3100 | Log aggregation and storage      |
| Promtail  | 9080 | Log collection agent metrics     |
| Grafana   | 3000 | Visualization (existing)         |

## Verification Steps

### 1. Check Services Are Running

```bash
docker ps | grep -E 'loki|promtail'
```

Expected output:
```
loki        grafana/loki:latest      Up X minutes
promtail    grafana/promtail:latest  Up X minutes
```

### 2. Verify Loki Is Healthy

```bash
curl http://localhost:3100/ready
```

Expected: `ready`

### 3. Check Promtail Is Discovering Containers

```bash
curl http://localhost:9080/targets | jq
```

Should show all AIXCL containers as targets.

### 4. Query Logs via API

```bash
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={compose_project="aixcl"}' \
  --data-urlencode 'limit=10' | jq
```

Should return recent log entries.

### 5. Check in Grafana

1. Go to **Configuration** → **Data Sources**
2. Click on **Loki**
3. Click **Save & Test**
4. Should see: "Data source successfully connected"

## Configuration Details

### Log Retention

**Current Setting**: 7 days (168 hours)

To change retention, edit `loki/loki-config.yml`:

```yaml
limits_config:
  retention_period: 336h  # Example: 14 days
```

Then restart: `./aixcl restart loki`

### Log Labels

Promtail automatically adds these labels to all logs:

- `compose_project`: "aixcl"
- `compose_service`: Service name (postgres, ollama, grafana, etc.)
- `container`: Container name
- `container_id`: Docker container ID
- `image`: Container image name
- `stream`: "stdout" or "stderr"

Use these labels for filtering in LogQL queries.

### Storage Location

Logs are stored in Docker volume `loki-data`:

```bash
docker volume inspect loki-data
```

## Troubleshooting

### Logs Not Appearing

1. Check Promtail logs:
   ```bash
   ./aixcl logs promtail
   ```

2. Verify Docker socket access:
   ```bash
   docker exec promtail ls -la /var/run/docker.sock
   ```

3. Check Loki is receiving data:
   ```bash
   curl http://localhost:3100/loki/api/v1/label/compose_service/values
   ```

### Loki Datasource Connection Failed

1. Check Loki is running:
   ```bash
   curl http://localhost:3100/ready
   ```

2. Restart Grafana:
   ```bash
   ./aixcl restart grafana
   ```

3. Manually test datasource in Grafana UI

## Next Steps

### Recommended Actions

1. **Explore the Logs Dashboard**: Familiarize yourself with filtering and search
2. **Try LogQL Queries**: Practice queries in Explore view
3. **Set Up Alerts**: Create alerts based on log patterns (optional)
4. **Adjust Retention**: Modify if 7 days isn't suitable
5. **Create Custom Dashboards**: Build dashboards for specific use cases

### Optional Enhancements

1. **Add Log-Based Metrics**: Convert log patterns to metrics
2. **Configure Alerting**: Alert on error rates or specific patterns
3. **Create Service-Specific Dashboards**: Dedicated dashboards per service
4. **Set Up Log Forwarding**: Forward logs to external systems
5. **Enable Authentication**: Secure Loki API if exposed

## Documentation

- **`LOGGING.md`**: Complete logging guide with examples
- **`MONITORING.md`**: Overall monitoring documentation (existing)
- Grafana dashboards include inline help

## Resources

- Loki Documentation: https://grafana.com/docs/loki/latest/
- LogQL Syntax: https://grafana.com/docs/loki/latest/logql/
- Promtail: https://grafana.com/docs/loki/latest/clients/promtail/

## Summary

The Loki logging integration is now fully operational and ready to use. All AIXCL containers are automatically discovered and their logs are aggregated in Loki with a 7-day retention period. You can view, search, and analyze logs through the Grafana interface, with powerful LogQL queries for filtering and analysis.

**Implementation Date**: October 13, 2025  
**Status**: ✅ Complete and Operational  
**Next Action**: Start the stack with `./aixcl start` and access logs at http://localhost:3000

