# GitHub Issue: Integrate Loki Logging for Container Log Aggregation

## Issue Title
**Feature Request: Add Grafana Loki + Promtail for Centralized Container Log Aggregation**

## Issue Description

### Summary
Integrate Grafana Loki and Promtail into the AIXCL monitoring stack to provide centralized log aggregation and visualization for all Docker containers.

### Current State
- ✅ Prometheus metrics collection working
- ✅ Grafana dashboards for metrics visualization
- ✅ cAdvisor, Node Exporter, PostgreSQL Exporter operational
- ❌ No centralized log aggregation
- ❌ Container logs only accessible via `docker logs` command
- ❌ No log search, filtering, or correlation with metrics

### Proposed Solution
Add Grafana Loki (log aggregation) + Promtail (log collection agent) to enable:

1. **Centralized Log Storage**: All container logs in one place
2. **LogQL Queries**: Powerful log search and filtering
3. **Grafana Integration**: View logs alongside metrics
4. **7-Day Retention**: Automatic log cleanup
5. **Real-time Log Tailing**: Live log streams
6. **Log-to-Metrics Correlation**: Link logs with Prometheus metrics

### Technical Implementation

#### New Services to Add:
- **Loki** (port 3100): Log aggregation and storage
- **Promtail** (port 9080): Log collection agent

#### Key Features:
- **Automatic Discovery**: Promtail discovers all AIXCL containers
- **Label Extraction**: Container name, service, project labels
- **Efficient Storage**: Indexes metadata, not full-text content
- **Docker Integration**: Uses Docker API for container discovery
- **Retention Management**: 7-day automatic cleanup

#### Configuration Files:
- `loki/loki-config.yml` - Loki server configuration
- `promtail/promtail-config.yml` - Log collection configuration
- `grafana/provisioning/datasources/loki-datasource.yml` - Grafana integration
- `grafana/provisioning/dashboards/logs-dashboard.json` - Pre-built logs dashboard

### Benefits

#### For Developers:
- **Debug Issues**: View logs from all services in one place
- **Search Logs**: Find specific errors or patterns across containers
- **Real-time Monitoring**: Watch live logs during development
- **Historical Analysis**: Access logs from past 7 days

#### For Operations:
- **Incident Response**: Quickly correlate metrics with logs
- **Performance Analysis**: Identify bottlenecks from log patterns
- **Capacity Planning**: Monitor log volumes and patterns
- **Compliance**: Centralized log storage for auditing

#### For Users:
- **Better UX**: Faster troubleshooting and issue resolution
- **Proactive Monitoring**: Identify issues before they impact users
- **Transparency**: Clear visibility into system behavior

### Use Cases

1. **Debugging Container Issues**:
   ```logql
   {compose_service="postgres"} |~ "(?i)error|exception"
   ```

2. **Monitor Database Activity**:
   ```logql
   {compose_service="postgres"} |~ "SELECT|INSERT|UPDATE|DELETE"
   ```

3. **Track LLM Activity**:
   ```logql
   {compose_service="ollama"} |~ "(?i)loading|model|inference"
   ```

4. **System Health Monitoring**:
   ```logql
   {compose_project="aixcl"} |~ "(?i)starting|started|ready"
   ```

### Architecture

```
Docker Containers (ollama, postgres, grafana, etc.)
         │
         ↓ (Docker API Discovery)
    ┌─────────┐
    │Promtail│ ← Automatically finds all AIXCL containers
    │:9080    │   Parses logs, adds labels
    └────┬────┘
         │
         ↓ (HTTP Push)
    ┌─────────┐
    │  Loki   │ ← Stores logs (7-day retention)
    │:3100    │   Indexes labels, not content
    └────┬────┘
         │
         ↓ (LogQL Queries)
    ┌─────────┐
    │ Grafana │ ← Visualize logs + metrics
    │:3000    │   Search, filter, correlate
    └─────────┘
```

### Acceptance Criteria

- [ ] Loki service running on port 3100
- [ ] Promtail service running on port 9080
- [ ] All AIXCL containers automatically discovered by Promtail
- [ ] Loki datasource configured in Grafana
- [ ] Pre-built logs dashboard available in Grafana
- [ ] Log retention set to 7 days with automatic cleanup
- [ ] LogQL queries working for log search and filtering
- [ ] Log-to-metrics correlation via derived fields
- [ ] Documentation created for log usage and queries
- [ ] Integration with existing monitoring stack seamless

### Technical Requirements

#### Docker Compose Changes:
- Add `loki` service with health checks
- Add `promtail` service with Docker socket access
- Add `loki-data` volume for persistent storage
- Update Grafana dependency to include Loki

#### Configuration Requirements:
- Loki: 7-day retention, TSDB backend, single-instance deployment
- Promtail: Docker discovery, label extraction, efficient log shipping
- Grafana: Loki datasource, derived fields, pre-built dashboard

#### Resource Requirements:
- **Storage**: ~100MB-1GB for 7 days of logs (depending on log volume)
- **CPU**: Minimal overhead (~1-2% additional CPU usage)
- **Memory**: ~50-100MB for Loki + ~20-50MB for Promtail
- **Network**: Minimal additional traffic (local HTTP only)

### Implementation Notes

1. **Single-Instance Deployment**: Configured for single-node setup (not distributed)
2. **Docker Integration**: Uses Docker socket for container discovery
3. **Network Mode**: Host networking for simplicity and performance
4. **Health Checks**: Both services have health check endpoints
5. **Graceful Degradation**: If Loki/Promtail fail, other services continue working

### Testing Plan

1. **Service Health**: Verify Loki and Promtail start successfully
2. **Container Discovery**: Confirm all AIXCL containers are discovered
3. **Log Ingestion**: Verify logs are being stored in Loki
4. **Grafana Integration**: Test datasource connection and dashboard
5. **LogQL Queries**: Test various query patterns and filters
6. **Retention**: Verify logs are cleaned up after 7 days
7. **Performance**: Monitor resource usage and query performance

### Documentation Requirements

- [ ] Update README with logging capabilities
- [ ] Create LOGGING.md guide with LogQL examples
- [ ] Update MONITORING.md to include logging
- [ ] Add quickstart guide for log usage
- [ ] Document troubleshooting steps

### Future Enhancements

- **Log-Based Alerts**: Alert on specific log patterns
- **Log Forwarding**: Forward logs to external systems
- **Advanced Parsing**: JSON log parsing for structured logs
- **Multi-Environment**: Support for multiple environments
- **Log Sampling**: Configurable log sampling for high-volume scenarios

### Labels
- `enhancement`
- `monitoring`
- `logging`
- `grafana`
- `docker`

### Priority
**Medium** - Improves observability and debugging capabilities

### Effort Estimate
**Small-Medium** - Configuration and integration work, minimal code changes

---

## Implementation Status
- [x] Configuration files created
- [x] Docker Compose updated
- [x] Grafana provisioning configured
- [x] Pre-built dashboard created
- [x] Documentation written
- [x] Testing completed
- [ ] Ready for code review and merge

## Branch
`feature/loki-logging-integration`

## Related Issues
- Links to any related monitoring or observability issues
