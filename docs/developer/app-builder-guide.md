# App Builder Guide

Everything a developer needs to build an application on top of AIXCL.

## Prerequisites

Before writing any app code, you need a running stack. The full system stack
(`--profile sys`) starts Ollama, Open WebUI, Vault, Postgres, pgAdmin, and
the observability services.

```bash
# One-time stack initialisation (first time only)
./aixcl stack init

# Start the full stack
./aixcl stack start --profile sys

# Verify all services are healthy
./aixcl stack status
```

If Vault sealed after a restart, unseal it before checking status:

```bash
./aixcl vault unseal
```

For platform prerequisites (Podman, GPG, gh), see [development-workflow.md](development-workflow.md).

## Inference API

AIXCL exposes an OpenAI-compatible HTTP API via Ollama at `http://localhost:11434/v1`.
No authentication is required for local development -- the API is bound to loopback only.

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:0.5b",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

The API implements the OpenAI chat completions spec. Any library or tool written against
the OpenAI API works against AIXCL by pointing `base_url` at `http://localhost:11434/v1`
with an empty or dummy API key:

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="local")
response = client.chat.completions.create(
    model="qwen2.5-coder:0.5b",
    messages=[{"role": "user", "content": "Hello"}],
)
print(response.choices[0].message.content)
```

### Authentication

| Context | Auth required |
|---------|--------------|
| Local dev (loopback) | None |
| Vault-secured deployment | `X-Vault-Token` header (obtain via `./aixcl vault credentials`) |

For local prototyping, omit any auth header. The Vault integration handles platform
secrets (database passwords, service credentials) -- it does not gate the inference API
in the default stack configuration.

## Model Selection

List models currently pulled and available:

```bash
./aixcl models list
```

Pull an additional model:

```bash
./aixcl models add qwen2.5-coder:1.5b
```

### Recommended starting models

| Model | Size | Best for |
|-------|------|----------|
| `qwen2.5-coder:0.5b` | ~400 MB | Fast iteration, connectivity tests |
| `qwen2.5-coder:1.5b` | ~1 GB | Light code tasks, low RAM |
| `qwen2.5-coder:7b` | ~4 GB | General coding tasks |

The model identifier passed to the API must exactly match what `./aixcl models list`
returns -- Ollama is case-sensitive on model names.

### Known quirks

- **Context window**: Each model has a fixed context limit. Qwen 0.5b defaults to
  32768 tokens; requests exceeding this are truncated silently. Pass `max_tokens` in
  your request to cap output length and leave headroom in the context.
- **First response latency**: The first request after a model load takes 3-10 seconds
  while Ollama warms the model into memory. Subsequent requests are fast.
  `OLLAMA_KEEP_ALIVE` (default `1800` seconds) controls how long a model stays loaded.
- **Parallel requests**: `OLLAMA_NUM_PARALLEL` (default `8`) caps concurrent in-flight
  requests per model. Prototype apps rarely hit this, but batch workloads should queue
  rather than fan out unbounded.
- **Model name vs file path**: GGUF file models (llama.cpp / vLLM) use a full path
  (`Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/...`) in the API. Ollama registry models
  use a short name. Check `.env` (`INFERENCE_MODEL`) to see what the stack loaded.

## App Code Structure

AIXCL app scaffolding lives under `apps/<name>/`. See [adding-apps.md](adding-apps.md)
for the full manifest reference and CLI commands.

For a prototype that is not yet ready to be a first-class AIXCL app, the lightest
option is a standalone script in your working directory that calls the inference API
via the tracing wrapper. No manifest, no scaffolding required.

```
your-prototype/
  main.sh          # calls trace-llm-call.sh
  prompts/         # reusable prompt templates
```

When the prototype is stable enough to register:

```bash
./aixcl app scaffold my-app
./aixcl app register ./my-app
./aixcl app start my-app
```

## LLM Output Tracing

When debugging unexpected model behaviour the first question is always "what prompt did we
send and what did the model return?" The tracing wrapper answers that without requiring any
changes to your app code.

### Design decision

Traces are stored as JSON-lines files under `logs/traces/` (one file per app per day).
The `logs/` directory is gitignored -- traces never reach the repository. A relational
store (the stack already runs Postgres) was considered but ruled out for the prototype
phase: JSON-lines requires no schema migration, is trivially grep-able, and can be
imported into Postgres later if volume justifies it.

### Usage

```bash
# Inline prompt
./scripts/utils/trace-llm-call.sh \
  --app my-app \
  --model qwen2.5-coder:0.5b \
  --prompt "Explain recursion in one sentence"

# Stdin prompt (pipeline-friendly)
echo "Explain recursion in one sentence" | \
  ./scripts/utils/trace-llm-call.sh --app my-app --model qwen2.5-coder:0.5b
```

The script prints the model response to stdout and writes a trace entry to
`logs/traces/my-app-YYYY-MM-DD.jsonl`. It can be used as a drop-in replacement for
direct `curl` calls in prototype scripts.

### Trace schema

Each line in a trace file is a JSON object:

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string (ISO 8601) | UTC time of the API call |
| `app` | string | Value passed via `--app` |
| `model` | string | Value passed via `--model` |
| `prompt` | string | Full prompt text sent to the model |
| `response` | string | Full response text returned by the model |
| `duration_ms` | integer | Round-trip time in milliseconds |
| `status` | string | `ok`, `http_error_NNN`, or `connection_error` |

### Querying traces

```bash
# Pretty-print all traces for today
cat logs/traces/my-app-$(date +%Y-%m-%d).jsonl | python3 -m json.tool

# Count successful calls
grep '"status":"ok"' logs/traces/my-app-$(date +%Y-%m-%d).jsonl | wc -l

# Print the last trace entry
tail -1 logs/traces/my-app-$(date +%Y-%m-%d).jsonl | python3 -m json.tool

# Print prompts and responses side by side
python3 - << 'EOF'
import json, sys
for line in open(sys.argv[1]):
    e = json.loads(line)
    print(f"[{e['timestamp']}] {e['duration_ms']}ms {e['status']}")
    print(f"  PROMPT:   {e['prompt'][:80]}")
    print(f"  RESPONSE: {e['response'][:80]}")
EOF logs/traces/my-app-$(date +%Y-%m-%d).jsonl
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Inference API base URL |

## Testing Your App

App tests live in `tests/apps/`. Each test file is a standalone shell script that
sources the platform test framework and skips gracefully when the stack is not running.

```bash
# Run all platform and app tests
tests/run-tests.sh

# Run app tests only
tests/run-tests.sh --category apps

# Run a single test file
bash tests/apps/test-inference-api.sh
```

### Adding a test for your app

Create `tests/apps/test-<your-app>.sh` following this pattern:

```bash
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/tests/lib/test-framework.sh"

log_test_start "test-my-app"

API_BASE="${OLLAMA_BASE_URL:-http://localhost:11434}/v1"

# Skip if stack is not reachable
if ! curl -sf --max-time 3 "http://localhost:11434" > /dev/null 2>&1; then
    log_info "SKIP: stack not running"
    exit 0
fi

# Your assertions here
assert_command_success \
    "curl -sf --max-time 10 '${API_BASE}/models'" \
    "Models endpoint reachable"

log_test_pass "my-app tests passed"
```

See `tests/apps/CONTEXT.md` for the full list of available assertion helpers and
the pattern for skipping when the stack is unavailable.

## Where Things Live

| Artifact | Path |
|----------|------|
| App manifests and code | `apps/<name>/` |
| Inference API tests | `tests/apps/` |
| Trace logs | `logs/traces/<app>-YYYY-MM-DD.jsonl` (gitignored) |
| Tracing wrapper | `scripts/utils/trace-llm-call.sh` |
| Platform test framework | `tests/lib/test-framework.sh` |
| Model recommendations | `docs/operations/model-recommendations.md` |
| Platform invariants | `docs/architecture/governance/00_invariants.md` |
