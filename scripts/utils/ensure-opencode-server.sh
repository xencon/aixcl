#!/usr/bin/env bash
# ensure-opencode-server.sh -- Idempotently ensure a persistent `opencode
# serve` process is running and print its base URL.
#
# The delegate skill attaches every delegation to this one shared server
# (`opencode run --attach <url> ...`) instead of spawning a fresh instance
# per call, so only one process ever writes to the shared
# ~/.local/share/opencode/opencode.db sqlite file.
#
# State: .opencode/server-state.json (gitignored) -- {"pid":N,"port":N,"url":"..."}
# Log:   .opencode/server.log (gitignored)
#
# Usage: URL=$(bash scripts/utils/ensure-opencode-server.sh)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

mkdir -p .opencode
STATE_FILE=".opencode/server-state.json"
LOG_FILE=".opencode/server.log"

healthy() {
    local url="$1"
    curl -sf -o /dev/null --max-time 2 "${url}/doc"
}

if [ -f "$STATE_FILE" ]; then
    pid=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['pid'])" 2>/dev/null || echo "")
    url=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['url'])" 2>/dev/null || echo "")
    if [ -n "$pid" ] && [ -n "$url" ] && kill -0 "$pid" 2>/dev/null && healthy "$url"; then
        echo "$url"
        exit 0
    fi
    rm -f "$STATE_FILE"
fi

for port in 4097 4098 4099; do
    : > "$LOG_FILE"
    nohup opencode serve --port "$port" --hostname 127.0.0.1 >> "$LOG_FILE" 2>&1 &
    pid=$!
    disown "$pid"

    url="http://127.0.0.1:${port}"
    for _ in $(seq 1 20); do
        if healthy "$url"; then
            python3 -c "import json; json.dump({'pid': $pid, 'port': $port, 'url': '$url'}, open('$STATE_FILE', 'w'))"
            echo "$url"
            exit 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 0.5
    done

    kill "$pid" 2>/dev/null || true
done

echo "ensure-opencode-server.sh: failed to start opencode serve on ports 4097-4099" >&2
exit 1
