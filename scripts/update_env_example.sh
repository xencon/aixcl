#!/bin/bash
# Script to update .env.example with council configuration variables
# This ensures new installations have the correct format

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_EXAMPLE="${SCRIPT_DIR}/.env.example"

if [[ ! -f "$ENV_EXAMPLE" ]]; then
    echo "❌ .env.example file not found"
    exit 1
fi

# Check if council configuration already exists
if grep -q "^CHAIRMAN_MODEL=" "$ENV_EXAMPLE" 2>/dev/null; then
    echo "✅ Council configuration already exists in .env.example"
    exit 0
fi

# Append council configuration section
echo "" >> "$ENV_EXAMPLE"
echo "# LLM Council Configuration" >> "$ENV_EXAMPLE"
echo "# Chairman model - synthesizes final response from council members" >> "$ENV_EXAMPLE"
echo "# Configure with: ./aixcl council configure" >> "$ENV_EXAMPLE"
echo "CHAIRMAN_MODEL=" >> "$ENV_EXAMPLE"
echo "" >> "$ENV_EXAMPLE"
echo "# Council Members - Comma-separated list of models that participate in the council" >> "$ENV_EXAMPLE"
echo "# Configure with: ./aixcl council configure" >> "$ENV_EXAMPLE"
echo "COUNCIL_MODELS=" >> "$ENV_EXAMPLE"

echo "✅ Added council configuration to .env.example"
