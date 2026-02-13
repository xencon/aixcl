#!/usr/bin/env bash
# Test script for Open WebUI JSON generation security (Issue #448)

SCRIPT_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
TARGET_SCRIPT="${SCRIPT_DIR}/../scripts/openwebui.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Testing security of JSON generation fallback..."

# Mock variables with special characters that would break simple string interpolation
# or cause injection if not properly escaped.
OPENWEBUI_EMAIL='admin@example.com"}'
OPENWEBUI_PASSWORD='password" --payload "injection'
export OPENWEBUI_EMAIL
export OPENWEBUI_PASSWORD

echo "Simulating Python JSON generation fallback..."

# This mocks the logic we will insert into openwebui.sh
# Note: In the real script, this runs if jq is missing.
generate_json_python() {
    python3 -c "import json, os; print(json.dumps({'email': os.environ.get('OPENWEBUI_EMAIL', ''), 'password': os.environ.get('OPENWEBUI_PASSWORD', ''), 'name': 'Admin'}))"
}

PAYLOAD=$(generate_json_python)
echo "Generated Payload (Escaping Test): $PAYLOAD"

# Validate using python's json.loads ensure it's valid JSON
if python3 -c "import json, sys; json.loads(sys.argv[1])" "$PAYLOAD" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS: Payload is valid JSON${NC}"
else
    echo -e "${RED}FAIL: Payload is invalid JSON${NC}"
    exit 1
fi

# Check if injection characters are escaped
# The email 'admin@example.com"}' should be escaped as "admin@example.com\"}"
if [[ "$PAYLOAD" == *"admin@example.com\\\"}"* ]] || [[ "$PAYLOAD" == *"admin@example.com\"}"* ]]; then
    if echo "$PAYLOAD" | grep -q 'admin@example.com\\"}'; then
       echo -e "${GREEN}PASS: Special characters escaped${NC}"
    elif echo "$PAYLOAD" | grep -q 'admin@example.com"}'; then
        echo -e "${GREEN}PASS: JSON is valid (implies escaping)${NC}"
    else
        echo -e "${RED}FAIL: Payload content mismatch${NC}"
        exit 1
    fi
else
     echo -e "${RED}FAIL: Special characters not properly handled${NC}"
     echo "Payload: $PAYLOAD"
     exit 1
fi

echo "Testing empty variables behavior (Issue: null vs empty string)..."
unset OPENWEBUI_EMAIL
unset OPENWEBUI_PASSWORD
PAYLOAD_EMPTY=$(generate_json_python)
echo "Generated Payload (Empty Test): $PAYLOAD_EMPTY"

# Verify empty strings are used, not null
if [[ "$PAYLOAD_EMPTY" == *'"email": ""'* ]] || [[ "$PAYLOAD_EMPTY" == *'"email":""'* ]]; then
    echo -e "${GREEN}PASS: Unset variables serialize to empty string${NC}"
else
    echo -e "${RED}FAIL: Unset variables serialized incorrectly (likely null)${NC}"
    echo "Payload: $PAYLOAD_EMPTY"
    exit 1
fi
