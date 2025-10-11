# Pull Request Test Plan: Enhanced Monitoring Dashboards

## PR Summary
- **Branch**: `feature/prometheus-grafana-monitoring`
- **Commits**: `5300724`, `aeda9b7`
- **Changes**: Connected Prometheus datasource and enhanced Grafana dashboards with 33 comprehensive monitoring panels

## Prerequisites

Before testing, ensure the following:

- [ ] All AIXCL services are running: `./aixcl status`
- [ ] Docker containers are healthy (no restarts)
- [ ] At least 10 minutes of runtime to collect baseline metrics

## Test Categories

### 1. Service Health Checks

#### 1.1 Verify All Services are Running
```bash
./aixcl status
```

**Expected Result**: All services should show as "Up" or "healthy"

Required services:
- [ ] ollama
- [ ] open-webui
- [ ] postgres
- [ ] pgadmin
- [ ] prometheus
- [ ] grafana
- [ ] cadvisor
- [ ] node-exporter
- [ ] postgres-exporter

#### 1.2 Check Prometheus Targets
```bash
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"[^"]*"'
```

**Expected Result**: All targets (except ollama) should show `"health":"up"`

- [ ] prometheus: up
- [ ] node-exporter: up
- [ ] cadvisor: up
- [ ] postgres-exporter: up
- [ ] ollama: down (expected - no /metrics endpoint)

### 2. Datasource Connection Tests

#### 2.1 Verify Grafana is Accessible
```bash
curl -s http://localhost:3000/api/health
```

**Expected Result**: 
```json
{
  "database": "ok",
  "version": "12.2.0",
  ...
}
```

- [ ] Grafana API responds successfully
- [ ] Database status is "ok"

#### 2.2 Verify Prometheus Datasource is Configured
```bash
curl -s -u admin:admin http://localhost:3000/api/datasources | grep -o '"name":"Prometheus"'
```

**Expected Result**: Output should include `"name":"Prometheus"`

- [ ] Prometheus datasource exists
- [ ] Datasource is set as default

#### 2.3 Test Datasource Connection Health
```bash
curl -s -u admin:admin http://localhost:3000/api/datasources/uid/PBFA97CFB590B2093/health
```

**Expected Result**:
```json
{
  "status": "OK",
  "message": "Successfully queried the Prometheus API."
}
```

- [ ] Datasource health check passes
- [ ] Connection to Prometheus is successful

### 3. Dashboard Verification Tests

#### 3.1 Verify All Dashboards are Loaded
```bash
curl -s -u admin:admin http://localhost:3000/api/search?type=dash-db
```

**Expected Result**: Three dashboards should be present:

- [ ] AIXCL - System Overview (uid: aixcl-system)
- [ ] AIXCL - PostgreSQL Performance (uid: aixcl-postgres)
- [ ] AIXCL - Docker Containers (uid: aixcl-docker)

#### 3.2 System Overview Dashboard - Panel Count
```bash
curl -s -u admin:admin "http://localhost:3000/api/dashboards/uid/aixcl-system" | grep -o '"title":"[^"]*"' | wc -l
```

**Expected Result**: Should return 10 (9 panels + 1 dashboard title)

Verify panels exist:
- [ ] CPU Usage
- [ ] Memory Usage
- [ ] Disk Usage
- [ ] Network I/O
- [ ] System Load Average
- [ ] Disk I/O Rate
- [ ] Network Errors and Drops
- [ ] System Uptime
- [ ] Disk IOPS

#### 3.3 PostgreSQL Performance Dashboard - Panel Count
```bash
curl -s -u admin:admin "http://localhost:3000/api/dashboards/uid/aixcl-postgres" | grep -o '"title":"[^"]*"' | wc -l
```

**Expected Result**: Should return 15 (14 panels + 1 dashboard title)

Verify panels exist:
- [ ] Active Connections
- [ ] Database Size
- [ ] Database Status
- [ ] Transaction Rate
- [ ] Query Operations Rate
- [ ] Connections by Database
- [ ] Cache Hit Ratio
- [ ] Transaction Activity
- [ ] Database Conflicts and Deadlocks
- [ ] Block I/O Statistics
- [ ] Rows Returned vs Fetched
- [ ] Block I/O Timing
- [ ] Max Connections Configured
- [ ] Temporary File Usage

#### 3.4 Docker Containers Dashboard - Panel Count
```bash
curl -s -u admin:admin "http://localhost:3000/api/dashboards/uid/aixcl-docker" | grep -o '"title":"[^"]*"' | wc -l
```

**Expected Result**: Should return 11 (10 panels + 1 dashboard title)

Verify panels exist:
- [ ] Container CPU Usage
- [ ] Container Memory Usage
- [ ] Container Network I/O
- [ ] Container Status
- [ ] Container Disk I/O
- [ ] Container Memory Usage %
- [ ] Container Restart Count
- [ ] Container Uptime
- [ ] Container Disk IOPS
- [ ] Container Processes

### 4. Metrics Data Verification

#### 4.1 System Metrics (Node Exporter)
```bash
# CPU metrics
curl -s 'http://localhost:9090/api/v1/query?query=node_cpu_seconds_total' | grep -c '"value"'

# Memory metrics
curl -s 'http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes' | grep -c '"value"'

# Load average
curl -s 'http://localhost:9090/api/v1/query?query=node_load1' | grep -c '"value"'

# Disk I/O
curl -s 'http://localhost:9090/api/v1/query?query=node_disk_read_bytes_total' | grep -c '"value"'

# Network errors
curl -s 'http://localhost:9090/api/v1/query?query=node_network_receive_errs_total' | grep -c '"value"'
```

**Expected Result**: Each command should return `1` or higher

- [ ] CPU metrics available
- [ ] Memory metrics available
- [ ] Load average metrics available
- [ ] Disk I/O metrics available
- [ ] Network error metrics available

#### 4.2 Container Metrics (cAdvisor)
```bash
# Container CPU
curl -s 'http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total' | grep -c '"value"'

# Container Memory
curl -s 'http://localhost:9090/api/v1/query?query=container_memory_usage_bytes' | grep -c '"value"'

# Container Disk I/O
curl -s 'http://localhost:9090/api/v1/query?query=container_fs_reads_bytes_total' | grep -c '"value"'

# Container processes
curl -s 'http://localhost:9090/api/v1/query?query=container_processes' | grep -c '"value"'
```

**Expected Result**: Each command should return `1` or higher

- [ ] Container CPU metrics available
- [ ] Container memory metrics available
- [ ] Container disk I/O metrics available
- [ ] Container process metrics available

#### 4.3 Database Metrics (Postgres Exporter)
```bash
# PostgreSQL status
curl -s 'http://localhost:9090/api/v1/query?query=pg_up' | grep -c '"value"'

# Active connections
curl -s 'http://localhost:9090/api/v1/query?query=pg_stat_database_numbackends' | grep -c '"value"'

# Database size
curl -s 'http://localhost:9090/api/v1/query?query=pg_database_size_bytes' | grep -c '"value"'

# Deadlocks
curl -s 'http://localhost:9090/api/v1/query?query=pg_stat_database_deadlocks' | grep -c '"value"'

# Block I/O
curl -s 'http://localhost:9090/api/v1/query?query=pg_stat_database_blks_read' | grep -c '"value"'
```

**Expected Result**: Each command should return `1` or higher

- [ ] PostgreSQL status metrics available
- [ ] Connection metrics available
- [ ] Database size metrics available
- [ ] Deadlock metrics available
- [ ] Block I/O metrics available

### 5. Dashboard Query Tests (via Grafana)

#### 5.1 Test System Overview Dashboard Query
```bash
curl -s -u admin:admin -X POST -H "Content-Type: application/json" -d '{
  "queries": [{
    "refId": "A",
    "datasourceId": 1,
    "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
    "instant": true
  }],
  "from": "now-5m",
  "to": "now"
}' http://localhost:3000/api/ds/query | grep -o '"status":[0-9]*'
```

**Expected Result**: `"status":200`

- [ ] CPU Usage query returns data

#### 5.2 Test PostgreSQL Dashboard Query
```bash
curl -s -u admin:admin -X POST -H "Content-Type: application/json" -d '{
  "queries": [{
    "refId": "A",
    "datasourceId": 1,
    "expr": "pg_stat_database_numbackends",
    "instant": true
  }],
  "from": "now-5m",
  "to": "now"
}' http://localhost:3000/api/ds/query | grep -o '"status":[0-9]*'
```

**Expected Result**: `"status":200`

- [ ] Active Connections query returns data

#### 5.3 Test Docker Dashboard Query
```bash
curl -s -u admin:admin -X POST -H "Content-Type: application/json" -d '{
  "queries": [{
    "refId": "A",
    "datasourceId": 1,
    "expr": "container_cpu_usage_seconds_total{name=~\"ollama|postgres\"}",
    "instant": true
  }],
  "from": "now-5m",
  "to": "now"
}' http://localhost:3000/api/ds/query | grep -o '"status":[0-9]*'
```

**Expected Result**: `"status":200`

- [ ] Container CPU query returns data

### 6. Visual Verification Tests (Manual)

Open Grafana at http://localhost:3000 (admin/admin) and verify:

#### 6.1 System Overview Dashboard
Navigate to: http://localhost:3000/d/aixcl-system

- [ ] Dashboard loads without errors
- [ ] All 9 panels display data (no "No Data" messages)
- [ ] Graphs show time-series data with values
- [ ] CPU Usage shows percentage between 0-100%
- [ ] Memory Usage shows actual memory consumption
- [ ] System Load Average shows 1m, 5m, 15m values
- [ ] Network I/O shows traffic in/out
- [ ] System Uptime displays correctly

#### 6.2 PostgreSQL Performance Dashboard
Navigate to: http://localhost:3000/d/aixcl-postgres

- [ ] Dashboard loads without errors
- [ ] All 14 panels display data
- [ ] Active Connections gauge shows current connections
- [ ] Database Size gauge shows size in bytes
- [ ] Database Status shows "Up" (value: 1)
- [ ] Transaction Rate shows transactions per second
- [ ] Cache Hit Ratio shows percentage
- [ ] All time-series graphs show data points

#### 6.3 Docker Containers Dashboard
Navigate to: http://localhost:3000/d/aixcl-docker

- [ ] Dashboard loads without errors
- [ ] All 10 panels display data
- [ ] Container CPU Usage shows data for all containers
- [ ] Container Memory Usage shows bytes consumed
- [ ] Container Status gauges show "Running" (value: 1)
- [ ] Container Uptime displays time since start
- [ ] All monitored containers visible (ollama, postgres, grafana, etc.)

### 7. Configuration File Tests

#### 7.1 Verify Datasource Configuration
```bash
cat /home/sbadakhc/src/github.com/xencon/aixcl/grafana/provisioning/datasources/datasource.yml
```

**Expected Result**: Should contain:
```yaml
basicAuth: false
url: http://localhost:9090
isDefault: true
```

- [ ] `basicAuth: false` is set
- [ ] URL points to correct Prometheus endpoint
- [ ] Datasource is set as default

#### 7.2 Verify Dashboard Files Exist
```bash
ls -la /home/sbadakhc/src/github.com/xencon/aixcl/grafana/provisioning/dashboards/*.json
```

**Expected Result**: Three JSON files present:

- [ ] system-overview.json exists
- [ ] postgresql-performance.json exists
- [ ] docker-containers.json exists

#### 7.3 Verify Dashboard JSON Structure
```bash
# Check panel count in each dashboard
grep -o '"id":[0-9]*' /home/sbadakhc/src/github.com/xencon/aixcl/grafana/provisioning/dashboards/system-overview.json | wc -l
```

**Expected Result**: 
- System Overview: 9 panels (IDs 1-9)
- PostgreSQL Performance: 14 panels (IDs 1-14)
- Docker Containers: 10 panels (IDs 1-10)

- [ ] System Overview has 9 panel IDs
- [ ] PostgreSQL Performance has 14 panel IDs
- [ ] Docker Containers has 10 panel IDs

### 8. Documentation Tests

#### 8.1 Verify Documentation Files Exist
```bash
ls -la /home/sbadakhc/src/github.com/xencon/aixcl/*.md
```

**Expected Result**: Files should exist:

- [ ] README.md exists and updated
- [ ] DATASOURCE-CONNECTION-SUMMARY.md exists
- [ ] MONITORING.md exists (if created)

#### 8.2 Verify README.md Updates
```bash
grep -c "33 dashboard panels" /home/sbadakhc/src/github.com/xencon/aixcl/README.md
```

**Expected Result**: Should return `1` or higher

- [ ] README mentions 33 total panels
- [ ] README lists System Overview: 9 panels
- [ ] README lists Docker Containers: 10 panels
- [ ] README lists PostgreSQL Performance: 14 panels
- [ ] README references DATASOURCE-CONNECTION-SUMMARY.md

#### 8.3 Verify Summary Documentation
```bash
cat /home/sbadakhc/src/github.com/xencon/aixcl/DATASOURCE-CONNECTION-SUMMARY.md
```

**Expected Result**: Document should contain:

- [ ] Prometheus targets status
- [ ] Datasource connection details
- [ ] Panel breakdown for each dashboard
- [ ] Access URLs and credentials
- [ ] Configuration files modified

### 9. Performance Tests

#### 9.1 Dashboard Load Time
Open each dashboard and measure load time:

- [ ] System Overview loads in < 5 seconds
- [ ] PostgreSQL Performance loads in < 5 seconds
- [ ] Docker Containers loads in < 5 seconds

#### 9.2 Query Response Time
Check Prometheus query performance:

```bash
time curl -s 'http://localhost:9090/api/v1/query?query=up' > /dev/null
```

**Expected Result**: Should complete in < 1 second

- [ ] Simple queries respond in < 1s
- [ ] Complex queries respond in < 3s

#### 9.3 Grafana Memory Usage
```bash
docker stats grafana --no-stream
```

**Expected Result**: Memory usage should be reasonable (< 500MB)

- [ ] Grafana memory usage is acceptable
- [ ] No memory leaks observed

### 10. Regression Tests

Ensure existing functionality still works:

- [ ] `./aixcl metrics` command opens Prometheus
- [ ] `./aixcl dashboard` command opens Grafana
- [ ] `./aixcl status` shows all services
- [ ] Existing dashboards still accessible
- [ ] pgAdmin still connects to database
- [ ] Open WebUI still accessible at localhost:8080

### 11. Edge Case Tests

#### 11.1 Service Restart
```bash
./aixcl restart
```

**Expected Result**: All services restart cleanly

- [ ] Services restart without errors
- [ ] Dashboards reload and display data after restart
- [ ] Metrics collection resumes immediately

#### 11.2 Dashboard Refresh
In Grafana, set dashboard refresh to 5 seconds

- [ ] Dashboards update automatically
- [ ] No errors in browser console
- [ ] Graphs continue to display new data

#### 11.3 Time Range Changes
Change time range in Grafana (last 5m, 1h, 6h, 24h)

- [ ] All panels adapt to new time range
- [ ] Data displays correctly for each range
- [ ] No "No Data" errors for recent time ranges

## Test Results Summary

### Pass/Fail Criteria

**Required for Merge**:
- All service health checks pass
- All datasource connection tests pass
- All 33 dashboard panels display data
- All metric queries return valid data
- Documentation is complete and accurate

**Total Tests**: ~100+ checkpoints

**Passed**: ___ / ___
**Failed**: ___ / ___
**Blocked**: ___ / ___

### Issues Found

| Issue # | Severity | Description | Status |
|---------|----------|-------------|--------|
|         |          |             |        |

### Reviewer Notes

_Add any additional observations, concerns, or recommendations here._

---

## Quick Test Script

For a rapid verification, run this script:

```bash
#!/bin/bash
echo "=== Quick PR Test ==="
echo ""

echo "1. Checking Grafana health..."
curl -s http://localhost:3000/api/health | grep -q "ok" && echo "✅ PASS" || echo "❌ FAIL"

echo "2. Checking Prometheus health..."
curl -s http://localhost:9090/-/healthy | grep -q "Prometheus" && echo "✅ PASS" || echo "❌ FAIL"

echo "3. Checking datasource connection..."
curl -s -u admin:admin http://localhost:3000/api/datasources | grep -q "Prometheus" && echo "✅ PASS" || echo "❌ FAIL"

echo "4. Checking System Overview dashboard..."
curl -s -u admin:admin http://localhost:3000/api/dashboards/uid/aixcl-system | grep -q "System Overview" && echo "✅ PASS" || echo "❌ FAIL"

echo "5. Checking PostgreSQL dashboard..."
curl -s -u admin:admin http://localhost:3000/api/dashboards/uid/aixcl-postgres | grep -q "PostgreSQL Performance" && echo "✅ PASS" || echo "❌ FAIL"

echo "6. Checking Docker dashboard..."
curl -s -u admin:admin http://localhost:3000/api/dashboards/uid/aixcl-docker | grep -q "Docker Containers" && echo "✅ PASS" || echo "❌ FAIL"

echo "7. Checking node metrics..."
curl -s 'http://localhost:9090/api/v1/query?query=node_load1' | grep -q "value" && echo "✅ PASS" || echo "❌ FAIL"

echo "8. Checking container metrics..."
curl -s 'http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total' | grep -q "value" && echo "✅ PASS" || echo "❌ FAIL"

echo "9. Checking postgres metrics..."
curl -s 'http://localhost:9090/api/v1/query?query=pg_up' | grep -q "value" && echo "✅ PASS" || echo "❌ FAIL"

echo ""
echo "=== Quick Test Complete ==="
```

Save this as `test-pr.sh`, make it executable with `chmod +x test-pr.sh`, and run it with `./test-pr.sh`.

