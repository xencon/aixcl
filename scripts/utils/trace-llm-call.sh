#!/usr/bin/env bash
#
# LLM Call Tracer for AIXCL App Prototypes
#
# Usage:
#   ./scripts/utils/trace-llm-call.sh --app <name> --model <model> --prompt <text>
#   echo "prompt text" | ./scripts/utils/trace-llm-call.sh --app <name> --model <model>
#
# Calls the AIXCL inference API and appends a JSON-lines trace entry to
# logs/traces/<app>-YYYY-MM-DD.jsonl. Response text is written to stdout
# so the script can be used as a transparent wrapper in pipelines.
#
# Schema: timestamp, app, model, prompt, response, duration_ms, status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_error() { echo -e "${RED}[trace-llm-call]${NC} $1" >&2; }
log_info()  { echo -e "${GREEN}[trace-llm-call]${NC} $1" >&2; }

usage() {
    echo "Usage: $0 --app <name> --model <model> [--prompt <text>]" >&2
    echo "  --app     Application name (used for log file naming)" >&2
    echo "  --model   Model identifier (e.g. qwen2.5-coder:0.5b)" >&2
    echo "  --prompt  Prompt text; reads from stdin if omitted" >&2
    exit 1
}

APP=""
MODEL=""
PROMPT=""
API_BASE="${OLLAMA_BASE_URL:-http://localhost:11434}/v1"
TRACE_DIR="${PROJECT_DIR}/logs/traces"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)    APP="$2";    shift 2 ;;
        --model)  MODEL="$2";  shift 2 ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) log_error "Unknown argument: $1"; usage ;;
    esac
done

[[ -z "$APP" || -z "$MODEL" ]] && usage

# Read prompt from stdin if not supplied via flag
if [[ -z "$PROMPT" ]]; then
    if [[ -t 0 ]]; then
        log_error "--prompt not given and stdin is a terminal -- provide prompt text"
        usage
    fi
    PROMPT=$(cat)
fi

# Sanitize app name for use as filename component
APP_SAFE="${APP//[^a-zA-Z0-9_-]/-}"

mkdir -p "$TRACE_DIR"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TRACE_DATE=$(date -u +"%Y-%m-%d")
TRACE_FILE="${TRACE_DIR}/${APP_SAFE}-${TRACE_DATE}.jsonl"

# Build JSON payload -- use python3 to safely escape all special characters
PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({'model': sys.argv[1], 'messages': [{'role': 'user', 'content': sys.argv[2]}]}))
" "$MODEL" "$PROMPT")

# Call the API and capture HTTP status code separately
START_MS=$(date +%s%3N)
HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${API_BASE}/chat/completions" 2>/dev/null || echo -e "\nconnection_failed")
END_MS=$(date +%s%3N)
DURATION_MS=$(( END_MS - START_MS ))

HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | head -n -1)

# Determine status and extract response text
if [[ "$HTTP_CODE" == "200" ]]; then
    STATUS="ok"
    RESPONSE_TEXT=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    print(d['choices'][0]['message']['content'], end='')
except Exception as e:
    print(f'parse_error: {e}', end='')
" <<< "$RESPONSE_BODY")
elif [[ "$HTTP_CODE" == "connection_failed" ]]; then
    STATUS="connection_error"
    RESPONSE_TEXT="inference API unreachable at ${API_BASE}"
else
    STATUS="http_error_${HTTP_CODE}"
    RESPONSE_TEXT="$RESPONSE_BODY"
fi

# Append JSON-lines trace entry
python3 -c "
import json, sys
entry = {
    'timestamp':   sys.argv[1],
    'app':         sys.argv[2],
    'model':       sys.argv[3],
    'prompt':      sys.argv[4],
    'response':    sys.argv[5],
    'duration_ms': int(sys.argv[6]),
    'status':      sys.argv[7],
}
print(json.dumps(entry))
" "$TIMESTAMP" "$APP" "$MODEL" "$PROMPT" "$RESPONSE_TEXT" "$DURATION_MS" "$STATUS" >> "$TRACE_FILE"

log_info "trace written to ${TRACE_FILE}"

# Optional Loki push -- set LOKI_ENABLED=true to activate.
# LOKI_URL overrides the default endpoint (http://localhost:3100).
# Push is best-effort: failures are suppressed so the trace file remains
# the reliable primary store.
if [ "${LOKI_ENABLED:-}" = "true" ]; then
    python3 - "${LOKI_URL:-http://localhost:3100}" "$TRACE_FILE" << 'PYEOF'
import sys, json, time
try:
    import urllib.request
    loki_url, trace_file = sys.argv[1], sys.argv[2]
    with open(trace_file) as fh:
        lines = [ln for ln in fh if ln.strip()]
    if not lines:
        sys.exit(0)
    raw = lines[-1].strip()
    entry = json.loads(raw)
    stream = {"app": entry["app"], "model": entry["model"],
              "status": entry["status"], "job": "trace-llm-call"}
    nanos = str(int(time.time() * 1e9))
    body = json.dumps({
        "streams": [{"stream": stream, "values": [[nanos, raw]]}]
    }).encode()
    req = urllib.request.Request(
        loki_url.rstrip("/") + "/loki/api/v1/push",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    urllib.request.urlopen(req, timeout=2)
except Exception:
    pass
PYEOF
fi

# Surface errors but still exit cleanly so callers can inspect the trace
if [[ "$STATUS" != "ok" ]]; then
    log_error "API call failed: $STATUS"
    exit 1
fi

# Write response to stdout (transparent wrapper behaviour)
echo "$RESPONSE_TEXT"
