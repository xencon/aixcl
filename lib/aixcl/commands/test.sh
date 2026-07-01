#!/usr/bin/env bash
# Test runner front-end for AIXCL
# Fronts tests/run-tests.sh and tests/run-security-tests.sh so the test
# suites share the single ./aixcl entry point with the rest of the platform.

_test_usage() {
    echo "Usage: $0 test {all|command|workflow|lib|apps|security} [--quick|--dry-run]"
    echo "  all        Run every suite (command, workflow, lib, apps, then security)"
    echo "  command    CLI command validation tests (needs a running stack for most)"
    echo "  workflow   README Quick Start workflow test"
    echo "  lib        Pure shell library unit tests (no stack required)"
    echo "  apps       App layer API connectivity tests (skip gracefully if stack down)"
    echo "  security   Network binding and JSON generation security tests"
    echo "  Flags: --quick skips slow model-download tests; --dry-run previews"
}

function test_cmd() {
    if [[ $# -lt 1 ]]; then
        _test_usage
        return 1
    fi

    local suite="$1"
    shift

    local runner="${SCRIPT_DIR}/tests/run-tests.sh"
    local security_runner="${SCRIPT_DIR}/tests/run-security-tests.sh"

    # Pass-through flags accepted by tests/run-tests.sh
    local flags=()
    local flag
    for flag in "$@"; do
        case "$flag" in
            --quick|--dry-run)
                flags+=("$flag")
                ;;
            *)
                echo "Error: Unknown flag '$flag'"
                _test_usage
                return 1
                ;;
        esac
    done

    case "$suite" in
        all)
            local status=0
            bash "$runner" "${flags[@]}" || status=1
            # Security tests have no dry-run mode; skip them when previewing
            if [[ ! " ${flags[*]} " =~ " --dry-run " ]]; then
                bash "$security_runner" || status=1
            fi
            return $status
            ;;
        command|workflow|lib|apps)
            bash "$runner" --category "$suite" "${flags[@]}"
            ;;
        security)
            bash "$security_runner"
            ;;
        *)
            echo "Error: Unknown test suite '$suite'"
            _test_usage
            return 1
            ;;
    esac
}
