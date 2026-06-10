# OpenCode Configuration for Host -> Dev Container Connection

## Setup Complete!

Your dev container is running AIXCL with the following configuration:
- **API Endpoint**: http://localhost:11434/v1
- **Local Model**: qwen2.5-coder:0.5b (when Ollama running)
- **Provider**: Ollama (running in dev container)

## Provider-Agnostic Note

AIXCL no longer hardcodes a default `model` in `opencode.json`. You must connect to a provider via `/connect` before working. The dev container provides a local Ollama endpoint, but you can also use any cloud provider.

## Host-Side OpenCode Configuration

Your `opencode.json` file in the repository root is configured with a local provider:

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
  }
}
```

**No `model` key is set.** Use `/connect` to select your provider.

## How to Use

### From Your Host Machine:

```bash
# Start OpenCode
cd ~/src/github.com/xencon/aixcl
opencode

# In the TUI, connect via one of:
# a) Local dev container (if running): /connect -> aixcl-local
# b) Cloud provider: /connect -> opencode, anthropic, openai, etc.

# Then test with:
# "Hello, can you confirm you're running from the dev container?"
```

### From VS Code (if using):

1. Open the project folder in VS Code on your **host**
2. The OpenCode extension will read the local `opencode.json`
3. Use `/connect` in the TUI to select the local provider (`aixcl-local`) or any cloud provider

## How It Works

```
+-------------------------------------------------------------+
|  Your Host Machine (WSL2)                                     |
|  +--------------------------------------------------------+ |
|  |  OpenCode CLI                                         | |
|  |  - Reads opencode.json                                | |
|  |  - Use /connect to select provider                    | |
|  |  - aixcl-local -> http://localhost:11434/v1            | |
|  |  - cloud providers -> remote API                      | |
|  +--------------------+-----------------------------------+ |
+-----------------------+-------------------------------------+
                        |
                        | (port forwarded, when using local)
                        |
+-----------------------+-------------------------------------+
|  Dev Container        |                                       |
|  +--------------------+-----------------------------------+ |
|  |  AIXCL Ollama Service                                  | |
|  |  - Listens on port 11434                               | |
|  |  - Uses host network mode (--network=host)             | |
|  |  - Accessible as localhost:11434 from host             | |
|  +--------------------------------------------------------+ |
+-------------------------------------------------------------+
```

## Connection Status

[x] Dev Container: Running  
[x] AIXCL Services: Healthy (2/2)  
[x] Model Loaded: qwen2.5-coder:0.5b  
[x] API Accessible: http://localhost:11434/v1  
[x] Model Available: qwen2.5-coder:0.5b  

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
