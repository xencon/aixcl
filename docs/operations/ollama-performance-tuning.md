# Ollama Performance Tuning for Parallel Model Queries

## Executive Summary

This document presents performance tuning optimizations for Ollama to maximize efficiency and accuracy when running multiple models in parallel or switching between them rapidly. These optimizations are particularly useful for workflows involving multi-model orchestration, comparison, or automated review.

All optimizations are tailored for:
- **Platform**: Containerized deployment (Docker)
- **OS**: Linux
- **GPU**: Single NVIDIA 40XX GPU
- **Use Case**: Concurrent model queries and rapid model switching

## Recommended Default Configuration

**Current Default Setup** (optimized for 8GB GPUs):
- **Primary Model**: `qwen2.5-coder:7b` (4.7GB)
- **Secondary Models**: `deepseek-coder:1.3b` (776MB), `codegemma:2b` (1.6GB)
- **Total VRAM**: ~7.1GB
- **Performance**: High throughput, low switching latency
- **Status**: Stable, fits within 8GB VRAM

See [`model-recommendations.md`](./model-recommendations.md) for alternative configurations and [`performance-test-results.md`](./performance-test-results.md) for detailed test results.

## Performance Bottlenecks Identified

1. **Limited Parallelism**: Default `OLLAMA_NUM_PARALLEL=4` may bottleneck when querying multiple models simultaneously.
2. **Model Loading**: Models may be unloaded between requests, causing reload delays.
3. **Memory Management**: Lack of control over how many models stay loaded simultaneously in GPU memory.

## Recommended Optimizations

### 1. Increase Parallel Request Handling

**Environment Variable**: `OLLAMA_NUM_PARALLEL`

**Recommendation**: Set to match or exceed your expected concurrent request count.
- **For typical multi-model workflows**: `OLLAMA_NUM_PARALLEL=8`
- **Rationale**: Enables Ollama to process multiple requests simultaneously without queuing.

**Implementation**:
```yaml
environment:
  - OLLAMA_NUM_PARALLEL=8
```

**Impact**: Enables true parallel execution of model queries.

### 2. Optimize Model Loading Strategy

**Environment Variable**: `OLLAMA_MAX_LOADED_MODELS`

**Recommendation**: Set to the number of models you want to keep active in GPU memory.
- **Typical Setting**: `OLLAMA_MAX_LOADED_MODELS=3`
- **Rationale**: Keep frequently-used models in GPU memory to avoid reload overhead.

**Implementation**:
```yaml
environment:
  - OLLAMA_MAX_LOADED_MODELS=3
```

**Impact**: Reduces model loading time from seconds to milliseconds for repeated queries.

**Trade-off**: Higher GPU memory usage. Monitor VRAM usage and adjust if models don't fit.

### 3. Enable Model Keep-Alive

**Environment Variable**: `OLLAMA_KEEP_ALIVE`

**Recommendation**: Set to a duration that covers your typical session length (e.g., 30 minutes).
- **Value**: `OLLAMA_KEEP_ALIVE=1800` (30 minutes)
- **Rationale**: Prevents models from being unloaded during active development sessions.

**Implementation**:
```yaml
environment:
  - OLLAMA_KEEP_ALIVE=1800
```

**Impact**: Eliminates model reload overhead between frequent queries.

### 4. Explicit GPU Configuration

**Environment Variable**: `OLLAMA_NUM_GPU`

**Recommendation**: Set to 1 (explicit single GPU)
- **Value**: `OLLAMA_NUM_GPU=1`
- **Rationale**: Explicitly tells Ollama to use the single GPU, ensuring optimal GPU utilization.

**Implementation**:
```yaml
environment:
  - OLLAMA_NUM_GPU=1
```

**Impact**: Ensures GPU is properly detected and utilized.

### 5. CPU Thread Optimization (Optional)

**Environment Variable**: `OLLAMA_NUM_THREAD`

**Recommendation**: Match physical CPU cores
- **Value**: Set to number of physical CPU cores (e.g., `OLLAMA_NUM_THREAD=8`)
- **Rationale**: Optimal CPU utilization for preprocessing/postprocessing tasks.

**Implementation**:
```yaml
environment:
  - OLLAMA_NUM_THREAD=8  # Adjust to your CPU core count
```

## Complete Optimized Configuration

### Updated docker-compose.yml snippet

```yaml
services:
  ollama:
    environment:
      - OLLAMA_HOST=127.0.0.1:11434
      - OLLAMA_NUM_PARALLEL=8          # Handle concurrent queries
      - OLLAMA_MAX_LOADED_MODELS=3     # Keep multiple models loaded
      - OLLAMA_KEEP_ALIVE=1800         # 30 min keep-alive
      - OLLAMA_NUM_GPU=1               # Explicit single GPU usage
      - OLLAMA_NUM_THREAD=8            # Match CPU cores
```

## Model Selection Recommendations

### Key Considerations
1. **Model Size**: Total size of concurrently loaded models must fit in GPU VRAM.
2. **Quantization**: Use Q4_0 or Q5_0 quantized models for better performance/memory ratio.

### Model Loading Memory Estimates

**Approximate VRAM Usage**:
- **3B-4B Q4_0**: ~2-3GB per model
- **7B-8B Q4_0**: ~4-5GB per model
- **7B-8B Q5_0**: ~5-6GB per model

**Example Scenarios**:
- **16GB GPU**: Can load 3x 7B-8B Q4_0 models (~12-15GB total).
- **12GB GPU**: Can load 2x 7B-8B Q4_0 models (~8-10GB total).

## Performance Monitoring

### Key Metrics to Track

1. **GPU Memory Usage**: Monitor with `nvidia-smi` or Grafana dashboard.
2. **Request Latency**: Track individual model response times.
3. **Model Load Times**: Monitor time between request and first token.

### Monitoring Commands

```bash
# GPU memory usage
docker exec ollama nvidia-smi

# Ollama logs
docker logs ollama --tail 100
```

## Summary

**Critical Optimizations**:
1. `OLLAMA_NUM_PARALLEL=8` - Enable concurrent queries.
2. `OLLAMA_MAX_LOADED_MODELS=3` - Keep models in memory.
3. `OLLAMA_KEEP_ALIVE=1800` - Prevent frequent reloading.
4. `OLLAMA_NUM_GPU=1` - Explicit GPU usage.

**Expected Impact**: Significant reduction in response time for multi-model workflows, with models staying loaded and true parallel execution.
