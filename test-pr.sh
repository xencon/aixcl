#!/bin/bash
# Quick PR Test Script for Enhanced Monitoring Dashboards
# Tests the datasource connection and dashboard functionality

set +e  # Don't exit on error - we want to count failures

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

echo -e "${BLUE}=== Quick PR Test - Enhanced Monitoring Dashboards ===${NC}"
echo ""

# Function to test and report
test_check() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        ((FAIL_COUNT++))
        return 1
    fi
}

echo "🔍 Service Health Checks"
echo "------------------------"
test_check "Grafana health" "curl -s http://localhost:3000/api/health | grep -q 'ok'"
test_check "Prometheus health" "curl -s http://localhost:9090/-/healthy"
test_check "cAdvisor availability" "curl -s http://localhost:8081/ | grep -q 'cAdvisor'"
echo ""

echo "🔌 Datasource Connection Tests"
echo "-------------------------------"
test_check "Prometheus datasource exists" "curl -s -u admin:admin http://localhost:3000/api/datasources | grep -q 'Prometheus'"
test_check "Datasource health check" "curl -s -u admin:admin http://localhost:3000/api/datasources/uid/PBFA97CFB590B2093/health | grep -q 'OK'"
echo ""

echo "📊 Dashboard Verification"
echo "-------------------------"
test_check "System Overview dashboard" "curl -s -u admin:admin http://localhost:3000/api/dashboards/uid/aixcl-system | grep -q 'System Overview'"
test_check "PostgreSQL dashboard" "curl -s -u admin:admin http://localhost:3000/api/dashboards/uid/aixcl-postgres | grep -q 'PostgreSQL Performance'"
test_check "Docker Containers dashboard" "curl -s -u admin:admin http://localhost:3000/api/dashboards/uid/aixcl-docker | grep -q 'Docker Containers'"
echo ""

echo "📈 System Metrics Tests"
echo "-----------------------"
test_check "CPU metrics" "curl -s 'http://localhost:9090/api/v1/query?query=node_cpu_seconds_total' | grep -q 'value'"
test_check "Memory metrics" "curl -s 'http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes' | grep -q 'value'"
test_check "Load average metrics" "curl -s 'http://localhost:9090/api/v1/query?query=node_load1' | grep -q 'value'"
test_check "Disk I/O metrics" "curl -s 'http://localhost:9090/api/v1/query?query=node_disk_read_bytes_total' | grep -q 'value'"
test_check "Network metrics" "curl -s 'http://localhost:9090/api/v1/query?query=node_network_receive_bytes_total' | grep -q 'value'"
echo ""

echo "🐳 Container Metrics Tests"
echo "--------------------------"
test_check "Container CPU metrics" "curl -s 'http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total' | grep -q 'value'"
test_check "Container memory metrics" "curl -s 'http://localhost:9090/api/v1/query?query=container_memory_usage_bytes' | grep -q 'value'"
test_check "Container disk I/O metrics" "curl -s 'http://localhost:9090/api/v1/query?query=container_fs_reads_bytes_total' | grep -q 'value'"
test_check "Container process metrics" "curl -s 'http://localhost:9090/api/v1/query?query=container_processes' | grep -q 'value'"
echo ""

echo "🗄️  Database Metrics Tests"
echo "--------------------------"
test_check "PostgreSQL status" "curl -s 'http://localhost:9090/api/v1/query?query=pg_up' | grep -q 'value'"
test_check "Database connections" "curl -s 'http://localhost:9090/api/v1/query?query=pg_stat_database_numbackends' | grep -q 'value'"
test_check "Database size" "curl -s 'http://localhost:9090/api/v1/query?query=pg_database_size_bytes' | grep -q 'value'"
test_check "Database deadlocks" "curl -s 'http://localhost:9090/api/v1/query?query=pg_stat_database_deadlocks' | grep -q 'value'"
test_check "Database block I/O" "curl -s 'http://localhost:9090/api/v1/query?query=pg_stat_database_blks_read' | grep -q 'value'"
echo ""

echo "🎯 Dashboard Query Tests"
echo "------------------------"
test_check "System Overview query" "curl -s -u admin:admin -X POST -H 'Content-Type: application/json' -d '{\"queries\":[{\"refId\":\"A\",\"datasourceId\":1,\"expr\":\"node_load1\",\"instant\":true}],\"from\":\"now-5m\",\"to\":\"now\"}' http://localhost:3000/api/ds/query | grep -q '\"status\":200'"
test_check "PostgreSQL query" "curl -s -u admin:admin -X POST -H 'Content-Type: application/json' -d '{\"queries\":[{\"refId\":\"A\",\"datasourceId\":1,\"expr\":\"pg_up\",\"instant\":true}],\"from\":\"now-5m\",\"to\":\"now\"}' http://localhost:3000/api/ds/query | grep -q '\"status\":200'"
test_check "Docker query" "curl -s -u admin:admin -X POST -H 'Content-Type: application/json' -d '{\"queries\":[{\"refId\":\"A\",\"datasourceId\":1,\"expr\":\"container_memory_usage_bytes\",\"instant\":true}],\"from\":\"now-5m\",\"to\":\"now\"}' http://localhost:3000/api/ds/query | grep -q '\"status\":200'"
echo ""

echo "📝 Documentation Tests"
echo "----------------------"
test_check "README.md updated" "grep -q '33 dashboard panels' README.md"
test_check "DATASOURCE-CONNECTION-SUMMARY.md exists" "test -f DATASOURCE-CONNECTION-SUMMARY.md"
echo ""

echo -e "${BLUE}=== Test Summary ===${NC}"
echo "-------------------"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
PASS_PERCENT=$((PASS_COUNT * 100 / TOTAL))

echo -e "Total Tests: ${BLUE}$TOTAL${NC}"
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo -e "Success Rate: ${BLUE}${PASS_PERCENT}%${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! PR is ready for review.${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed. Please review the failures above.${NC}"
    exit 1
fi

