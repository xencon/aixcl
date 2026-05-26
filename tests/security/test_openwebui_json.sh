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
echo "Generated Payload (Escaping Test): $PAYLOAD"

# Validate using python's json.loads ensure it's valid JSON
if python3 -c "import json, sys; json.loads(sys.argv[1])" "$PAYLOAD" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS: Payload is valid JSON${NC}"
else
    echo -e "${RED}FAIL: Payload is invalid JSON${NC}"
    exit 1
fi

# Check if special characters survive JSON round-trip
# This is the correct security test: can malicious payloads be serialized to JSON
# and deserialized back to their exact original values?
parsed_email=$(python3 -c "import json, sys; print(json.loads(sys.argv[1])['email'])" "$PAYLOAD")
parsed_password=$(python3 -c "import json, sys; print(json.loads(sys.argv[1])['password'])" "$PAYLOAD")

if [ "$parsed_email" = "admin@example.com\"}" ] && [ "$parsed_password" = 'password" --payload "injection' ]; then
    echo -e "${GREEN}PASS: Special characters preserved through JSON round-trip${NC}"
else
    echo -e "${RED}FAIL: Values corrupted during JSON generation${NC}"
    echo "  Expected email:    admin@example.com\"}"
    echo "  Got email:         $parsed_email"
    echo "  Expected password: password\" --payload \"injection"
    echo "  Got password:      $parsed_password"
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
