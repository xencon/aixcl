#!/usr/bin/env bash
# Logging utility functions

# Source color functions
source "${BASH_SOURCE%/*}/color.sh"

# Log levels
LOG_DEBUG=0
LOG_INFO=1
LOG_WARNING=2
LOG_ERROR=3

# Default log level
LOG_LEVEL=${LOG_LEVEL:-$LOG_INFO}

# Log a debug message
log_debug() {
    if [ $LOG_LEVEL -le $LOG_DEBUG ]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Log an info message
log_info() {
    if [ $LOG_LEVEL -le $LOG_INFO ]; then
        print_info "$*"
    fi
}

# Log a warning message
log_warning() {
    if [ $LOG_LEVEL -le $LOG_WARNING ]; then
        print_warning "$*"
    fi
}

# Log an error message
log_error() {
    if [ $LOG_LEVEL -le $LOG_ERROR ]; then
        print_error "$*"
    fi
}
