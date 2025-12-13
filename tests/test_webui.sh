#!/usr/bin/env bash
# Quick script to restart and verify Open WebUI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Open WebUI Restart and Verification"
echo "=========================================="
echo ""

# Step 1: Restart the service
echo "Step 1: Restarting open-webui service..."
./aixcl service restart open-webui

echo ""
echo "Step 2: Waiting for Open WebUI to be ready..."
echo ""

# Wait for health endpoint with timeout
MAX_WAIT=60
WAIT_INTERVAL=2
elapsed=0
health_ready=false

while [ $elapsed -lt $MAX_WAIT ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        health_ready=true
        break
    fi
    
    echo "  Waiting... (${elapsed}s/${MAX_WAIT}s) - HTTP $HTTP_CODE"
    sleep $WAIT_INTERVAL
    elapsed=$((elapsed + WAIT_INTERVAL))
done

echo ""

# Step 3: Verify health endpoint
echo "Step 3: Verifying health endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Health endpoint is responding (HTTP 200)"
    
    # Get the actual health response
    HEALTH_RESPONSE=$(curl -s http://localhost:8080/health 2>/dev/null || echo "")
    if [ -n "$HEALTH_RESPONSE" ]; then
        echo "   Response: $HEALTH_RESPONSE"
    fi
else
    echo "❌ Health endpoint failed (HTTP $HTTP_CODE)"
    echo ""
    echo "Checking container logs..."
    docker logs open-webui --tail 20 2>&1 || echo "Could not retrieve logs"
    exit 1
fi

echo ""

# Step 4: Verify root endpoint
echo "Step 4: Verifying root endpoint..."
ROOT_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null || echo "000")

if [ "$ROOT_CODE" = "200" ] || [ "$ROOT_CODE" = "302" ] || [ "$ROOT_CODE" = "301" ]; then
    echo "✅ Root endpoint is responding (HTTP $ROOT_CODE)"
else
    echo "⚠️  Root endpoint returned HTTP $ROOT_CODE (may still be starting)"
fi

echo ""

# Step 5: Check container status
echo "Step 5: Checking container status..."
CONTAINER_STATUS=$(docker ps --filter "name=open-webui" --format "{{.Status}}" 2>/dev/null || echo "")

if [ -n "$CONTAINER_STATUS" ]; then
    echo "✅ Container is running: $CONTAINER_STATUS"
else
    echo "❌ Container is not running"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Open WebUI is working!"
echo "=========================================="
echo ""
echo "Access Open WebUI at: http://localhost:8080"
echo ""
