# Model Recommendations

AIXCL uses Qwen 2.5 Coder instruct models across all three supported inference engines (Ollama, vLLM, llama.cpp).

## Qwen 2.5 Coder Model Series

The Qwen 2.5 Coder series is optimized for coding tasks with excellent performance across all sizes.

### Available Sizes

| Model | Size | VRAM* | Best For | Ollama | vLLM | llama.cpp |
|-------|------|-------|----------|--------|------|-----------|
| `0.5b` | ~400MB | ~1GB | Ultra-lightweight, IoT, edge devices | ✅ | ✅ | ✅ |
| `1.5b` | ~1GB | ~2.5GB | Lightweight, fast responses | ✅ | ✅ | ✅ |
| `3b` | ~2GB | ~5GB | Balanced performance | ✅ | ✅ | ✅ |
| `7b` | ~4.5GB | ~9GB | Higher quality, more capacity | ✅ | ✅ | ✅ |
| `14b` | ~9GB | ~18GB | Best quality, larger GPUs | ✅ | ✅ | ✅ |
| `32b` | ~20GB | ~40GB | Maximum quality, professional workstations | ✅ | ✅ | ✅ |

\* VRAM estimates are for inference with default context length. Actual usage varies by batch size and context.

### Engine-Specific Naming

**Ollama:**
```bash
./aixcl models add qwen2.5-coder:0.5b
./aixcl models add qwen2.5-coder:1.5b
./aixcl models add qwen2.5-coder:3b
```

**vLLM:**
```bash
./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct
./aixcl models add Qwen/Qwen2.5-Coder-1.5B-Instruct
./aixcl models add Qwen/Qwen2.5-Coder-3B-Instruct
```

**llama.cpp (GGUF):**
```bash
./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf
./aixcl models add Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf
./aixcl models add Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/qwen2.5-coder-3b-instruct-q4_k_m.gguf
```

## Recommended Configurations

### Configuration 1: Development Workstation (8-12GB VRAM)

Best for: Daily coding with OpenCode, Open WebUI, and concurrent queries

```bash
./aixcl models add qwen2.5-coder:1.5b
./aixcl models add qwen2.5-coder:3b
./aixcl models add qwen2.5-coder:7b
```

- **Primary**: 7B for complex tasks
- **Fast**: 1.5B for quick autocomplete
- **Balanced**: 3B for general queries
- **Total**: ~7.5GB VRAM loaded together

### Configuration 2: Lightweight/Laptop (4-8GB VRAM)

Best for: Running on integrated GPUs, older hardware, or when VRAM is shared with display

```bash
./aixcl models add qwen2.5-coder:0.5b
./aixcl models add qwen2.5-coder:1.5b
./aixcl models add qwen2.5-coder:3b
```

- **Total**: ~3.5GB VRAM
- All three can stay resident simultaneously

### Configuration 3: High-Performance (16GB+ VRAM)

Best for: Maximum quality, long context, batch processing

```bash
./aixcl models add qwen2.5-coder:7b
./aixcl models add qwen2.5-coder:14b
```

- **Total**: ~13.5GB VRAM
- 14B for highest quality responses
- 7B for faster fallback

### Configuration 4: Minimal/Edge (2-4GB VRAM)

Best for: Single model use, resource-constrained environments

```bash
./aixcl models add qwen2.5-coder:0.5b
```

- Surprisingly capable for 0.5B parameters
- Fits in nearly any modern GPU
- Good for testing and demos

## Model Selection Guidelines

| Scenario | Recommended | Why |
|----------|-------------|-----|
| OpenCode autocomplete | 0.5B or 1.5B | Fast, low latency |
| OpenCode chat/agent | 1.5B or 3B | Balance of speed and quality |
| Code review/analysis | 3B or 7B | Better reasoning capabilities |
| Documentation generation | 3B or 7B | Longer coherent outputs |
| Complex refactoring | 7B or 14B | Deeper understanding |
| Learning/tutorials | 0.5B or 1.5B | Fast experimentation |
| Production CI/CD | 1.5B or 3B | Reliable, consistent |

## Performance Notes

1. **Model Loading**: Larger models take longer to load (seconds vs minutes for 14B+)
2. **Memory Management**: Multiple small models often outperform single large model with swapping
3. **Context Length**: All Qwen 2.5 Coder models support 32K context (configurable per engine)
4. **Quantization**: GGUF models use Q4_K_M by default for best speed/quality balance
5. **Concurrent Use**: Smaller models enable true parallel processing

## Implementation

Add models one by one or in batch:

```bash
# Single model
./aixcl models add qwen2.5-coder:1.5b

# Multiple models
./aixcl models add qwen2.5-coder:0.5b qwen2.5-coder:1.5b qwen2.5-coder:3b

# List installed models
./aixcl models list

# Remove a model
./aixcl models remove qwen2.5-coder:3b
```

## See Also

- [Qwen 2.5 Coder on Hugging Face](https://huggingface.co/Qwen) - Official model cards
- [`../user/usage.md`](../user/usage.md) - Adding and managing models
