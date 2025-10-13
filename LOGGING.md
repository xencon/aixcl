# AIXCL Logging Guide

This guide provides detailed information about the log aggregation and monitoring capabilities integrated into AIXCL using Grafana Loki and Promtail.

## Overview

AIXCL now includes a comprehensive logging stack consisting of:
- **Loki**: Log aggregation system designed by Grafana Labs
- **Promtail**: Agent that discovers and ships container logs to Loki
- **Grafana**: Unified interface for viewing logs and metrics together

## Quick Start

### Accessing Logs

1. **Start all services** (including logging stack):
   ```bash
   ./aixcl start
   ```

2. **Open Grafana**:
   ```bash
   ./aixcl dashboard
   ```
   Or navigate to: http://localhost:3000

3. **Login** with credentials (default: admin/admin)

4. **View Logs Dashboard**:
   - Click **Dashboards** → **Browse** → **AIXCL** folder
   - Select **AIXCL - Container Logs**
   - Or go directly to: http://localhost:3000/d/aixcl-logs

### Using Explore for Ad-Hoc Log Queries

1. Navigate to **Explore** (compass icon in left sidebar)
2. Select **Loki** as datasource
3. Build queries using LogQL (Loki Query Language)

## Architecture

### Log Collection Flow

```
┌──────────────────┐
│ Docker Containers│
│   (All Services) │
└────────┬─────────┘
         │
         │ Docker logs
         ▼
    ┌────────────┐
    │  Promtail  │  ──► Discovers containers automatically
    │ (port 9080)│      Parses log formats
    └─────┬──────┘      Adds labels
          │
          │ Push logs
          ▼
    ┌────────────┐
    │    Loki    │  ──► Indexes labels only
    │ (port 3100)│      Stores log chunks
    └─────┬──────┘      7-day retention
          │
          │ Query logs
          ▼
    ┌────────────┐
    │  Grafana   │  ──► Visualize logs
    │ (port 3000)│      Search and filter
    └────────────┘      Correlate with metrics
```

## Service Details

### Loki (Port 3100)

**Purpose**: Aggregates and stores logs from all containers

**Configuration**: `loki/loki-config.yml`

**Key Features**:
- 7-day retention period (configurable)
- Efficient storage - indexes only metadata, not full-text
- Horizontal scalability (single-instance for AIXCL)
- Built-in compaction and retention management
- Compatible with Prometheus-style label queries

**Storage**:
- Volume: `loki-data` (Docker volume)
- Location: `/loki` inside container
- Chunks: `/loki/chunks`
- Index: `/loki/tsdb-index`

**Retention Configuration**:
```yaml
limits_config:
  retention_period: 168h  # 7 days
compactor:
  retention_enabled: true
  retention_delete_delay: 2h
```

### Promtail (Port 9080)

**Purpose**: Discovers and ships container logs to Loki

**Configuration**: `promtail/promtail-config.yml`

**Key Features**:
- Automatic Docker container discovery
- Filters for AIXCL compose project only
- Extracts useful labels from container metadata
- Real-time log tailing
- Positions tracking (resumes from last position after restart)

**Labels Automatically Added**:
- `container`: Container name
- `container_id`: Docker container ID
- `compose_service`: Service name from docker-compose
- `compose_project`: Project name (aixcl)
- `image`: Container image name
- `stream`: stdout or stderr

**Docker Discovery**:
Promtail automatically discovers all containers with the label `com.docker.compose.project=aixcl`

## LogQL Query Language

### Basic Queries

**View all logs from all services:**
```logql
{compose_project="aixcl"}
```

**Filter by specific service:**
```logql
{compose_service="postgres"}
```

**Multiple services:**
```logql
{compose_service=~"postgres|ollama"}
```

**Exclude a service:**
```logql
{compose_service!="watchtower"}
```

**Filter by stream (stdout/stderr):**
```logql
{compose_service="postgres", stream="stderr"}
```

### Text Filtering

**Search for specific text (case-insensitive):**
```logql
{compose_service="postgres"} |~ "(?i)error"
```

**Filter lines containing "error" or "warning":**
```logql
{compose_service="postgres"} |~ "error|warning"
```

**Exclude lines containing "debug":**
```logql
{compose_service="ollama"} != "debug"
```

**Multiple filters:**
```logql
{compose_service="postgres"} |~ "SELECT" != "pg_stat"
```

### Advanced Queries

**Count logs per second by service:**
```logql
sum by (compose_service) (rate({compose_project="aixcl"}[1m]))
```

**Extract and count HTTP status codes:**
```logql
{compose_service="open-webui"} | regexp `(?P<status>\d{3})` | line_format "{{.status}}" | status != ""
```

**Calculate 95th percentile of query durations:**
```logql
quantile_over_time(0.95, 
  {compose_service="postgres"} 
  | regexp `duration: (?P<duration>\d+\.\d+) ms` 
  | unwrap duration [5m]
)
```

## Common Use Cases

### 1. Debugging Container Issues

**View recent errors from a specific service:**
```logql
{compose_service="ollama"} |~ "(?i)error|exception|fatal"
```

**Tail live logs from a service:**
- Go to Explore
- Query: `{compose_service="ollama"}`
- Enable "Live" mode (toggle in top-right)

### 2. Monitoring Database Activity

**PostgreSQL queries:**
```logql
{compose_service="postgres"} |~ "SELECT|INSERT|UPDATE|DELETE"
```

**Slow queries (over 1 second):**
```logql
{compose_service="postgres"} 
  | regexp `duration: (?P<duration>\d+\.\d+) ms` 
  | line_format "{{.duration}}ms: {{__line__}}"
  | duration > 1000
```

**Connection activity:**
```logql
{compose_service="postgres"} |~ "connection"
```

### 3. Monitoring LLM Activity

**Ollama model loading:**
```logql
{compose_service="ollama"} |~ "(?i)loading|loaded"
```

**Open-WebUI user interactions:**
```logql
{compose_service="open-webui"} |~ "POST|GET|PUT|DELETE"
```

### 4. System Health Monitoring

**Container restarts (look for startup messages):**
```logql
{compose_project="aixcl"} |~ "(?i)starting|started|ready"
```

**Health check failures:**
```logql
{compose_project="aixcl"} |~ "(?i)health|unhealthy"
```

**Resource warnings:**
```logql
{compose_project="aixcl"} |~ "(?i)memory|disk|space"
```

### 5. Security Auditing

**Authentication events:**
```logql
{compose_project="aixcl"} |~ "(?i)login|logout|auth|authentication"
```

**Failed authentication:**
```logql
{compose_project="aixcl"} |~ "(?i)failed.*auth|authentication.*failed"
```

**pgAdmin access:**
```logql
{compose_service="pgadmin"} |~ "(?i)login|access"
```

## Logs Dashboard

The **AIXCL - Container Logs** dashboard (UID: `aixcl-logs`) includes:

### Panels

1. **Container Logs** - Live log stream with filtering
   - Filter by service using dropdown
   - Search for specific text
   - View stdout/stderr
   - Color-coded log levels

2. **Log Volume by Service** - Time series showing log rate
   - Identify chatty services
   - Spot unusual activity patterns
   - Stacked area chart

3. **Total Logs** - Gauge showing total log count

4. **Active Services** - Count of services producing logs

5. **Logs by Service (Distribution)** - Pie chart
   - See which services generate most logs
   - Identify potential issues (unusual volume)

### Variables

- **Service**: Multi-select dropdown to filter by service(s)
- **Search**: Text box for log content filtering

### Using the Dashboard

1. **Select services** to view using the "Service" dropdown (multi-select)
2. **Enter search terms** in the "Search" box to filter log content
3. **Adjust time range** using the time picker (top-right)
4. **Click log lines** to expand and see full details
5. **Click "Split"** to view logs in Explore for advanced queries

## Correlating Logs with Metrics

One of the most powerful features is correlating logs with metrics from Prometheus:

### Example: Debugging High CPU Usage

1. Open **AIXCL - Docker Containers** dashboard
2. Notice high CPU usage on `ollama` container
3. Note the time range
4. Open **AIXCL - Container Logs** dashboard
5. Filter to `ollama` service
6. Set same time range
7. Look for model loading or inference activity

### Example: Database Performance Investigation

1. Open **AIXCL - PostgreSQL Performance** dashboard
2. Notice slow query rates or high connections
3. Note the time range
4. Open **Explore** → Select **Loki**
5. Query: `{compose_service="postgres"} |~ "duration"`
6. Find slow queries at that time

### Derived Fields

The Loki datasource is configured with derived fields that automatically link logs to metrics:
- Clicking on a container name in logs jumps to metrics for that container
- Enables quick navigation between logs and metrics

## Retention and Storage

### Current Configuration

- **Retention Period**: 7 days
- **Storage**: Docker volume `loki-data`
- **Compaction**: Automatic every 10 minutes
- **Deletion**: 2 hours after retention expires

### Adjusting Retention

Edit `loki/loki-config.yml`:

```yaml
limits_config:
  retention_period: 336h  # 14 days (example)

compactor:
  retention_enabled: true
  retention_delete_delay: 2h
```

Then restart Loki:
```bash
./aixcl restart loki
```

### Storage Management

**Check storage usage:**
```bash
docker volume inspect loki-data
```

**Backup logs** (before clearing):
```bash
docker run --rm -v loki-data:/data -v $(pwd)/backup:/backup \
  alpine tar czf /backup/loki-backup-$(date +%Y%m%d).tar.gz /data
```

**Clear old data** (careful - irreversible):
```bash
docker-compose down loki
docker volume rm loki-data
docker-compose up -d loki
```

## Monitoring Loki and Promtail

Both Loki and Promtail expose Prometheus metrics, which are automatically scraped:

### Loki Metrics

Available at: http://localhost:3100/metrics

**Key metrics:**
- `loki_ingester_chunks_created_total`: Chunks created
- `loki_ingester_bytes_received_total`: Bytes ingested
- `loki_request_duration_seconds`: Query performance
- `loki_panic_total`: Service health

### Promtail Metrics

Available at: http://localhost:9080/metrics

**Key metrics:**
- `promtail_sent_entries_total`: Logs sent to Loki
- `promtail_dropped_entries_total`: Logs dropped (indicates issues)
- `promtail_targets_active_total`: Active log sources
- `promtail_files_active_total`: Active log files

### Viewing in Grafana

You can create custom dashboards or queries in Prometheus:

```promql
# Rate of logs ingested by Loki
rate(loki_ingester_bytes_received_total[5m])

# Promtail targets discovered
promtail_targets_active_total
```

## Troubleshooting

### No Logs Appearing in Grafana

1. **Check Promtail is running:**
   ```bash
   ./aixcl status promtail
   ```

2. **Check Promtail logs:**
   ```bash
   ./aixcl logs promtail
   ```

3. **Verify Promtail is discovering containers:**
   ```bash
   curl http://localhost:9080/targets
   ```

4. **Check Loki is receiving logs:**
   ```bash
   curl http://localhost:3100/loki/api/v1/label/compose_service/values
   ```

5. **Verify Loki datasource in Grafana:**
   - Settings → Data Sources → Loki
   - Click "Save & Test"

### Promtail Not Discovering Containers

**Check Docker socket access:**
```bash
./aixcl logs promtail | grep "docker"
```

**Verify compose labels:**
```bash
docker inspect <container_name> | grep com.docker.compose
```

### Loki Running Out of Disk Space

1. **Check disk usage:**
   ```bash
   docker system df -v | grep loki
   ```

2. **Reduce retention period** (edit `loki/loki-config.yml`)

3. **Trigger manual compaction:**
   ```bash
   curl -X POST http://localhost:3100/loki/api/v1/delete
   ```

### Slow Log Queries

1. **Reduce time range** - query smaller time windows
2. **Add more specific label filters** - filter by service first
3. **Avoid regex when possible** - use exact matches
4. **Check Loki performance metrics** in Prometheus

### Logs Missing from Specific Container

1. **Check container is logging to stdout/stderr:**
   ```bash
   docker logs <container_name>
   ```

2. **Verify Promtail is targeting it:**
   ```bash
   curl http://localhost:9080/targets | grep <container_name>
   ```

3. **Check for label mismatches** in `promtail/promtail-config.yml`

## Best Practices

### Performance

1. **Always use label filters first** - more efficient than text search
   - Good: `{compose_service="postgres"} |~ "error"`
   - Bad: `{compose_project="aixcl"} |~ "postgres.*error"`

2. **Limit time ranges** for large queries
3. **Use LogQL aggregations** instead of large result sets
4. **Create dashboard panels** for frequently-used queries

### Query Optimization

1. **Use line filters before parsing:**
   ```logql
   {compose_service="postgres"} 
     |~ "duration" 
     | regexp `duration: (?P<dur>\d+)`
   ```

2. **Aggregate at query time** rather than storing derived metrics
3. **Use "Live" mode** for real-time debugging, not continuous monitoring

### Security

1. **Restrict access** to Grafana (change default password)
2. **Consider log retention requirements** (compliance, auditing)
3. **Be aware logs may contain sensitive data** (credentials, PII)
4. **Use network isolation** in production environments

### Maintenance

1. **Monitor Loki disk usage** regularly
2. **Backup critical logs** before retention expires
3. **Review log volumes** to identify chatty services
4. **Update Loki/Promtail images** periodically
5. **Test restore procedures** if using backups

## Integration with Existing Monitoring

The logging stack integrates seamlessly with existing AIXCL monitoring:

### Combined Workflows

1. **Alert on metric → Investigate with logs**
   - Prometheus alerts on high CPU
   - Use logs to find root cause

2. **Find error in logs → Check related metrics**
   - See errors in logs
   - Verify metrics for context

3. **Capacity planning**
   - Use metrics for trends
   - Use logs to understand patterns

### Dashboard Links

Create links between dashboards for easy navigation:
- Metrics dashboards → Logs dashboard (filtered to same service)
- Logs dashboard → Metrics dashboards (same time range)

## Advanced Features

### Log-Based Metrics

Create metrics from logs using LogQL metric queries:

```logql
# Count errors per second by service
sum by (compose_service) (
  rate({compose_project="aixcl"} |~ "(?i)error" [1m])
)
```

### Alerting on Logs

Configure alerts in Grafana based on log patterns:
1. Create LogQL query that returns metric
2. Set alert threshold
3. Configure notification channel

Example: Alert on high error rate
```logql
sum(rate({compose_project="aixcl"} |~ "(?i)error|exception" [5m])) > 1
```

### Structured Log Parsing

For JSON logs, use JSON parser:
```logql
{compose_service="open-webui"} 
  | json 
  | line_format "{{.level}}: {{.message}}"
  | level="error"
```

### Multi-Line Log Aggregation

For stack traces and multi-line logs:
```logql
{compose_service="ollama"} 
  |~ "Exception"
  | line_format "{{__timestamp__}}: {{.compose_service}}: {{__line__}}"
```

## Additional Resources

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Reference](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Grafana Explore Documentation](https://grafana.com/docs/grafana/latest/explore/)

## Summary

The AIXCL logging stack provides:

- ✅ **Centralized log aggregation** from all containers
- ✅ **7-day retention** with automatic cleanup
- ✅ **Powerful search and filtering** via LogQL
- ✅ **Seamless integration** with Prometheus metrics
- ✅ **Real-time log tailing** for debugging
- ✅ **Automatic service discovery** for Docker containers
- ✅ **Efficient storage** (indexes labels, not content)
- ✅ **Pre-built dashboard** for quick log access

### Quick Commands Reference

```bash
# View logs in terminal (traditional way)
./aixcl logs <service>

# Access Grafana logs dashboard
./aixcl dashboard  # Then navigate to Logs dashboard

# Check Loki health
curl http://localhost:3100/ready

# Check Promtail targets
curl http://localhost:9080/targets

# Query Loki API directly
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={compose_service="postgres"}' \
  --data-urlencode 'limit=10' | jq
```

Use logs to complement your metrics and gain complete observability into your AIXCL deployment!

