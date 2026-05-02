# AIXCL Monitoring - Next Phase Enhancements

## Current Status: 8.5/10
Platform monitoring is production-ready for rootless Podman deployment. All critical metrics are flowing and alerts are configured.

---

## Phase 2 Enhancements (Target: 9.5/10)

### 1. PostgreSQL Query Performance Tracking

**Priority:** High  
**Current Gap:** Cannot identify slow queries or query performance degradation

**Implementation:**
- Enable pg_stat_statements extension in PostgreSQL
- Add postgres_exporter queries for:
  - Top 10 slowest queries by total time
  - Query execution time percentiles (p50, p95, p99)
  - Query rate by database/table
- Add dashboard panel showing slow query trends
- Add alert: Query taking >5 seconds

**Files to Modify:**
- `scripts/db/init/` - Add pg_stat_statements extension setup
- `prometheus/alerts.yml` - Add slow query alert
- `grafana/provisioning/dashboards/AIXCL/dashboard.json` - Add query performance panel

---

### 2. Ollama Inference Latency Metrics

**Priority:** High  
**Current Gap:** No visibility into inference request duration

**Implementation Options:**

**Option A: Log Parsing (Easier)**
- Extend ollama-exporter.py to tail Ollama logs
- Parse generate/chat requests and calculate duration
- Expose: request_rate, latency_p50, latency_p95, latency_p99

**Option B: API Interception (Better)**
- Create lightweight proxy between Open WebUI and Ollama
- Measure request/response times
- Export metrics to Prometheus

**Metrics to Add:**
- ollama_inference_duration_seconds histogram
- ollama_requests_total counter
- ollama_errors_total counter
- ollama_queue_length gauge

**Files to Modify:**
- `scripts/exporters/ollama-exporter.py` - Add latency tracking
- `prometheus/alerts.yml` - Add inference latency alert (>5s)
- `grafana/provisioning/dashboards/AIXCL/dashboard.json` - Add AI performance panel

---

### 3. GPU Clock Speed Metrics

**Priority:** Medium  
**Current Gap:** Missing SM clock and memory clock speeds

**Implementation:**
- Extend GPU exporter to query:
```bash
nvidia-smi --query-gpu=clocks.sm,clocks.mem --format=csv,noheader
```
- Add metrics:
  - nvidia_smi_sm_clock_mhz
  - nvidia_smi_memory_clock_mhz
- Add to GPU dashboard as optional panels

**Files to Modify:**
- `scripts/exporters/gpu-exporter.py` - Add clock queries
- `grafana/provisioning/dashboards/AIXCL/gpu-metrics.json` - Add clock panels

---

### 4. Container Name Resolution

**Priority:** Medium  
**Current Gap:** cAdvisor shows cgroup paths instead of container names

**Issue:** Rootless Podman doesn't populate Docker-compatible labels

**Potential Solutions:**

**Option A: Podman Label Mapping**
- Create mapping script that queries Podman API
- Maps container IDs to names
- Creates recording rules in Prometheus

**Option B: Custom Container Exporter**
- Create simple exporter that exposes container metadata
- Query Podman socket for container names
- Join with cAdvisor metrics in Grafana

**Files to Create:**
- `scripts/exporters/container-labels.py` - Optional helper exporter

---

### 5. End-to-End Synthetic Monitoring

**Priority:** Medium  
**Current Gap:** No automated testing of full inference pipeline

**Implementation:**
- Create simple script that:
  1. Sends test prompt to Open WebUI API
  2. Measures total response time
  3. Reports success/failure
- Run via cron every 5 minutes
- Export metrics: synthetic_request_duration, synthetic_success
- Add alert if synthetic test fails

**Files to Create:**
- `scripts/monitoring/synthetic-test.py`
- Add systemd timer for execution

---

### 6. Business Metrics (Optional)

**Priority:** Low  
**Current Gap:** No visibility into actual platform usage

**Potential Metrics:**
- Active user sessions (from Open WebUI)
- Models usage by frequency
- Average tokens per request
- Cost per inference (if tracking GPU time)

**Implementation:**
- Would require extending Open WebUI or parsing its logs
- Could add custom metrics endpoint to WebUI

---

## Implementation Priority

### Immediate (Week 1)
1. PostgreSQL pg_stat_statements
2. Ollama inference latency (log parsing approach)

### Short-term (Week 2-3)
3. GPU clock speeds
4. Container name resolution
5. Synthetic monitoring

### Long-term (Month 2+)
6. Business metrics
7. Distributed tracing (if needed)

---

## Acceptance Criteria

**Phase 2 Complete When:**
- [ ] Can identify top 10 slowest PostgreSQL queries
- [ ] Can see Ollama inference latency trends
- [ ] Can identify which container is consuming most resources
- [ ] Get alerted if end-to-end inference pipeline fails
- [ ] Can see GPU clock speeds under load

**Target Score:** 9.5/10

---

## Notes

- All enhancements should maintain rootless Podman compatibility
- Keep custom exporters lightweight (Python HTTP servers)
- Document any new ports or configuration requirements
- Ensure alerts have actionable runbook entries
