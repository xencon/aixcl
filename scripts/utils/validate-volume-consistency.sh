#!/usr/bin/env bash
# Validate volume consistency across docker-compose files
# Ensures external volumes are properly defined

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Volume Consistency Validation"
echo "==============================="
echo ""

ERRORS=0

# Check services/docker-compose.yml
echo "Checking services/docker-compose.yml..."

# Verify external volumes are declared
for volume in aixcl-ollama-data aixcl-hf-cache aixcl-llamacpp-data aixcl-pgdata; do
  if ! grep -q "^  ${volume}:" services/docker-compose.yml; then
    echo -e "${RED}[✗]${NC} Volume ${volume} not declared in volumes section"
    ERRORS=$((ERRORS + 1))
  elif ! grep -A1 "^  ${volume}:" services/docker-compose.yml | grep -q "external: true"; then
    echo -e "${RED}[✗]${NC} Volume ${volume} not marked as external"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "${GREEN}[✓]${NC} Volume ${volume} properly configured"
  fi
done

# Check docker-compose.gpu.yml
echo ""
echo "Checking services/docker-compose.gpu.yml..."

# Check that GPU file doesn't redefine volumes (they should be external)
if [ -f "services/docker-compose.gpu.yml" ]; then
  if grep -q "^volumes:" services/docker-compose.gpu.yml; then
    echo -e "${YELLOW}[!]${NC} GPU compose has volumes section (may override base)"
  else
    echo -e "${GREEN}[✓]${NC} GPU compose uses external volumes from base"
  fi
  
  # Check that llamacpp has required configuration
  if grep -A5 "llamacpp:" services/docker-compose.gpu.yml | grep -q "entrypoint:"; then
    echo -e "${GREEN}[✓]${NC} llamacpp GPU config has entrypoint"
  else
    echo -e "${RED}[✗]${NC} llamacpp GPU config missing entrypoint"
    ERRORS=$((ERRORS + 1))
  fi
fi

# Check devcontainer compose
echo ""
echo "Checking .devcontainer/docker-compose.dev.yml..."

if [ -f ".devcontainer/docker-compose.dev.yml" ]; then
  for volume in aixcl-ollama-data aixcl-hf-cache aixcl-llamacpp-data aixcl-pgdata; do
    if ! grep -q "${volume}:" .devcontainer/docker-compose.dev.yml; then
      echo -e "${RED}[✗]${NC} Devcontainer missing volume ${volume}"
      ERRORS=$((ERRORS + 1))
    else
      echo -e "${GREEN}[✓]${NC} Devcontainer has volume ${volume}"
    fi
  done
  
  # Check volumes are marked as external (look within first 30 lines after volumes:)
  if grep -A30 "^volumes:" .devcontainer/docker-compose.dev.yml | grep -q "external: true"; then
    echo -e "${GREEN}[✓]${NC} Devcontainer volumes are external"
  else
    echo -e "${RED}[✗]${NC} Devcontainer volumes not marked as external"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo -e "${YELLOW}[!]${NC} Devcontainer compose not found (skipping)"
fi

# Summary
echo ""
echo "==============================="
if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}All volume consistency checks PASSED${NC}"
  exit 0
else
  echo -e "${RED}Volume consistency checks FAILED: ${ERRORS} errors${NC}"
  exit 1
fi
