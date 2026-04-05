# vLLM Model Download Workaround

**Issue**: vLLM container (`vllm/vllm-openai:v0.19.0`) does not include the `hf` CLI, causing `./aixcl models add` to fail.

**Error Message**:
```
[ ] 'hf' command not found in container
   Please ensure huggingface-hub is installed in the vllm container
```

---

## Workaround: Pre-download Models

Since the vLLM container doesn't have hf CLI, download models to the host first, then vLLM will pick them up from the HuggingFace cache.

### Method 1: Using Host hf CLI (Recommended)

```bash
# 1. Set engine to vLLM
./aixcl engine set vllm

# 2. Start the stack (without model first)
./aixcl stack start --profile usr

# 3. Download model to host cache using hf CLI
# The vLLM container shares the HF cache volume
hf download Qwen/Qwen2.5-Coder-0.5B-Instruct

# 4. Update docker-compose.yml to use the model
# Edit services/docker-compose.yml vLLM service command:
# command: ["--model", "Qwen/Qwen2.5-Coder-0.5B-Instruct", ...]

# 5. Restart vLLM to load the model
./aixcl stack restart
```

### Method 2: Using Python Direct Download

```bash
# If hf CLI is not available, use huggingface_hub Python library
python3 -c "from huggingface_hub import snapshot_download; snapshot_download('Qwen/Qwen2.5-Coder-0.5B-Instruct', cache_dir='~/.cache/huggingface')"
```

### Method 3: Manual Configuration

```bash
# 1. Set engine to vLLM
./aixcl engine set vllm

# 2. Manually edit services/docker-compose.yml
# Update the vllm service command to use your desired model:
# command: ["--model", "Qwen/Qwen2.5-Coder-0.5B-Instruct", "--gpu-memory-utilization", "0.8", ...]

# 3. Start stack
./aixcl stack start --profile usr
```

---

## Long-term Solutions

### Option A: Custom vLLM Image with hf CLI

Create a custom Dockerfile:

```dockerfile
FROM vllm/vllm-openai:v0.19.0

# Install huggingface-hub
RUN pip install huggingface-hub[cli]

# Set entrypoint same as base image
ENTRYPOINT ["python3", "-m", "vllm.entrypoints.openai.api_server"]
```

Build and use:
```bash
docker build -t aixcl-vllm:latest -f Dockerfile.vllm .
# Update docker-compose.yml to use aixcl-vllm:latest
```

### Option B: Volume Mount hf CLI

Modify `services/docker-compose.yml` to mount host's hf CLI:

```yaml
vllm:
  volumes:
    - /home/linuxbrew/.linuxbrew/bin/hf:/usr/local/bin/hf:ro
    - huggingface-cache:/root/.cache/huggingface
```

**Note**: Requires hf CLI to be compatible with container's architecture (Linux AMD64).

### Option C: Entrypoint Script Wrapper

Create a wrapper script that downloads the model before starting vLLM:

```bash
#!/bin/bash
# scripts/runtime/vllm-entrypoint.sh

MODEL=${VLLM_MODEL:-"Qwen/Qwen2.5-Coder-0.5B-Instruct"}

# Download model if not present
if [ ! -d "/root/.cache/huggingface/hub/models--${MODEL//\//--}" ]; then
    echo "Downloading model: $MODEL"
    # Use Python to download since hf CLI not available
    python3 -c "from huggingface_hub import snapshot_download; snapshot_download('$MODEL')"
fi

# Start vLLM
exec python3 -m vllm.entrypoints.openai.api_server "$@"
```

---

## Testing vLLM After Workaround

```bash
# 1. Verify vLLM is running
./aixcl stack status

# 2. Check if model loaded
curl -s http://localhost:11434/v1/models | jq '.data[0].id'

# 3. Test OpenCode connectivity
./opencode

# 4. In OpenCode, verify model responds
# Type: "Hello, what model are you?"
```

---

## Related Issues

- This workaround is temporary until vLLM container includes hf CLI or AIXCL implements automated model download
- See test report: `docs/operations/engine-switching-test-report.md`

---

*Last updated: 2025-01-20*
