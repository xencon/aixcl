# Model Size Recommendations for Performance

## Current Configuration

**Default Configuration (Recommended):**
- **Chairman**: `deepseek-coder:1.3b` (776MB)
- **Council Members**: `codegemma:2b` (1.6GB) + `qwen2.5-coder:3b` (1.9GB)
- **Total VRAM**: ~4.3GB
- **Performance**: 24.75s average, 68.1% keep-alive improvement

This configuration provides:
- Excellent keep-alive performance (68.1% improvement)
- Low VRAM usage (~4.3GB)
- Good response times (24.75s average)
- No GPU memory pressure issues
- Most reliable performance

## Previous Issue (Resolved)

**Previous Problem**: Large models (8GB+) caused:
- Slow loading times (30-60+ seconds)
- GPU memory pressure
- Inability to keep multiple models loaded simultaneously
- Poor performance (100+ seconds per query vs expected 15-30s)

**Solution**: Switched to smaller models (Option 1) which resolved all issues.

## Alternative Model Configurations

### Option 1: Ultra-Lightweight Setup (CURRENT DEFAULT)

**Best for**: Maximum speed, minimal VRAM usage, most reliable

**Council Members** (2 models):
- `codegemma:2b` (1.6GB)
- `qwen2.5-coder:3b` (1.9GB)

**Chairman**:
- `deepseek-coder:1.3b` (776MB)

**Total VRAM**: ~4.3GB
**Performance**: 24.75s average, 68.1% keep-alive improvement

### Option 2: Balanced Small Setup (Warning: GPU Memory Pressure)

**Best for**: Better consistency, but requires more GPU memory

**Council Members** (2 models):
- `codegemma:2b` (1.6GB)
- `deepseek-coder:1.3b` (776MB)

**Chairman**:
- `ministral-3:3b` (3.0GB)

**Total VRAM**: ~5.9GB
**Performance**: 24.05s average, 23.8% consistency (best), but GPU memory pressure issues

**Note**: This configuration has GPU memory pressure issues on 8GB GPUs. Models may be evicted causing reload delays. Requires 16GB+ GPU or quantized models.

### Option 3: Medium Performance Setup (Warning: Slower)

**Best for**: Better code quality with larger chairman model

**Council Members** (2 models):
- `codegemma:2b` (1.6GB)
- `deepseek-coder:1.3b` (776MB)

**Chairman**:
- `qwen2.5-coder:7b` (4.7GB)

**Total VRAM**: ~7.6GB
**Performance**: 31.91s average, 55.7% consistency, 13.4% keep-alive improvement

**Note**: Slower than Option 1, acceptable but could be better. May have GPU memory pressure on 8GB GPUs.

## Quick Setup Guide

### Step 1: Reconfigure Council with Smaller Models

```bash
# Use Option 1 (Ultra-Lightweight) for fastest performance
./aixcl council configure
```

**Select these models:**
- **Council Members**: `codegemma:2b`, `qwen2.5-coder:3b`
- **Chairman**: `deepseek-coder:1.3b`

### Step 2: Verify Configuration

```bash
./aixcl council status
```

### Step 3: Test Performance

```bash
./tests/runtime-core/run_test.sh
```

**Expected Results with Small Models:**
- First query: 10-20 seconds
- Subsequent queries: 8-15 seconds
- Average time: < 20 seconds

## Model Size Comparison

| Model | Size | Use Case | Speed |
|-------|------|----------|-------|
| `deepseek-coder:1.3b` | 776MB | Council member | Very fast |
| `codegemma:2b` | 1.6GB | Council member | Very fast |
| `qwen2.5-coder:3b` | 1.9GB | Council member/Chairman | Fast |
| `llama3.2:3b` | 2.0GB | Council member | Fast |
| `phi3:mini` | 2.2GB | Council member | Fast |
| `codellama:7b` | 3.8GB | Council member/Chairman | Medium |
| `deepseek-coder:6.7b` | 3.8GB | Council member | Medium |
| `qwen2.5:7b` | 4.7GB | Chairman | Medium |
| `ministral-3:8b` | 6.0GB | Too large (not recommended) | Slow |
| `gemma3:12b` | 8.1GB | Too large (not recommended) | Very slow |

## Why Smaller Models?

1. **Faster Loading**: Small models load in seconds vs minutes
2. **Better Memory Management**: Multiple small models can stay loaded simultaneously
3. **Parallel Execution**: Smaller models enable true parallel processing
4. **Consistent Performance**: Less variation in response times

## Current Performance vs Expected

**Your Current Setup** (large models):
- Average: 104.85 seconds (too slow)
- Expected: 15-30 seconds
- **Problem**: Models too large, can't stay loaded

**With Small Models** (Option 1):
- Expected: 10-20 seconds
- **Benefit**: Models stay loaded, parallel execution works

## Next Steps

1. **Reconfigure council** with smaller models (Option 1 recommended)
2. **Run performance test** to verify improvement
3. **Monitor GPU memory** with `nvidia-smi` during tests
4. **Adjust if needed** - if still slow, check Ollama optimization settings

## Additional Optimizations

Even with small models, ensure Ollama is optimized:

```yaml
# In docker-compose.yml
environment:
  - OLLAMA_NUM_PARALLEL=8
  - OLLAMA_MAX_LOADED_MODELS=3
  - OLLAMA_KEEP_ALIVE=600
  - OLLAMA_NUM_GPU=1
```

See [`ollama-performance-tuning.md`](./ollama-performance-tuning.md) for complete optimization guide.

