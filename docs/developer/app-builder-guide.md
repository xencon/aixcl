# App Builder Guide

This guide covers everything a developer needs to build an application on top of AIXCL.

For scaffolding a new app and wiring it into the CLI see [adding-apps.md](adding-apps.md).
For prerequisites and stack startup see [development-workflow.md](development-workflow.md).

## Inference API

AIXCL exposes an OpenAI-compatible HTTP API via Ollama at `http://localhost:11434/v1`.
No authentication is required for local development.

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:0.5b",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

List available models:

```bash
./aixcl models list
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
# Print all traces for today
cat logs/traces/my-app-$(date +%Y-%m-%d).jsonl | python3 -m json.tool

# Filter by status
grep '"status":"ok"' logs/traces/my-app-$(date +%Y-%m-%d).jsonl | wc -l

# Pretty-print the last trace entry
tail -1 logs/traces/my-app-$(date +%Y-%m-%d).jsonl | python3 -m json.tool

# Extract prompts and responses side by side
python3 - << 'EOF'
import json
with open(f"logs/traces/my-app-$(date +%Y-%m-%d).jsonl") as f:
    for line in f:
        e = json.loads(line)
        print(f"[{e['timestamp']}] {e['duration_ms']}ms {e['status']}")
        print(f"  PROMPT:   {e['prompt'][:80]}")
        print(f"  RESPONSE: {e['response'][:80]}")
EOF
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Inference API base URL |

## Non-Containerized Apps

Because the platform uses `network_mode: host`, all services are reachable on
localhost from any process running on the host -- including native Python scripts,
Node services, and Go binaries that are not yet Dockerized. No special configuration
is required to reach the inference API or the database during local development.

### Inference API (no Docker needed)

```python
import openai

client = openai.OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="unused",  # Ollama requires a non-empty value; content is ignored
)

response = client.chat.completions.create(
    model="qwen2.5-coder:0.5b",
    messages=[{"role": "user", "content": "Hello"}],
)
print(response.choices[0].message.content)
```

### Database access

Retrieve credentials for local development, then connect using any standard client:

```bash
./aixcl app secrets my-app
# Prints db-password and any other provisioned secrets
```

```python
import psycopg2, subprocess, json

# Read the provisioned password
pw = subprocess.check_output(
    ["./aixcl", "app", "secrets", "my-app", "--json"],
    text=True,
)
creds = json.loads(pw)

conn = psycopg2.connect(
    host="localhost", port=5432,
    dbname="my_app", user="my_app",
    password=creds["db-password"],
)
```

### Registering a non-Dockerized app

A non-Dockerized app can still declare a `prometheus` scrape target and register
itself so the CLI tracks it. Create a minimal `app.yaml` alongside your code:

```yaml
app:
  name: "my-app"
  version: "0.1.0"

# No services block needed for a native process

prometheus:
  targets:
    - "localhost:9000"   # port your app exposes /metrics on
  labels:
    app: "my-app"
    job: "my-app-service"
```

Register the directory:

```bash
./aixcl app register /path/to/my-app
./aixcl app provision my-app   # creates Vault secrets and Postgres DB
```

Start your process manually and Prometheus will discover its metrics endpoint
within 30 seconds.

### Minimal Dockerfile for containerizing later

When you are ready to containerize, use these patterns as a starting point:

**Python (FastAPI)**

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 9000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "9000"]
```

**Node.js**

```dockerfile
FROM node:20-slim
WORKDIR /app
COPY package*.json .
RUN npm ci --omit=dev
COPY . .
EXPOSE 9000
CMD ["node", "server.js"]
```

Mount the platform secrets volume to read provisioned credentials at runtime:

```yaml
# in your app docker-compose.yml
volumes:
  my-secrets:
    name: aixcl-app-my-app-secrets
    external: true

services:
  my-app-service:
    ...
    volumes:
      - my-secrets:/run/secrets:ro
```

Secrets are then available as files: `/run/secrets/my-app-db-password`, etc.
