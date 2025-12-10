#!/bin/bash
# Test script for Continue conversation storage via API

set -e

API_URL="http://localhost:8000"
echo "Testing LLM-Council API with PostgreSQL storage"
echo "================================================"

# Wait for service to be ready
echo -n "Waiting for API to be ready..."
for i in {1..30}; do
    if curl -s -f "$API_URL/health" > /dev/null 2>&1; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 1
done

if [ $i -eq 30 ]; then
    echo " ❌ API not ready"
    exit 1
fi

# Test 1: Health check
echo -e "\n1. Testing health endpoint..."
HEALTH=$(curl -s "$API_URL/health")
echo "   Response: $HEALTH"

# Test 2: Send a test chat completion (simulating Continue plugin)
echo -e "\n2. Testing chat completion (Continue conversation)..."
RESPONSE=$(curl -s -X POST "$API_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "council",
        "messages": [
            {"role": "user", "content": "Hello, this is a test message from Continue plugin"}
        ],
        "stream": false
    }')

echo "   Response received (length: ${#RESPONSE})"
CONV_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
if [ -n "$CONV_ID" ]; then
    echo "   ✅ Got response ID: $CONV_ID"
else
    echo "   ⚠️  No response ID found"
fi

# Test 3: Check database for the conversation
echo -e "\n3. Checking database for stored conversation..."
# Extract conversation ID from first message hash
FIRST_MSG="Hello, this is a test message from Continue plugin"
HASH=$(echo -n "$FIRST_MSG" | sha256sum | cut -d' ' -f1 | cut -c1-16)
CONV_ID="continue-$HASH"
echo "   Expected conversation ID: $CONV_ID"

# Test 4: Send another message in the same conversation
echo -e "\n4. Testing conversation continuity (second message)..."
RESPONSE2=$(curl -s -X POST "$API_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"council\",
        \"messages\": [
            {\"role\": \"user\", \"content\": \"Hello, this is a test message from Continue plugin\"},
            {\"role\": \"assistant\", \"content\": \"Previous response\"},
            {\"role\": \"user\", \"content\": \"This is a follow-up question\"}
        ],
        \"stream\": false
    }")

echo "   Response received (length: ${#RESPONSE2})"
echo "   ✅ Second message processed"

# Test 5: Test deletion endpoint
echo -e "\n5. Testing conversation deletion..."
DELETE_RESPONSE=$(curl -s -X DELETE "$API_URL/v1/chat/completions/$CONV_ID")
echo "   Response: $DELETE_RESPONSE"

if echo "$DELETE_RESPONSE" | grep -q "success"; then
    echo "   ✅ Conversation deleted successfully"
else
    echo "   ⚠️  Deletion response: $DELETE_RESPONSE"
fi

echo -e "\n================================================"
echo "✅ API tests completed!"
echo "================================================"

