#!/usr/bin/env bash
# Test script for Open WebUI JSON generation security (Issue #448)



# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Testing security of JSON generation fallback..."

# Mock variables with special characters that would break simple string interpolation
# or cause injection if not properly escaped.
# shellcheck disable=SC2089
OPENWEBUI_EMAIL='admin@example.com"}'
# shellcheck disable=SC2089
OPENWEBUI_PASSWORD='password" --payload "injection'
# shellcheck disable=SC2090
export OPENWEBUI_EMAIL
# shellcheck disable=SC2090
export OPENWEBUI_PASSWORD

echo "Simulating Python JSON generation fallback..."

# This mocks the logic we will insert into openwebui.sh
# Note: In the real script, this runs if jq is missing.
generate_json_python() {
    python3 -c "import json, os; print(json.dumps({'email': os.environ.get('OPENWEBUI_EMAIL', ''), 'password': os.environ.get('OPENWEBUI_PASSWORD', ''), 'name': 'Admin'}))"
}

PAYLOAD=$(generate_json_python)
export PAYLOAD
echo "Generated Payload (Escaping Test): $PAYLOAD"

# Validate using python's json.loads ensure it's valid JSON
if python3 -c "import json, sys; json.loads(sys.argv[1])" "$PAYLOAD" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS: Payload is valid JSON${NC}"
else
    echo -e "${RED}FAIL: Payload is invalid JSON${NC}"
    exit 1
fi

# Check if injection characters are properly escaped in JSON
# Use Python to parse and verify the values are correctly preserved
VERIFY_RESULT=$(python3 << 'PYEOF'
import json
import sys
import os

payload_str = os.environ.get('PAYLOAD')
try:
    obj = json.loads(payload_str)
    email = obj.get('email', '')
    password = obj.get('password', '')
    
    # Verify the original values were preserved correctly
    expected_email = 'admin@example.com"}'
    expected_password = 'password" --payload "injection'
    
    if email == expected_email and password == expected_password:
        print("0")
        sys.exit(0)
    else:
        print(f"Email mismatch: got '{email}', expected '{expected_email}'")
        print(f"Password mismatch: got '{password}', expected '{expected_password}'")
        sys.exit(1)
except Exception as e:
    print(f"JSON parsing error: {e}")
    sys.exit(1)
PYEOF
)

VERIFY_EXIT=$?

if [ $VERIFY_EXIT -eq 0 ]; then
    echo -e "${GREEN}PASS: Special characters properly escaped${NC}"
else
    echo -e "${RED}FAIL: Special characters not properly handled${NC}"
    echo "Debug output: $VERIFY_RESULT"
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
