#!/bin/bash
# Remove old COUNCILLOR-XX entries from .env file
# This script cleans up legacy environment variable entries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found at: $ENV_FILE"
    exit 1
fi

echo "🧹 Cleaning up COUNCILLOR-XX entries from .env file..."

# Create backup
BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$ENV_FILE" "$BACKUP_FILE"
echo "✅ Created backup: $BACKUP_FILE"

# Remove all LLM Council configuration sections (including duplicates and empty sections)
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS uses BSD sed
    # Remove section header and all related comments
    sed -i '' '/^[[:space:]]*#.*LLM Council Configuration/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*#.*Chairman/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*#.*Council Members/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*#.*COUNCIL_MODELS/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*#.*CHAIRMAN_MODEL/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*#.*CHAIRMAN=/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*#.*COUNCILLOR-/d' "$ENV_FILE"
    # Remove variable assignments
    sed -i '' '/^[[:space:]]*COUNCIL_MODELS=/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*CHAIRMAN_MODEL=/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*CHAIRMAN=/d' "$ENV_FILE"
    sed -i '' '/^[[:space:]]*COUNCILLOR-/d' "$ENV_FILE"
    # Remove "Configure with" comment lines
    sed -i '' '/^[[:space:]]*#.*Configure with.*council configure/d' "$ENV_FILE"
else
    # Linux uses GNU sed
    # Remove section header and all related comments
    sed -i '/^[[:space:]]*#.*LLM Council Configuration/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*#.*Chairman/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*#.*Council Members/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*#.*COUNCIL_MODELS/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*#.*CHAIRMAN_MODEL/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*#.*CHAIRMAN=/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*#.*COUNCILLOR-/d' "$ENV_FILE"
    # Remove variable assignments
    sed -i '/^[[:space:]]*COUNCIL_MODELS=/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*CHAIRMAN_MODEL=/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*CHAIRMAN=/d' "$ENV_FILE"
    sed -i '/^[[:space:]]*COUNCILLOR-/d' "$ENV_FILE"
    # Remove "Configure with" comment lines
    sed -i '/^[[:space:]]*#.*Configure with.*council configure/d' "$ENV_FILE"
fi

# Remove consecutive blank lines (more than 1 in a row) to clean up the file
if [[ "$(uname)" == "Darwin" ]]; then
    awk 'BEGIN{blank=0} /^[[:space:]]*$/{blank++; if(blank<=1) print; next} {blank=0; print}' "$ENV_FILE" > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "$ENV_FILE"
else
    awk 'BEGIN{blank=0} /^[[:space:]]*$/{blank++; if(blank<=1) print; next} {blank=0; print}' "$ENV_FILE" > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "$ENV_FILE"
fi

echo "✅ Removed all LLM Council configuration sections from .env file"
echo ""
echo "The .env file has been cleaned. You can now run:"
echo "  ./aixcl council configure"
echo ""
echo "to add the council configuration back in the correct format."
echo "Backup saved at: $BACKUP_FILE"
