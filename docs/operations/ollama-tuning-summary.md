# Ollama Performance Tuning - Executive Summary

## Key Findings

Based on analysis of parallel model performance and Ollama research, here are the critical optimizations for your containerized deployment on a single NVIDIA 40XX GPU.

## Critical Optimizations (Must Implement)

### 1. Increase Parallel Request Capacity
**Variable**: `OLLAMA_NUM_PARALLEL=8`
- **Why**: Default limit of 4 causes queuing when multiple models are queried simultaneously or in rapid succession.
- **Impact**: Enables true parallel execution without bottlenecks.

### 2. Keep Models Loaded in Memory
**Variable**: `OLLAMA_MAX_LOADED_MODELS=3`
- **Why**: Rapidly switching between models adds 5-10 second reload delays.
- **Impact**: Eliminates model reload overhead, 50%+ faster multi-model workflows.
- **Note**: Adjust based on your GPU VRAM (3x 7B Q4_0 models ≈ 12-15GB).

### 3. Extend Model Keep-Alive
**Variable**: `OLLAMA_KEEP_ALIVE=1800` (30 minutes)
- **Why**: Prevents models from unloading between queries during active sessions.
- **Impact**: Models stay ready for immediate use.

### 4. Explicit GPU Configuration
**Variable**: `OLLAMA_NUM_GPU=1`
- **Why**: Ensures Ollama properly detects and uses your single GPU.
- **Impact**: Optimal GPU utilization.

## Recommended Model Strategy

### Balanced Configuration (Recommended for 8GB GPUs)

- **Primary Model**: `qwen2.5-coder:7b` (4.7GB)
- **Secondary Models**: `deepseek-coder:1.3b` (776MB), `codegemma:2b` (1.6GB)
- **Total VRAM**: ~7.1GB
- **Performance**: High throughput, low switching latency.

### For Larger GPUs (16GB+)

**Use Quantized Models (Q4_0 or Q5_0)**:
- **7B Q4_0 models**: ~4-5GB VRAM each.
- **7B Q5_0 models**: ~5-6GB VRAM each.

**VRAM Planning**:
- **16GB GPU**: 3x 7B-8B Q4_0 models (~12-15GB) or 2x 7B-8B Q5_0 models (~10-12GB).
- **12GB GPU**: 2x 7B-8B Q4_0 models (~8-10GB) or 3x 3B-4B Q4_0 models (~6-9GB).

## Implementation

Add to `services/docker-compose.yml`:

```yaml
services:
  ollama:
    environment:
      - OLLAMA_HOST=127.0.0.1:11434
      - OLLAMA_NUM_PARALLEL=8
      - OLLAMA_MAX_LOADED_MODELS=3
      - OLLAMA_KEEP_ALIVE=1800
      - OLLAMA_NUM_GPU=1
      - OLLAMA_NUM_THREAD=8  # Match CPU cores
```

Then restart: `./aixcl stack restart ollama`

## Expected Performance Gains

**Before**: 
- Sequential/limited parallel execution.
- Model reload delays between queries.

**After**:
- True parallel execution.
- No reload delays (models stay loaded).
- **50-70% improvement** in multi-model workflow response times.

## Important Considerations

1. **GPU Memory**: Monitor VRAM usage. If OOM errors occur, reduce `OLLAMA_MAX_LOADED_MODELS`.
2. **Model Selection**: Use quantized models (Q4_0/Q5_0) to maximize models that fit in VRAM.
3. **Testing**: Verify parallel execution in logs and measure actual performance improvements.

## Full Documentation

See [`ollama-performance-tuning.md`](./ollama-performance-tuning.md) for complete details.
