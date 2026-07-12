#!/usr/bin/env bash
# Local CI parity checks for AIXCL
# Fronts scripts/checks/* and inline CI checks so contributors and agents
# have one entry point for pre-push validation: ./aixcl checks all

# Track results for the summary table in `checks all`
CHECKS_PASSED=()
CHECKS_FAILED=()
CHECKS_SKIPPED=()

_checks_usage() {
    echo "Usage: $0 checks {all|paths|agents|elisions|generated|ascii|pins|profiles|obfuscation|yaml|compose|env|pr-refs <file>|pr-ready <pr>}"
    echo "  all              Run every check below (continues on failure, prints summary)"
    echo "  paths            Documentation relative links and stale path patterns"
    echo "  agents           .claude/ vs .opencode/ rules and skills mirror parity"
    echo "  elisions         AI-elision placeholders and suspicious mass deletions"
    echo "  generated        Tracked generated files and stale artifacts"
    echo "  pins             Container image references pinned (compose + shell code)"
    echo "  profiles         Profile configs match the 02_profiles.md contract"
    echo "  obfuscation      Shell obfuscation/injection patterns (unwaivered eval, pipe-to-shell)"
    echo "  ascii            Non-ASCII punctuation in markdown files"
    echo "  yaml             yamllint over the repository"
    echo "  compose          docker compose config validation (main + overrides)"
    echo "  env              Environment prerequisites (same as utils check-env)"
    echo "  pr-refs <file>   Issue/PR body reference style (one reference per line)"
    echo "  pr-ready <pr>    Merge-readiness gate: checkboxes, format, labels, CI state"
}

_check_run() {
    local name="$1"
    shift
    echo ""
    echo "--- checks: $name ---"
    if "$@"; then
        CHECKS_PASSED+=("$name")
        return 0
    else
        CHECKS_FAILED+=("$name")
        return 1
    fi
}

_check_skip() {
    local name="$1"
    local reason="$2"
    echo ""
    echo "--- checks: $name ---"
    echo "   Skipped: $reason"
    CHECKS_SKIPPED+=("$name")
}

_check_ascii() {
    # Mirror of the bash-ci.yml ASCII markdown check
    # Only check git-tracked markdown files to avoid gitignored third-party files (like node_modules)
    local file
    local found_issues=false

    # Iterate over only tracked markdown files. Paths from git ls-files are
    # repo-root relative, so anchor them to SCRIPT_DIR or the check passes
    # vacuously when run from another working directory.
    while IFS= read -r -d '' file; do
        if [ -f "${SCRIPT_DIR}/${file}" ]; then
            # Check for non-ASCII punctuation in each tracked file
            if grep -qP "[\x{2013}\x{2014}\x{2018}\x{2019}\x{201C}\x{201D}\x{2026}\x{00A0}]" "${SCRIPT_DIR}/${file}" 2>/dev/null; then
                if [ "$found_issues" = false ]; then
                    echo "Non-ASCII punctuation found in:"
                    found_issues=true
                fi
                echo "  $file"
            fi
        fi
    done < <(git -C "${SCRIPT_DIR}" ls-files "*.md" | tr '\n' '\0')

    if [ "$found_issues" = true ]; then
        return 1
    fi
    echo "All markdown files use ASCII-only punctuation"
    return 0
}

_check_compose() {
    local main_compose="${SCRIPT_DIR}/services/docker-compose.yml"
    "${DOCKER_BIN:-docker}" compose -f "$main_compose" config > /dev/null 2>&1 || {
        echo "Main compose file invalid: $main_compose"
        return 1
    }
    echo "Main compose file valid"

    local override
    for override in "${SCRIPT_DIR}"/services/docker-compose.*.yml; do
        [ -f "$override" ] || continue
        if "${DOCKER_BIN:-docker}" compose -f "$main_compose" -f "$override" config > /dev/null 2>&1; then
            echo "Override valid: $(basename "$override")"
        else
            echo "Override invalid: $(basename "$override")"
            return 1
        fi
    done
    return 0
}

_checks_summary() {
    echo ""
    echo "========================================"
    echo "Checks Summary"
    echo "========================================"
    local name
    for name in "${CHECKS_PASSED[@]}"; do
        echo "  ${ICON_SUCCESS:-[x]} $name"
    done
    for name in "${CHECKS_SKIPPED[@]}"; do
        echo "  ${ICON_WARNING:-[!]} $name (skipped)"
    done
    for name in "${CHECKS_FAILED[@]}"; do
        echo "  ${ICON_ERROR:-[ ]} $name FAILED"
    done
    echo ""
    if [ "${#CHECKS_FAILED[@]}" -gt 0 ]; then
        echo "${#CHECKS_FAILED[@]} check(s) failed"
        return 1
    fi
    echo "All checks passed"
    return 0
}

function checks_cmd() {
    if [[ $# -lt 1 ]]; then
        _checks_usage
        return 1
    fi

    local action="$1"
    shift

    local checks_dir="${SCRIPT_DIR}/scripts/checks"

    case "$action" in
        paths)
            bash "${checks_dir}/check-paths.sh"
            ;;
        agents)
            bash "${checks_dir}/check-agents.sh"
            ;;
        elisions)
            bash "${checks_dir}/check-ai-elisions.sh" "$@"
            ;;
        pins)
            bash "${checks_dir}/check-image-pins.sh"
            ;;
        profiles)
            bash "${checks_dir}/check-profiles.sh"
            ;;
        obfuscation)
            bash "${checks_dir}/check-obfuscation.sh"
            ;;
        generated)
            bash "${checks_dir}/check-generated-files.sh"
            ;;
        ascii)
            _check_ascii
            ;;
        yaml)
            if ! command -v yamllint > /dev/null 2>&1; then
                echo "yamllint not installed (pip install yamllint)"
                return 1
            fi
            yamllint -c "${SCRIPT_DIR}/.yamllint.yml" "${SCRIPT_DIR}"
            ;;
        compose)
            _check_compose
            ;;
        env)
            check_env
            ;;
        pr-refs)
            local body_file="${1:-}"
            if [ -z "$body_file" ] || [ ! -f "$body_file" ]; then
                echo "Usage: $0 checks pr-refs <body-file>"
                return 1
            fi
            bash "${checks_dir}/check-pr-references.sh" < "$body_file"
            ;;
        pr-ready)
            local pr_number="${1:-}"
            if [ -z "$pr_number" ]; then
                echo "Usage: $0 checks pr-ready <pr-number> [owner/repo]"
                return 1
            fi
            bash "${checks_dir}/check-pr-ready.sh" "$@"
            ;;
        all)
            CHECKS_PASSED=()
            CHECKS_FAILED=()
            CHECKS_SKIPPED=()

            _check_run "paths" bash "${checks_dir}/check-paths.sh" || true
            _check_run "agents" bash "${checks_dir}/check-agents.sh" || true
            _check_run "elisions" bash "${checks_dir}/check-ai-elisions.sh" || true
            _check_run "generated" bash "${checks_dir}/check-generated-files.sh" || true
            _check_run "ascii" _check_ascii || true
            _check_run "pins" bash "${checks_dir}/check-image-pins.sh" || true
            _check_run "profiles" bash "${checks_dir}/check-profiles.sh" || true
            _check_run "obfuscation" bash "${checks_dir}/check-obfuscation.sh" || true

            if command -v yamllint > /dev/null 2>&1; then
                _check_run "yaml" yamllint -c "${SCRIPT_DIR}/.yamllint.yml" "${SCRIPT_DIR}" || true
            else
                _check_skip "yaml" "yamllint not installed"
            fi

            if "${DOCKER_BIN:-docker}" info > /dev/null 2>&1; then
                _check_run "compose" _check_compose || true
            else
                _check_skip "compose" "container engine not available"
            fi

            _check_run "env" check_env || true

            _checks_summary
            ;;
        *)
            echo "Error: Unknown checks action '$action'"
            _checks_usage
            return 1
            ;;
    esac
}
