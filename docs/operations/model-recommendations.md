# Model Size Recommendations for Performance

## Current Configuration

**Balanced Configuration (Recommended):**
- **Primary Model**: `qwen2.5-coder:7b` (4.7GB)
- **Secondary Models**: `deepseek-coder:1.3b` (776MB), `codegemma:2b` (1.6GB)
- **Total VRAM**: ~7.1GB
- **Performance**: High throughput, low switching latency

This configuration provides:
- Excellent keep-alive performance
- Manageable VRAM usage for 8GB+ GPUs
- Good response times
- Reliable performance for concurrent queries

## Performance Analysis

**Problem**: Large models (8GB+) can cause:
- Slow loading times (30-60+ seconds)
- GPU memory pressure
- Inability to keep multiple models loaded simultaneously
- Poor performance due to frequent model swapping

**Solution**: Use a mix of one primary model and smaller auxiliary models to stay within VRAM limits.

## Alternative Model Configurations

### Option 1: Ultra-Lightweight Setup

**Best for**: Maximum speed, minimal VRAM usage, older hardware

- `codegemma:2b` (1.6GB)
- `qwen2.5-coder:3b` (1.9GB)
- `deepseek-coder:1.3b` (776MB)

**Total VRAM**: ~4.3GB
**Performance**: Extremely fast, fits in 6GB VRAM GPUs

### Option 2: Balanced Coding Setup (CURRENT DEFAULT)

**Best for**: High-quality code assistance with good performance

- `qwen2.5-coder:7b` (4.7GB)
- `deepseek-coder:1.3b` (776MB)
- `codegemma:2b` (1.6GB)

**Total VRAM**: ~7.1GB
**Performance**: Best balance of quality and speed for 8GB+ GPUs

### Option 3: High-Quality Setup (12GB+ VRAM required)

**Best for**: Maximum quality across multiple models

- `qwen2.5-coder:7b` (4.7GB)
- `llama3.1:8b` (4.7GB)
- `ministral-3:3b` (3.0GB)

**Total VRAM**: ~12.4GB
**Note**: Requires 16GB+ GPU for optimal performance with multiple models loaded.

## Model Size Comparison

| Model | Size | Use Case | Speed |
|-------|------|----------|-------|
| `deepseek-coder:1.3b` | 776MB | Fast auxiliary | Very fast |
| `codegemma:2b` | 1.6GB | Fast auxiliary | Very fast |
| `qwen2.5-coder:3b` | 1.9GB | Balanced | Fast |
| `llama3.2:3b` | 2.0GB | Balanced | Fast |
| `phi3:mini` | 2.2GB | Balanced | Fast |
| `codellama:7b` | 3.8GB | High quality | Medium |
| `deepseek-coder:6.7b` | 3.8GB | High quality | Medium |
| `qwen2.5-coder:7b` | 4.7GB | High quality | Medium |

## Why Smaller Models?

1. **Faster Loading**: Small models load in seconds vs minutes.
2. **Better Memory Management**: Multiple small models can stay loaded simultaneously.
3. **Parallel Execution**: Smaller models enable true parallel processing without GPU swapping.
4. **Consistent Performance**: Less variation in response times.

## Implementation Steps

1. **Pull Recommended Models**:
   ```bash
   ./aixcl models add qwen2.5-coder:7b deepseek-coder:1.3b codegemma:2b
   ```
2. **Configure Engine**: Ensure `OLLAMA_MAX_LOADED_MODELS` is set correctly in `docker-compose.yml`.
3. **Monitor GPU memory** with `nvidia-smi` during use.

## Additional Optimizations

Ensure your engine is optimized for multi-model use:

```yaml
# In docker-compose.yml
environment:
  - OLLAMA_NUM_PARALLEL=8
  - OLLAMA_MAX_LOADED_MODELS=3
  - OLLAMA_KEEP_ALIVE=1800
  - OLLAMA_NUM_GPU=1
```

See [`ollama-performance-tuning.md`](./ollama-performance-tuning.md) for complete optimization guide.
