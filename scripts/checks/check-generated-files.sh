#!/usr/bin/env bash
# Check for generated files that should not be committed
# Exit code: 0 if clean, 1 if generated files found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ERRORS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
    ((ERRORS++)) || true
}

warn() {
    echo -e "${YELLOW}WARN:${NC} $1" >&2
}

info() {
    echo -e "${GREEN}INFO:${NC} $1"
}

# Check for files matching .gitignore patterns that are committed
check_gitignore_violations() {
    info "Checking for files matching .gitignore patterns..."
    
    # Get list of tracked files that match .gitignore patterns
    local tracked_ignored
    tracked_ignored=$(git ls-files --ignored --exclude-standard 2>/dev/null || true)
    
    if [[ -n "$tracked_ignored" ]]; then
        error "Found tracked files that should be ignored:"
        echo "$tracked_ignored" | while read -r file; do
            echo "  - $file"
        done
        echo ""
        echo "To fix: git rm --cached <file>"
    fi
}

# Check for test backup directories
check_test_backups() {
    info "Checking for test backup directories..."
    
    if [[ -d "tests/.backup" ]]; then
        local backup_count
        backup_count=$(find tests/.backup -type d -name "test-*" 2>/dev/null | wc -l)
        if [[ $backup_count -gt 0 ]]; then
            error "Found $backup_count test backup directories in tests/.backup/"
            find tests/.backup -type d -name "test-*" 2>/dev/null | head -5 | while read -r dir; do
                echo "  - $dir"
            done
            echo ""
            echo "Run: rm -rf tests/.backup/test-*"
        fi
    fi
}

# Check for generated test result files
check_test_results() {
    info "Checking for generated test result files..."
    
    local result_patterns=(
        "tests/test-results.md"
        "tests/*-results.md"
        "tests/*.backup"
        "tests/.backup/*"
    )
    
    # shellcheck disable=SC2206
    for pattern in "${result_patterns[@]}"; do
        # Use glob expansion instead of ls | grep (SC2010)
        # Glob expansion is intentional here for pattern matching
        local files
        files=($pattern)
        if [[ ${#files[@]} -gt 0 && -e "${files[0]}" ]]; then
            for file in "${files[@]}"; do
                if [[ -f "$file" ]]; then
                    error "Found generated test result file: $file"
                fi
            done
        fi
    done
}

# Check for dated operations reports (older than 30 days) - DELETE not archive
check_dated_reports() {
    info "Checking for dated operations reports (lean repository policy)..."
    
    local old_reports
    old_reports=$(find docs/operations -name "*-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" -type f -mtime +30 2>/dev/null || true)
    
    if [[ -n "$old_reports" ]]; then
        error "Found dated reports (lean repository policy: DELETE, do not archive):"
        echo "$old_reports" | while read -r file; do
            echo "  - $file"
        done
        echo ""
        echo "To fix (DELETE, do not archive):"
        echo "  git rm \"$file\""
    fi
}

# Check for engine test result files
check_engine_test_results() {
    info "Checking for engine test result files..."
    
    local engine_files=(
        "ENGINE_TEST_RESULTS.md"
        "ENGINE_TEST_PLAN.md"
    )
    
    for file in "${engine_files[@]}"; do
        if [[ -f "$file" ]]; then
            # Check if it's older than 30 days
            if [[ $(find "$file" -mtime +30 2>/dev/null | wc -l) -gt 0 ]]; then
                error "Found dated engine test file (lean repository policy: DELETE): $file"
            fi
        fi
    done
}

# Check for pgadmin-data directory (should be gitignored)
check_pgadmin_data() {
    info "Checking for pgadmin-data directory..."
    
    if [[ -d "pgadmin-data" ]] && git ls-files pgadmin-data 2>/dev/null | grep -q .; then
        error "Found tracked pgadmin-data directory (should be in .gitignore)"
    fi
}

# Check for log files
check_log_files() {
    info "Checking for log files..."
    
    # Use glob expansion instead of ls | grep
    local log_files=(logs/*.log)
    if [[ -e "${log_files[0]}" ]]; then
        for file in "${log_files[@]}"; do
            if [[ -f "$file" ]] && git ls-files "$file" 2>/dev/null | grep -q .; then
                error "Found tracked log file: $file"
            fi
        done
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "Generated Files Check"
    echo "========================================"
    echo ""
    
    check_gitignore_violations
    check_test_backups
    check_test_results
    check_dated_reports
    check_engine_test_results
    check_pgadmin_data
    check_log_files
    
    echo ""
    echo "========================================"
    if [[ $ERRORS -eq 0 ]]; then
        info "No generated/stale files found - repository is clean!"
        exit 0
    else
        error "Found $ERRORS issue(s) with generated/stale files"
        echo ""
        echo "To fix:"
        echo "  1. Remove generated files: git rm --cached <file>"
        echo "  2. Clean test backups: rm -rf tests/.backup/test-*"
        echo "  3. DELETE dated reports: git rm <file> (lean repository policy)"
        exit 1
    fi
}

main "$@"
