# Ollama Performance Tuning - Executive Summary

## Key Findings

Based on analysis of your LLM Council implementation and Ollama performance research, here are the critical optimizations for your containerized deployment on a single NVIDIA 40XX GPU.

## Critical Optimizations (Must Implement)

### 1. Increase Parallel Request Capacity
**Variable**: `OLLAMA_NUM_PARALLEL=8`
- **Why**: Your council queries multiple models simultaneously in Stage 1, then again in Stage 2, then chairman in Stage 3. Default limit of 4 causes queuing.
- **Impact**: Enables true parallel execution without bottlenecks

### 2. Keep Models Loaded in Memory
**Variable**: `OLLAMA_MAX_LOADED_MODELS=3`
- **Why**: Council stages execute rapidly (Stage 1 → Stage 2 → Stage 3). Reloading models between stages adds 5-10 second delays.
- **Impact**: Eliminates model reload overhead, 50%+ faster council cycles
- **Note**: Adjust based on your GPU VRAM (3x 7B Q4_0 models ≈ 12-15GB)

### 3. Extend Model Keep-Alive
**Variable**: `OLLAMA_KEEP_ALIVE=600` (10 minutes)
- **Why**: Prevents models from unloading between rapid council queries
- **Impact**: Models stay ready for immediate use across all stages

### 4. Explicit GPU Configuration
**Variable**: `OLLAMA_NUM_GPU=1`
- **Why**: Ensures Ollama properly detects and uses your single GPU
- **Impact**: Optimal GPU utilization

## Recommended Model Strategy

### Default Configuration (Recommended)

**Current Default Setup** (optimized for 8GB GPUs):
- **Chairman**: `deepseek-coder:1.3b` (776MB)
- **Council Members**: `codegemma:2b` (1.6GB), `qwen2.5-coder:3b` (1.9GB)
- **Total VRAM**: ~4.3GB
- **Performance**: ~24s average, 68.1% keep-alive improvement
- **Status**: Most reliable, no GPU memory pressure

**Quick Setup:**
```bash
./aixcl council configure
# Select: Chairman: deepseek-coder:1.3b
# Select: Council: codegemma:2b, qwen2.5-coder:3b
```

### For Larger GPUs (16GB+)

**Use Quantized Models (Q4_0 or Q5_0)**:
- **7B Q4_0 models**: ~4-5GB VRAM each (optimal for council)
- **7B Q5_0 models**: ~5-6GB VRAM each (slightly better quality)

**Recommended Setup** (based on [Ollama model library](https://ollama.com/search)):

**Council Members** (2-4 models):
- **Best for Code Tasks**: `qwen2.5-coder:7b-q4_0` (9.4M pulls, actively maintained)
- **Alternatives**: `qwen3-coder:8b-q4_0`, `codellama:7b-q4_0`, `deepseek-r1:7b-q4_0`
- **General Purpose**: `llama3.1:8b-q4_0`, `ministral-3:8b-q4_0`

**Chairman**:
- **Recommended**: `qwen2.5-coder:7b-q5_0` or `qwen3-coder:8b-q5_0`
- **Alternative**: `llama3.1:8b-q5_0` or `deepseek-r1:7b-q5_0`
- **Rationale**: Better quantization (Q5_0) for synthesis quality

**VRAM Planning**:
- **16GB GPU**: 3x 7B-8B Q4_0 models (~12-15GB) or 2x 7B-8B Q5_0 models (~10-12GB)
- **12GB GPU**: 2x 7B-8B Q4_0 models (~8-10GB) or 3x 3B-4B Q4_0 models (~6-9GB)

**Model Selection Tips**:
- Code-specific models (`qwen2.5-coder`, `qwen3-coder`, `codellama`) provide better accuracy for council's code-focused tasks
- Check available quantizations: `docker exec ollama ollama list` after pulling
- Mix model sizes if needed (e.g., 2x 7B + 1x 3B) for optimal VRAM usage

## Implementation

Add to `services/docker-compose.yml`:

```yaml
services:
  ollama:
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_NUM_PARALLEL=8
      - OLLAMA_MAX_LOADED_MODELS=3
      - OLLAMA_KEEP_ALIVE=600
      - OLLAMA_NUM_GPU=1
      - OLLAMA_NUM_THREAD=8  # Adjust to your CPU cores
```

Then restart: `./aixcl stack restart ollama`

## Expected Performance Gains

**Before**: 
- Sequential/limited parallel execution
- Model reload delays between stages
- Total time: ~30-60 seconds

**After**:
- True parallel execution
- No reload delays (models stay loaded)
- Total time: ~15-30 seconds (**50-70% improvement**)

## Important Considerations

1. **GPU Memory**: Monitor VRAM usage. If OOM errors occur, reduce `OLLAMA_MAX_LOADED_MODELS` to 2
2. **Model Selection**: Use quantized models (Q4_0/Q5_0) to maximize models that fit in VRAM
3. **Council Size**: Balance between number of council members and available VRAM
4. **Testing**: Verify parallel execution in logs and measure actual performance improvements

## Full Documentation

See [`ollama-performance-tuning.md`](./ollama-performance-tuning.md) for complete details, troubleshooting, and monitoring guidance.

