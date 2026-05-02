# Platform Engineering Assessment: AIXCL Observability

## Executive Summary

**Current State:** Basic infrastructure monitoring operational with 1,450+ metrics available. PostgreSQL exporter fixed (SSL issue resolved). Custom exporters running for Ollama and Open WebUI. 

**Critical Gap:** Dashboards exist but lack depth for platform engineering needs. Need to focus on actionable metrics.

## Available Metrics Overview

### 1. Infrastructure Metrics (Working ✅)

| Exporter | Metrics Count | Key Data | Status |
|----------|--------------|----------|---------|
| **node-exporter** | ~400 | CPU, memory, disk, network, load, filesystem | ✅ Working |
| **cAdvisor** | ~300 | Container CPU, memory, network, disk I/O | ⚠️ Partial (names need fixing) |
| **postgres-exporter** | ~200 | Connections, queries, cache, locks, replication | ✅ Working (fixed SSL) |
| **GPU exporter** | 5 | Utilization, temp, power, memory | ✅ Working (custom) |

### 2. Application Metrics (Limited ⚠️)

| Component | Exporter | Metrics Available | Status |
|-----------|----------|-------------------|---------|
| **Ollama** | Custom (port 11435) | up, version, models_loaded, model_info | ✅ Basic |
| **Open WebUI** | Custom (port 11436) | up, api_up, response_time | ⚠️ Too basic |
| **Prometheus** | Self | Storage, targets, query stats | ✅ Working |
| **Grafana** | Not scraped | - | ❌ Missing |
| **Alertmanager** | Not scraped | - | ❌ Missing |

### 3. What's Missing for Platform Engineering

#### 🔴 CRITICAL (Need Immediate Action):

1. **Ollama Inference Metrics** (High Priority)
   - Current: Only "is it up?" and "what models loaded?"
   - Missing: Inference latency, request rate, errors, queue depth
   - **Why Important:** If Ollama is slow or failing, users can't do AI work
   - **Action:** Extend exporter to query Ollama generate/chat endpoints

2. **PostgreSQL Query Performance** (Medium Priority)
   - Current: Connection counts, cache hit ratio
   - Missing: Slow queries (pg_stat_statements), table bloat, vacuum status
   - **Why Important:** Database is bottleneck for WebUI
   - **Action:** Enable pg_stat_statements extension

3. **Open WebUI User Metrics** (Medium Priority)
   - Current: HTTP response time only
   - Missing: Active sessions, request rate, error rate by endpoint
   - **Why Important:** User experience visibility
   - **Action:** WebUI has no metrics API - would need proxy/logging

4. **Container-Level Resource Allocation** (Medium Priority)
   - Current: cAdvisor shows usage but names are container IDs
   - Missing: Proper container name labels (ollama, postgres, etc.)
   - **Why Important:** Can't tell which container is using resources
   - **Action:** Fix cAdvisor labels in Podman rootless

#### 🟡 IMPORTANT (Should Add):

5. **Prometheus Storage Metrics**
   - Missing: Storage usage, retention, ingestion rate
   - Alert needed: Disk filling up

6. **Alertmanager Delivery**
   - Missing: Are alerts actually being sent?
   - Current: Prometheus fires alerts but no confirmation they arrive

7. **Loki Log Metrics**
   - Current: Running but no dashboards
   - Missing: Log volume, error rate from logs

8. **GPU Utilization by Model**
   - Current: Total GPU usage
   - Missing: Which model is using GPU, inference time per model

## Recommended Dashboard Strategy

### Dashboard 1: Platform Overview (NEW - Priority 1)
What a platform engineer needs at a glance:

**Row 1: System Health**
- CPU usage (current + trend)
- Memory usage (current + trend)
- Disk usage (current + trend)
- Load average

**Row 2: Service Status (Traffic Light Style)**
- 🔴/🟢 Prometheus, Grafana, Loki, Alertmanager
- 🔴/🟢 PostgreSQL, Ollama, Open WebUI
- 🔴/🟢 GPU Exporter, Custom Exporters

**Row 3: Critical Metrics**
- PostgreSQL connections (vs max)
- Ollama model loaded + last inference time
- GPU utilization
- Container restart count

**Row 4: Alerts Firing**
- List of active alerts with severity

### Dashboard 2: AI Platform Performance (NEW - Priority 2)

**Row 1: Ollama Performance**
- Inference requests per minute (need to add)
- Average inference latency (need to add)
- Model load time (need to add)
- GPU memory usage by model (need to add)

**Row 2: User Experience**
- Open WebUI response time
- Active sessions (need to add)
- Error rate (need to add)

**Row 3: Database Performance**
- Query rate
- Slow query count (need pg_stat_statements)
- Cache hit ratio
- Connection pool usage

### Dashboard 3: Resource Utilization (Enhance Existing)

**Current System Overview dashboard:**
- Add container-level breakdown (fix names first)
- Add GPU usage graphs
- Add disk I/O patterns
- Add network throughput

## Data Collection Priority

### Phase 1: Fix What's Broken (This Week)
1. ✅ ~~PostgreSQL exporter SSL~~ (FIXED)
2. ⚠️ Fix cAdvisor container names (rootless Podman issue)
3. ⚠️ Add Prometheus self-monitoring

### Phase 2: Application Metrics (Next Week)
1. Extend Ollama exporter:
   - Query `/api/generate` timing (need proxy/hook)
   - Track model loading time
   - Monitor request queue depth

2. Add database query monitoring:
   - Enable pg_stat_statements
   - Track slow queries

3. Add Grafana/Alertmanager scraping:
   - Basic health metrics

### Phase 3: Business Metrics (Nice to Have)
1. User session tracking
2. Model usage statistics
3. Cost per inference

## Immediate Recommendations

### 1. Fix Container Names in cAdvisor
Currently seeing:
```
container_cpu_usage_seconds_total{id="/"}
container_cpu_usage_seconds_total{id="/user.slice/..."}
```

Should see:
```
container_cpu_usage_seconds_total{name="ollama", id="..."}
container_cpu_usage_seconds_total{name="postgres", id="..."}
```

**Root Cause:** Podman rootless doesn't populate Docker labels the same way
**Solution:** Add custom labels to containers OR use systemd cgroup paths

### 2. Extend Ollama Exporter
Current implementation is too basic. Should capture:
- Request count
- Response time distribution (p50, p95, p99)
- Error rate
- Model loading events

**Technical Challenge:** Need to intercept API calls or parse logs

### 3. Add Critical Alerts
Missing alerts that should be firing:
- PostgreSQL connections > 90%
- Ollama response time > 5 seconds
- GPU temperature > 85°C
- Disk usage > 85%
- Memory usage > 90%

### 4. Documentation Gap
Need runbooks for:
- "What to do when Ollama is slow"
- "How to investigate PostgreSQL performance"
- "Interpreting GPU metrics"
- "Troubleshooting custom exporters"

## Conclusion

**Current Score: 5/10 for Platform Engineering**
- ✅ Basic infrastructure monitoring works
- ✅ All services have some visibility
- ⚠️ Container-level metrics need fixing
- ❌ Application performance metrics inadequate
- ❌ No end-to-end latency tracking
- ❌ Missing critical business metrics

**Target Score: 8/10**
Need: Better Ollama metrics, fixed container names, PostgreSQL query monitoring, and Grafana self-monitoring.

---

**Next Steps:**
1. Decide on priority: Fix container names OR extend Ollama metrics first?
2. Enable pg_stat_statements for PostgreSQL
3. Add Prometheus storage alerts
4. Create Platform Overview dashboard
