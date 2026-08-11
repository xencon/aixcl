#!/usr/bin/env bash
# check-opencode-models.sh -- verify OpenCode's configured models are live
#
# Derives the model list dynamically from opencode.json's own provider
# block (never a hardcoded list), always includes the configured `model`
# and `small_model` defaults, and probes each through the shared opencode
# server with a minimal bounded-timeout prompt.
#
# Catches the class of bug found in #2024: NVIDIA silently retired the
# entire deepseek-v4 family, and it was only discovered when a live
# delegation attempt failed with 410 Gone. The models.dev-backed catalog
# (`opencode models --refresh`) still listed the dead models as available
# at the time, so it cannot be trusted as a liveness source on its own --
# only an actual probe can.
#
# Design constraint: least friction to the delegation hot path. This
# script is never invoked by the delegate skill itself -- it runs
# standalone (`./aixcl checks models`) or as part of `checks all`.
#
# Exit codes:
#   0 -- configured defaults (model, small_model) are live (or check
#        skipped because opencode/server unavailable)
#   1 -- a configured default is dead or unresponsive
#
# Non-default catalog entries being dead is reported as a warning only --
# dead entries are sometimes kept deliberately as historical catalog
# records (see #2024), so they must not fail the check.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PROBE_TIMEOUT=20
CONFIG_FILE="opencode.json"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="config/opencode.json.example"
    echo "Note: live opencode.json not found, checking template config/opencode.json.example instead"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "SKIP: no opencode.json or config/opencode.json.example found"
    exit 0
fi

if ! command -v opencode > /dev/null 2>&1; then
    echo "SKIP: opencode CLI not installed"
    exit 0
fi

if ! command -v jq > /dev/null 2>&1; then
    echo "SKIP: jq not installed"
    exit 0
fi

DEFAULT_MODEL=$(jq -r '.model // empty' "$CONFIG_FILE")
SMALL_MODEL=$(jq -r '.small_model // empty' "$CONFIG_FILE")

# provider/model entries declared in the provider block, e.g.
# "nvidia/deepseek-ai/deepseek-v4-pro", "aixcl-local/qwen3-coder:30b-32k"
mapfile -t CATALOG_ENTRIES < <(
    jq -r '.provider // {} | to_entries[] | .key as $p | (.value.models // {}) | keys[] | "\($p)/\(.)"' "$CONFIG_FILE"
)

URL=$(bash "${REPO_ROOT}/scripts/utils/ensure-opencode-server.sh" 2>/dev/null) || {
    echo "SKIP: could not start or reach the shared opencode server"
    exit 0
}

ollama_reachable() {
    curl -sf -o /dev/null --max-time 2 "http://localhost:11434/v1/models" 2>/dev/null
}

OLLAMA_UP=0
if ollama_reachable; then
    OLLAMA_UP=1
fi

# entry -> "live" | "dead" | "skip" | "unknown"
declare -A STATUS
declare -A DETAIL

probe() {
    local entry="$1"
    local provider="${entry%%/*}"

    if [ "$provider" = "aixcl-local" ] && [ "$OLLAMA_UP" -ne 1 ]; then
        STATUS["$entry"]="skip"
        DETAIL["$entry"]="Ollama stack not running (never started just for this check)"
        return
    fi

    local out
    out=$(timeout -k 5 "$PROBE_TIMEOUT" opencode run --attach "$URL" --dir "$REPO_ROOT" \
        -m "$entry" 'Reply with exactly: OK' 2>&1) || true

    if echo "$out" | grep -q "410\|Gone\|end of life"; then
        STATUS["$entry"]="dead"
        DETAIL["$entry"]=$(echo "$out" | grep -o '"detail":"[^"]*"' | head -1 | sed -E 's/"detail":"(.*)"/\1/')
    elif echo "$out" | grep -qE "^Error:"; then
        STATUS["$entry"]="unknown"
        DETAIL["$entry"]=$(echo "$out" | grep "^Error:" | head -1)
    else
        STATUS["$entry"]="live"
        DETAIL["$entry"]=""
    fi
}

# Always probe the configured defaults, plus everything in the provider
# catalog (deduplicated) so the report covers the whole curated set.
ALL_ENTRIES=("${CATALOG_ENTRIES[@]}")
for extra in "$DEFAULT_MODEL" "$SMALL_MODEL"; do
    [ -z "$extra" ] && continue
    found=0
    for e in "${ALL_ENTRIES[@]}"; do
        [ "$e" = "$extra" ] && found=1 && break
    done
    [ "$found" -eq 0 ] && ALL_ENTRIES+=("$extra")
done

if [ "${#ALL_ENTRIES[@]}" -eq 0 ]; then
    echo "SKIP: no models declared in ${CONFIG_FILE}'s provider block"
    exit 0
fi

for entry in "${ALL_ENTRIES[@]}"; do
    probe "$entry"
done

echo "Model liveness (${CONFIG_FILE}, provider catalog + defaults):"
echo ""
printf '%-45s %-8s %-10s %s\n' "MODEL" "ROLE" "STATUS" "DETAIL"
fail=0
for entry in "${ALL_ENTRIES[@]}"; do
    role="catalog"
    [ "$entry" = "$DEFAULT_MODEL" ] && role="model"
    [ "$entry" = "$SMALL_MODEL" ] && role="small_model"

    st="${STATUS[$entry]}"
    detail="${DETAIL[$entry]}"
    printf '%-45s %-8s %-10s %s\n' "$entry" "$role" "$st" "$detail"

    if { [ "$entry" = "$DEFAULT_MODEL" ] || [ "$entry" = "$SMALL_MODEL" ]; } \
        && { [ "$st" = "dead" ] || [ "$st" = "unknown" ]; }; then
        fail=1
    fi
done

echo ""
if [ "$fail" -eq 1 ]; then
    echo "FAIL: configured default model or small_model is dead or unresponsive"
    echo "  Pick a replacement from any 'live' entry above, or probe a new"
    echo "  candidate with: opencode run -m <provider/model> 'Reply: OK'"
    exit 1
fi

echo "OK: configured defaults are live"
exit 0
