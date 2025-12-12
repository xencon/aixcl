#!/usr/bin/env bash
# Color and icon output functions for AIXCL

# Color codes (only if output is a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Icons
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_INFO="ℹ️"
ICON_CLEAN="🧹"

# Print colored success message
print_success() {
    echo -e "${GREEN}${ICON_SUCCESS}${NC} $1"
}

# Print colored error message
print_error() {
    echo -e "${RED}${ICON_ERROR}${NC} $1" >&2
}

# Print colored warning message
print_warning() {
    echo -e "${YELLOW}${ICON_WARNING}${NC} $1"
}

# Print colored info message
print_info() {
    echo -e "${BLUE}${ICON_INFO}${NC} $1"
}

# Print clean icon message
print_clean() {
    echo -e "${GREEN}${ICON_CLEAN}${NC} $1"
}
