# AIXCL Logging Quick Start Guide

## Overview

Your AIXCL stack now includes Grafana Loki for centralized log aggregation from all Docker containers.

## Quick Start (3 Steps)

### 1. Start the Stack

```bash
cd /home/sbadakhc/src/github.com/xencon/aixcl
./aixcl start
```

### 2. Open Grafana

```bash
./aixcl dashboard
# Or navigate to: http://localhost:3000
```

### 3. View Logs

**Option A - Pre-built Dashboard:**
1. Click **Dashboards** → **Browse** → **AIXCL** folder
2. Open **AIXCL - Container Logs**
3. Use filters to select services and search logs

**Option B - Explore View (for custom queries):**
1. Click **Explore** icon (compass) in left sidebar
2. Select **Loki** from datasource dropdown
3. Try this query: `{compose_project="aixcl"}`

## Common Log Queries

Copy and paste these into Grafana Explore:

```logql
# All logs from all services
{compose_project="aixcl"}

# Logs from specific service
{compose_service="postgres"}
{compose_service="ollama"}
{compose_service="open-webui"}

# Search for errors
{compose_project="aixcl"} |~ "(?i)error"

# PostgreSQL queries
{compose_service="postgres"} |~ "SELECT|INSERT|UPDATE|DELETE"

# Ollama activity
{compose_service="ollama"} |~ "(?i)loading|model|inference"

# Authentication events
{compose_project="aixcl"} |~ "(?i)login|auth"
```

## Services Added

| Service   | Port | Purpose                     |
|-----------|------|-----------------------------|
| Loki      | 3100 | Log storage (7-day retention)|
| Promtail  | 9080 | Collects logs from containers|

## Verify Installation

```bash
# Check services are running
docker ps | grep -E 'loki|promtail'

# Check Loki health
curl http://localhost:3100/ready

# Check Promtail is collecting logs
curl http://localhost:9080/targets
```

## Configuration Files

- `loki/loki-config.yml` - Loki server config (7-day retention)
- `promtail/promtail-config.yml` - Log collection config
- `grafana/provisioning/datasources/loki-datasource.yml` - Grafana integration
- `grafana/provisioning/dashboards/logs-dashboard.json` - Pre-built dashboard

## Features

✅ Automatic discovery of all AIXCL containers  
✅ 7-day log retention with automatic cleanup  
✅ Real-time log streaming  
✅ Powerful search and filtering  
✅ Correlate logs with metrics in same UI  
✅ Pre-built dashboard for quick access  

## Documentation

- **LOGGING.md** - Comprehensive guide with examples
- **IMPLEMENTATION_SUMMARY.md** - Technical implementation details
- **MONITORING.md** - Overall monitoring documentation

## Troubleshooting

**No logs appearing?**
```bash
./aixcl logs promtail
curl http://localhost:3100/loki/api/v1/label/compose_service/values
```

**Connection error in Grafana?**
1. Go to Settings → Data Sources → Loki
2. Click "Save & Test"
3. Should see success message

## Next Steps

1. ✅ Start the stack: `./aixcl start`
2. ✅ Open Grafana: http://localhost:3000
3. ✅ Navigate to Logs dashboard
4. ✅ Try filtering by service
5. ✅ Search for specific log content
6. ✅ Explore real-time log tailing

For detailed LogQL queries and advanced features, see **LOGGING.md**.

Happy logging! 🎉

