#!/usr/bin/env bash
# check-profiles.sh -- reconcile profile configs against the profiles contract
#
# Compares PROFILE_SERVICES in config/profiles/<profile>.env against the
# "Includes" enumeration for that profile in
# docs/architecture/governance/02_profiles.md, in both directions.
#
# Motivation (issue #1865): cAdvisor was dropped from the sys profile in
# v1.1.56 and nobody noticed for a day (#1845 restored it). `stack status`
# grades against PROFILE_SERVICES itself, so a service removed from the
# profile also vanishes from the health checklist. This check is the
# missing reconciliation between config and contract.
#
# Rules:
#   1. Every service enumerated in a profile's Includes section must appear
#      in that profile's PROFILE_SERVICES, and vice versa
#   2. $INFERENCE_ENGINE in PROFILE_SERVICES resolves to ollama
#   3. vault-agent-* sidecars and bootstraps are implementation detail and
#      exempt from the doc side
#   4. A display name in the doc with no slug mapping fails the check --
#      extend DISPLAY_TO_SLUG below when a new service is documented

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

CONTRACT="docs/architecture/governance/02_profiles.md"
PROFILE_DIR="config/profiles"
fail=0

# Display names used in 02_profiles.md -> service slugs used in
# PROFILE_SERVICES and services/docker-compose.yml
declare -A DISPLAY_TO_SLUG=(
    ["Inference Engine"]="ollama"
    ["Vault"]="vault"
    ["PostgreSQL"]="postgres"
    ["Prometheus"]="prometheus"
    ["Grafana"]="grafana"
    ["Loki"]="loki"
    ["cAdvisor"]="cadvisor"
    ["node-exporter"]="node-exporter"
    ["postgres-exporter"]="postgres-exporter"
    ["nvidia-gpu-exporter"]="nvidia-gpu-exporter"
    ["blackbox-exporter"]="blackbox-exporter"
    ["json-exporter"]="json-exporter"
    ["Alertmanager"]="alertmanager"
    ["Open WebUI"]="open-webui"
    ["pgAdmin"]="pgadmin"
)

# Print the resolved slugs enumerated under "### <profile>" ... "**Includes**:"
# in the contract, one per line. Recurses one level for "All <other> services:".
doc_services() {
    local profile="$1"
    local in_section=0 in_includes=0
    local line name rest sub

    while IFS= read -r line; do
        if [[ "$line" == "### ${profile}" ]]; then
            in_section=1
            continue
        fi
        [ "$in_section" -eq 1 ] || continue
        # Section ends at the next heading or horizontal rule
        if [[ "$line" == "---" || "$line" == "### "* || "$line" == "## "* ]]; then
            break
        fi
        if [[ "$line" == "**Includes**:"* ]]; then
            in_includes=1
            continue
        fi
        [ "$in_includes" -eq 1 ] || continue
        # Includes list ends at the next bold header (Excludes, Use Cases)
        if [[ "$line" == "**"* ]]; then
            break
        fi
        [[ "$line" == "- "* ]] || continue

        name="${line#- }"
        name="${name%% (*}"          # strip parenthetical description
        if [[ "$name" == "Runtime core:"* ]]; then
            name="${name#Runtime core: }"
        fi
        if [[ "$name" =~ ^All\ ([a-z]+)\ services:\ (.*)$ ]]; then
            # Expand "All bld services: A, B, C" from its own enumeration
            rest="${BASH_REMATCH[2]}"
            IFS=',' read -ra sub <<< "$rest"
            for name in "${sub[@]}"; do
                name="$(echo "$name" | sed 's/^ *//; s/ *$//')"
                resolve_slug "$profile" "$name"
            done
            continue
        fi
        resolve_slug "$profile" "$name"
    done < "$CONTRACT"
}

resolve_slug() {
    local profile="$1" name="$2"
    if [[ -n "${DISPLAY_TO_SLUG[$name]:-}" ]]; then
        echo "${DISPLAY_TO_SLUG[$name]}"
    else
        echo "UNMAPPED display name in ${CONTRACT} (${profile}): '${name}'" >&2
        echo "  Add it to DISPLAY_TO_SLUG in scripts/checks/check-profiles.sh" >&2
        return 1
    fi
}

# Print the slugs from PROFILE_SERVICES in the profile env file, one per
# line, with $INFERENCE_ENGINE resolved and vault-agent-* filtered out.
env_services() {
    local env_file="$1"
    local raw svc
    raw="$(grep -E '^PROFILE_SERVICES=' "$env_file" | head -1)"
    raw="${raw#PROFILE_SERVICES=}"
    raw="${raw%\"}"
    raw="${raw#\"}"
    for svc in $raw; do
        [[ "$svc" == "\$INFERENCE_ENGINE" ]] && svc="ollama"
        [[ "$svc" == vault-agent-* ]] && continue
        echo "$svc"
    done
}

for env_file in "$PROFILE_DIR"/*.env; do
    profile="$(basename "$env_file" .env)"

    if ! grep -q "^### ${profile}$" "$CONTRACT"; then
        echo "MISSING CONTRACT: no '### ${profile}' section in ${CONTRACT} for ${env_file}"
        fail=1
        continue
    fi

    if ! doc_list="$(doc_services "$profile" | sort -u)"; then
        fail=1
        continue
    fi
    env_list="$(env_services "$env_file" | sort -u)"

    missing_from_env="$(comm -23 <(echo "$doc_list") <(echo "$env_list"))"
    missing_from_doc="$(comm -13 <(echo "$doc_list") <(echo "$env_list"))"

    if [ -n "$missing_from_env" ]; then
        echo "DRIFT (${profile}): documented in ${CONTRACT} but absent from PROFILE_SERVICES in ${env_file}:"
        echo "$missing_from_env" | sed 's/^/  - /'
        fail=1
    fi
    if [ -n "$missing_from_doc" ]; then
        echo "DRIFT (${profile}): in PROFILE_SERVICES in ${env_file} but not documented in ${CONTRACT}:"
        echo "$missing_from_doc" | sed 's/^/  - /'
        fail=1
    fi
    if [ -z "$missing_from_env" ] && [ -z "$missing_from_doc" ]; then
        echo "ok: ${profile} -- $(echo "$doc_list" | wc -l | tr -d ' ') services match the contract"
    fi
done

if [ "$fail" -ne 0 ]; then
    echo ""
    echo "Profile reconciliation FAILED -- config/profiles/*.env and ${CONTRACT} disagree."
    echo "Fix whichever side is wrong; they must move together in the same PR."
    exit 1
fi
echo "All profiles match the contract"
