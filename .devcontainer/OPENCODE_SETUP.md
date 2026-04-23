# OpenCode Configuration for Host -> Dev Container Connection

## Setup Complete!

Your dev container is running AIXCL with the following configuration:
- **API Endpoint**: http://localhost:11434/v1
- **Model**: qwen2.5-coder:0.5b
- **Provider**: Ollama (running in dev container)

## Host-Side OpenCode Configuration

Your `opencode.json` file in the repository root is already configured correctly:

```json
{
  "provider": {
    "aixcl-local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "AIXCL",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "qwen2.5-coder:0.5b": {
          "name": "qwen2.5-coder:0.5b"
        }
      }
    }
  },
  "model": "aixcl-local/qwen2.5-coder:0.5b"
}
```

## How to Use

### From Your Host Machine:

```bash
# Start OpenCode (it will automatically connect to localhost:11434)
cd ~/src/github.com/xencon/aixcl
opencode

# In OpenCode, test with:
# "Hello, can you confirm you're running from the dev container?"
```

### From VS Code (if using):

1. Open the project folder in VS Code on your **host**
2. The OpenCode extension will read the local `opencode.json`
3. It will connect to `localhost:11434` (which is the dev container)

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Your Host Machine (WSL2)                                     │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  OpenCode CLI                                         │ │
│  │  - Reads opencode.json                                │ │
│  │  - Connects to http://localhost:11434/v1               │ │
│  └────────────────────┬───────────────────────────────────┘ │
└───────────────────────┼─────────────────────────────────────┘
                        │
                        │ (port forwarded)
                        │
┌───────────────────────┼─────────────────────────────────────┐
│  Dev Container        │                                       │
│  ┌────────────────────▼───────────────────────────────────┐ │
│  │  AIXCL Ollama Service                                  │ │
│  │  - Listens on port 11434                               │ │
│  │  - Uses host network mode (--network=host)             │ │
│  │  - Accessible as localhost:11434 from host             │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Connection Status

✅ Dev Container: Running  
✅ AIXCL Services: Healthy (2/2)  
✅ Model Loaded: qwen2.5-coder:0.5b  
✅ API Accessible: http://localhost:11434/v1  
✅ Model Available: qwen2.5-coder:0.5b  

## Quick Test

Run this from your host to verify the connection:

```bash
# Test API directly
curl http://localhost:11434/v1/models

# Expected output:
# {"object":"list","data":[{"id":"qwen2.5-coder:0.5b",...}]}

# Test OpenCode
opencode --message "Hello from host connection"
```

## Troubleshooting

If OpenCode can't connect:

1. **Check dev container is running:**
   ```bash
   docker compose -f .devcontainer/docker-compose.dev.yml ps
   ```

2. **Check AIXCL is healthy:**
   ```bash
   docker exec devcontainer-devcontainer-1 /bin/bash -c 'cd /workspace && ./aixcl stack status'
   ```

3. **Test API from host:**
   ```bash
   curl http://localhost:11434/v1/models
   ```

4. **Restart if needed:**
   ```bash
   ./aixcl stack restart
   ```

## Next Steps

Your setup is complete! You can now:
- Use OpenCode from your host
- The dev container manages all AIXCL services
- Model persistence is handled automatically
- GPU support is available if configured
