#!/bin/bash
# Cleanup stale artifacts and generated files
# Run this periodically to keep the repository clean

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run     Show what would be removed without removing"
            echo "  --verbose     Show detailed output"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "$1"
    fi
}

dry_run_echo() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would remove: $1"
    else
        echo "Removing: $1"
    fi
}

remove_if_not_dry_run() {
    if [[ "$DRY_RUN" == false ]]; then
        rm -rf "$1"
    fi
}

REMOVED_COUNT=0

# Clean up test backup directories older than 7 days
log "Checking for old test backups..."
if [[ -d "tests/.backup" ]]; then
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]]; then
            dry_run_echo "$dir"
            remove_if_not_dry_run "$dir"
            ((REMOVED_COUNT++)) || true
        fi
    done < <(find tests/.backup -type d -name "test-*" -mtime +7 -print0 2>/dev/null || true)
fi

# Clean up old test result files older than 7 days
log "Checking for old test result files..."
while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
        dry_run_echo "$file"
        remove_if_not_dry_run "$file"
        ((REMOVED_COUNT++)) || true
    fi
done < <(find tests -name "*-results.md" -mtime +7 -print0 2>/dev/null || true)

# Clean up old log files older than 30 days
log "Checking for old log files..."
if [[ -d "logs" ]]; then
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            dry_run_echo "$file"
            remove_if_not_dry_run "$file"
            ((REMOVED_COUNT++)) || true
        fi
    done < <(find logs -name "*.log" -mtime +30 -print0 2>/dev/null || true)
fi

# Clean up empty backup directories
log "Checking for empty backup directories..."
if [[ -d "tests/.backup" ]]; then
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
            dry_run_echo "$dir (empty)"
            remove_if_not_dry_run "$dir"
            ((REMOVED_COUNT++)) || true
        fi
    done < <(find tests/.backup -type d -empty -print0 2>/dev/null || true)
fi

# Clean up dated operations reports (lean repository policy: DELETE not archive)
log "Checking for dated operations reports..."
if [[ -d "docs/operations" ]]; then
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            dry_run_echo "$file (dated operations report - lean repository policy)"
            remove_if_not_dry_run "$file"
            ((REMOVED_COUNT++)) || true
        fi
    done < <(find docs/operations -name "*-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" -type f -mtime +30 -print0 2>/dev/null || true)
fi

# Clean up dated engine test files
log "Checking for dated engine test files..."
for file in "ENGINE_TEST_RESULTS.md" "ENGINE_TEST_PLAN.md"; do
    if [[ -f "$file" ]] && [[ $(find "$file" -mtime +30 2>/dev/null | wc -l) -gt 0 ]]; then
        dry_run_echo "$file (dated engine test file - lean repository policy)"
        remove_if_not_dry_run "$file"
        ((REMOVED_COUNT++)) || true
    fi
done

echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] Would remove $REMOVED_COUNT item(s)"
    echo "Run without --dry-run to actually remove files"
else
    echo "Cleanup complete - removed $REMOVED_COUNT item(s)"
fi
