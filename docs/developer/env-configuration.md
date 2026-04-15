# AIXCL Environment Configuration Guide

This document explains the `.env` file configuration for AIXCL and how different engines use environment variables.

## Overview

The `.env` file is created automatically from `config/.env.example` on first run of the AIXCL CLI. It contains user-specific configuration that persists across stack restarts.

**Important**: `.env` is gitignored and should NOT be committed. Share fixes via `config/.env.example` instead.

## Configuration by Engine

### Ollama Engine

When `INFERENCE_ENGINE=ollama`:

```bash
INFERENCE_ENGINE=ollama
# INFERENCE_MODEL is ignored - Ollama manages models via its API
VLLM_MODEL=                  # Not used
LLAMACPP_MODEL=              # Not used
ENABLE_OLLAMA_API=true       # Enable Ollama-specific features
```

**Model Management**:
- Add models: `./aixcl models add qwen2.5-coder:0.5b`
- List models: `./aixcl models list`
- Ollama handles model storage internally

### vLLM Engine

When `INFERENCE_ENGINE=vllm`:

```bash
INFERENCE_ENGINE=vllm
VLLM_MODEL=Qwen/Qwen2.5-Coder-0.5B-Instruct
VLLM_ENFORCE_EAGER=true
ENABLE_OLLAMA_API=false      # Use OpenAI-compatible API
```

**Key Variables**:
- `VLLM_MODEL`: HuggingFace model path (e.g., `Qwen/Qwen2.5-Coder-0.5B-Instruct`)
- `VLLM_ENFORCE_EAGER`: Set to `true` for WSL2 compatibility
- `VLLM_GPU_MEMORY_UTILIZATION`: GPU memory fraction (0.0-1.0, default 0.8)
- `VLLM_MAX_MODEL_LEN`: Maximum context length (default 32768)

**OpenCode Configuration**:
```bash
OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=8192
```
This prevents vLLM token limit errors. Recommended: 8192 for 32K context models.

**Model Management**:
- vLLM downloads models automatically on first start
- Models cached in `huggingface-cache` Docker volume
- Change model: Edit `VLLM_MODEL` in `.env`, then `./aixcl stack restart engine`

### llama.cpp Engine

When `INFERENCE_ENGINE=llamacpp`:

```bash
INFERENCE_ENGINE=llamacpp
INFERENCE_MODEL=qwen2.5-coder-0.5b-instruct-q4_k_m.gguf
ENABLE_OLLAMA_API=false      # Use OpenAI-compatible API
```

**Key Variables**:
- `INFERENCE_MODEL`: Just the filename (e.g., `qwen2.5-coder-0.5b-instruct-q4_k_m.gguf`)
- Model file must be in `llamacpp-data` Docker volume

**Model Management**:
- Add models: `./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf`
- CLI downloads GGUF and places it in the volume
- Entrypoint creates symlink for full HuggingFace path compatibility

## Common Configuration Sections

### Profile Selection

```bash
PROFILE=usr              # Options: usr, dev, ops, sys
```

- `usr`: Minimal (runtime + database)
- `dev`: Development (adds Open WebUI)
- `ops`: Observability (adds monitoring)
- `sys`: Full deployment (all services)

### Database Configuration

```bash
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin
POSTGRES_DATABASE=webui
```

Used when `ENABLE_DB_STORAGE=true` (set automatically for profiles that include PostgreSQL).

### Open WebUI Configuration

```bash
OPENWEBUI_EMAIL=admin@example.com
OPENWEBUI_PASSWORD=admin
```

Used when profile includes Open WebUI (dev, ops, sys).

## Troubleshooting

### Token Limit Errors with vLLM

**Error**: `Token limit exceeded` or OpenCode generates indefinitely

**Fix**: Ensure `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX` is set:
```bash
OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=8192
```

### Model Not Found After Engine Switch

When switching engines, old model configuration may persist:

1. Switch engine: `./aixcl engine set <engine>`
2. Update `.env` if needed (CLI should do this automatically)
3. Add new model: `./aixcl models add <model>`
4. Restart: `./aixcl stack restart engine`

### Duplicate/Conflicting Variables

**Issue**: `INFERENCE_MODEL` and `VLLM_MODEL` both set

**Solution**: 
- vLLM only uses `VLLM_MODEL`
- llama.cpp only uses `INFERENCE_MODEL`
- Keep unused variables commented out

## Best Practices

1. **Use CLI commands** to change engines: `./aixcl engine set <engine>`
2. **Comment out unused variables** to avoid confusion
3. **Regenerate from template** if corrupted: Delete `.env`, run any `./aixcl` command
4. **Don't commit `.env`** - it's user-specific
5. **Update template** (`config/.env.example`) if you find bugs in defaults

## See Also

- [Profile Documentation](../architecture/governance/02_profiles.md)
- [Engine Switching Guide](../operations/engine-switching-test-plan.md)
- [vLLM Workaround Guide](../operations/vllm-model-download-workaround.md)
