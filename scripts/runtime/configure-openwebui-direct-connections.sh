#!/bin/bash
# Open WebUI Direct Connections Auto-Configuration Script
# This script automatically configures Open WebUI Direct Connections on startup
# for vLLM/llama.cpp engines (non-Ollama)

set -e

echo "=== Open WebUI Direct Connections Auto-Configuration ==="

# Wait for Open WebUI to be ready
echo "Waiting for Open WebUI to start..."
for i in {1..30}; do
    if curl -s http://127.0.0.1:8080/api/version >/dev/null 2>&1; then
        echo "Open WebUI is ready"
        break
    fi
    sleep 2
done

# Check if Direct Connections are already configured
echo "Checking Direct Connections configuration..."
CONFIG_RESPONSE=$(curl -s http://127.0.0.1:8080/api/v1/configs/connections 2>/dev/null || echo "")

if echo "$CONFIG_RESPONSE" | grep -q '"ENABLE_DIRECT_CONNECTIONS": true'; then
    echo "Direct Connections already enabled"
else
    echo "Enabling Direct Connections..."
    
    # Get admin token (try common credentials or use API key if available)
    # Note: This requires the admin user to be already created
    
    # Enable Direct Connections via API
    curl -s -X POST http://127.0.0.1:8080/api/v1/configs/connections \
        -H "Content-Type: application/json" \
        -d '{
            "ENABLE_DIRECT_CONNECTIONS": true,
            "ENABLE_BASE_MODELS_CACHE": false
        }' || echo "Note: Could not enable via API (may require authentication)"
fi

echo "Configuration complete"
echo ""
echo "To complete setup manually:"
echo "1. Go to http://localhost:8080/admin/settings/connections"
echo "2. Enable 'Direct Connections'"
echo "3. Add connection:"
echo "   - URL: http://127.0.0.1:11434/v1"
echo "   - Key: (leave empty for local models)"
echo "4. Save and refresh"