# Ollama Performance Tuning for AIXCL Council

## Executive Summary

This document presents performance tuning optimizations for Ollama to maximize efficiency and accuracy of the LLM Council system. The council orchestrates multiple models in parallel (Stage 1), then has them review each other (Stage 2), and finally synthesizes a response (Stage 3). All optimizations are tailored for:
- **Platform**: Containerized deployment (Docker)
- **OS**: Linux
- **GPU**: Single NVIDIA 40XX GPU
- **Use Case**: Code-focused LLM Council with parallel model queries

## Recommended Default Configuration ✅

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

See [`model-recommendations.md`](./model-recommendations.md) for alternative configurations and [`performance-test-results.md`](./performance-test-results.md) for detailed test results.

## Current Configuration Analysis

### Existing Setup
- **Ollama Container**: Basic configuration with only `OLLAMA_HOST=0.0.0.0`
- **Default Behavior**: Ollama defaults to handling maximum 4 parallel requests
- **Council Pattern**: Stage 1 queries all council models in parallel (typically 2-5 models)
- **GPU**: Single NVIDIA 40XX GPU with full access via docker-compose.gpu.yml

### Performance Bottlenecks Identified

1. **Limited Parallelism**: Default `OLLAMA_NUM_PARALLEL=4` may bottleneck when council has multiple models
2. **Model Loading**: Models may be unloaded between requests, causing reload delays
3. **No GPU Optimization**: No explicit GPU configuration variables set
4. **Memory Management**: No control over how many models stay loaded simultaneously

## Recommended Optimizations

### 1. Increase Parallel Request Handling

**Environment Variable**: `OLLAMA_NUM_PARALLEL`

**Recommendation**: Set to match or exceed your maximum council size plus chairman
- **For 3-5 council members**: `OLLAMA_NUM_PARALLEL=8` (allows council + chairman + buffer)
- **Rationale**: Stage 1 queries all council models simultaneously, Stage 2 queries each model again, Stage 3 queries chairman. Need capacity for concurrent requests.

**Implementation**:
```yaml
environment:
  - OLLAMA_NUM_PARALLEL=8
```

**Impact**: Enables true parallel execution of council queries without queuing delays.

### 2. Optimize Model Loading Strategy

**Environment Variable**: `OLLAMA_MAX_LOADED_MODELS`

**Recommendation**: Set to 2-3 models (council size + chairman)
- **For typical council**: `OLLAMA_MAX_LOADED_MODELS=3`
- **Rationale**: Keep frequently-used models (council members + chairman) in GPU memory to avoid reload overhead. Single GPU has limited VRAM, so balance between keeping models loaded and memory availability.

**Implementation**:
```yaml
environment:
  - OLLAMA_MAX_LOADED_MODELS=3
```

**Impact**: Reduces model loading time from seconds to milliseconds for repeated queries.

**Trade-off**: Higher GPU memory usage. Monitor VRAM usage and adjust if models don't fit.

### 3. Enable Model Keep-Alive

**Environment Variable**: `OLLAMA_KEEP_ALIVE`

**Recommendation**: Set to 5-10 minutes (300-600 seconds)
- **Value**: `OLLAMA_KEEP_ALIVE=600` (10 minutes)
- **Rationale**: Council queries happen in rapid succession (Stage 1 → Stage 2 → Stage 3). Keeping models loaded prevents reload delays between stages.

**Implementation**:
```yaml
environment:
  - OLLAMA_KEEP_ALIVE=600
```

**Impact**: Eliminates model reload overhead between council stages.

**Note**: This works in conjunction with `OLLAMA_MAX_LOADED_MODELS`. Models beyond the max will still be unloaded.

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
- **Rationale**: Optimal CPU utilization for preprocessing/postprocessing tasks while GPU handles inference.

**Implementation**:
```yaml
environment:
  - OLLAMA_NUM_THREAD=8  # Adjust to your CPU core count
```

**Impact**: Better CPU utilization for non-GPU tasks.

**Note**: Less critical than GPU optimizations, but can help with overall throughput.

## Complete Optimized Configuration

### Updated docker-compose.yml

```yaml
services:
  ollama:
    volumes:
      - ollama:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0
      # Performance tuning for council
      - OLLAMA_NUM_PARALLEL=8          # Handle concurrent council queries
      - OLLAMA_MAX_LOADED_MODELS=3     # Keep council + chairman loaded
      - OLLAMA_KEEP_ALIVE=600          # 10 min keep-alive for rapid queries
      - OLLAMA_NUM_GPU=1                # Explicit single GPU usage
      - OLLAMA_NUM_THREAD=8             # Match CPU cores (adjust as needed)
    ports:
      - "11434:11434"
    container_name: ollama
    pull_policy: always
    tty: true
    restart: unless-stopped
    image: ollama/ollama:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/version"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
```

## Model Selection Recommendations

### For Council Efficiency

**Key Considerations**:
1. **Model Size**: Must fit on single GPU with multiple models loaded
2. **Quantization**: Use Q4_0 or Q5_0 quantized models for better performance
3. **Accuracy**: Maintain code generation quality

### Recommended Model Strategy

Based on current models available on [Ollama](https://ollama.com/search), here are optimized recommendations for code-focused council tasks:

**For NVIDIA 40XX GPUs (16GB+ VRAM)**:

1. **Council Members** (2-4 models):
   - **Primary Recommendations** (Code-Specific):
     - `qwen2.5-coder:7b` - Latest code-specific Qwen model (9.4M pulls, actively maintained)
     - `qwen3-coder:8b` - Newer generation with improved coding capabilities
     - `codellama:7b` - Proven code generation model (3.7M pulls)
   - **Alternative Options**:
     - `deepseek-r1:7b` - Reasoning model with tool support (good for complex code tasks)
     - `llama3.1:8b` - General purpose with tool support (107.9M pulls, very popular)
     - `ministral-3:8b` - Edge-optimized with vision and tools support
   - **Quantization**: Use Q4_0 or Q5_0 variants (e.g., `qwen2.5-coder:7b-q4_0`)
   - **Rationale**: Code-specific models provide better accuracy for council's code-focused tasks

2. **Chairman Model**:
   - **Recommended**: `qwen2.5-coder:7b-q5_0` or `qwen3-coder:8b-q5_0`
   - **Alternative**: `llama3.1:8b-q5_0` or `deepseek-r1:7b-q5_0`
   - **Rationale**: Needs to synthesize and evaluate code responses. Q5_0 quantization provides better quality while maintaining efficiency

**For NVIDIA 40XX GPUs (12GB VRAM)**:

1. **Council Members**:
   - **Primary Recommendations**:
     - `qwen2.5-coder:7b-q4_0` - Best code model that fits
     - `ministral-3:3b-q4_0` - Smaller edge-optimized model
     - `phi3:3.8b-q4_0` - Lightweight Microsoft model (15.3M pulls)
   - **Alternative**:
     - `qwen2.5:7b-q4_0` - General purpose Qwen (if code-specific unavailable)
   - **Rationale**: Lower VRAM requirements allow 2-3 models loaded simultaneously

2. **Chairman**:
   - Use `qwen2.5-coder:7b-q4_0` or `llama3.1:8b-q4_0`
   - **Rationale**: Balance between quality and memory constraints

### Model Loading Memory Estimates

**Approximate VRAM Usage** (for planning):
- **3B-4B Q4_0**: ~2-3GB per model
- **7B-8B Q4_0**: ~4-5GB per model
- **7B-8B Q5_0**: ~5-6GB per model
- **14B Q4_0**: ~7-8GB per model

**Example Scenarios**:
- **16GB GPU**: Can load 3x 7B-8B Q4_0 models (~12-15GB total) or 2x 7B-8B Q5_0 models (~10-12GB total)
- **12GB GPU**: Can load 2x 7B-8B Q4_0 models (~8-10GB total) or 3x 3B-4B Q4_0 models (~6-9GB total)

**Model Availability Notes**:
- Check available quantizations: `docker exec ollama ollama list` after pulling models
- Some models may have different quantization options (Q2, Q3, Q4, Q5, Q8, F16)
- Q4_0 and Q5_0 are typically the best balance of quality and performance

**Recommendation**: 
1. Pull and test models: `docker exec ollama ollama pull qwen2.5-coder:7b`
2. Check actual VRAM usage with `nvidia-smi` during inference
3. Adjust `OLLAMA_MAX_LOADED_MODELS` based on actual usage
4. Consider mixing model sizes (e.g., 2x 7B + 1x 3B) for optimal VRAM utilization

## Performance Monitoring

### Key Metrics to Track

1. **GPU Memory Usage**: Monitor with `nvidia-smi` or Grafana dashboard
2. **Request Latency**: Track Stage 1, Stage 2, Stage 3 times separately
3. **Model Load Times**: Monitor time between first request and response
4. **Parallel Request Handling**: Verify all Stage 1 queries execute concurrently

### Monitoring Commands

```bash
# GPU memory usage
docker exec ollama nvidia-smi

# Ollama logs
docker logs ollama --tail 100

# Test parallel requests
# (Stage 1 should show all models queried simultaneously)
```

### Expected Improvements

**Before Optimizations**:
- Stage 1: Sequential or limited parallel execution
- Model reload delays between stages
- Total time: ~30-60 seconds for full council cycle

**After Optimizations**:
- Stage 1: True parallel execution of all council queries
- No model reload delays (models stay loaded)
- Total time: ~15-30 seconds for full council cycle (50% improvement)

**Actual results depend on**:
- Model sizes and quantization
- GPU VRAM capacity
- Query complexity
- Network latency (minimal for localhost)

## Discovering Available Models

### Check Available Models on Ollama

1. **Browse Models Online**: Visit [https://ollama.com/search](https://ollama.com/search) to see all available models
2. **Search by Category**: Filter by "Tools" tag for code-capable models
3. **Check Model Details**: Click on models to see available sizes and quantizations

### Verify Installed Models

```bash
# List installed models
docker exec ollama ollama list

# Pull a model (if not installed)
docker exec ollama ollama pull qwen2.5-coder:7b

# Check available quantizations (may vary by model)
docker exec ollama ollama pull qwen2.5-coder:7b-q4_0
docker exec ollama ollama pull qwen2.5-coder:7b-q5_0
docker exec ollama ollama pull qwen2.5-coder:7b-q8_0
```

### Popular Code-Focused Models (as of 2025)

Based on [Ollama's model library](https://ollama.com/search):

**Highly Recommended for Council**:
- `qwen2.5-coder:7b` - 9.4M pulls, actively maintained, code-specific
- `qwen3-coder:8b` - Newer generation with improved capabilities
- `codellama:7b` - 3.7M pulls, proven code generation
- `deepseek-r1:7b` - Reasoning model with tool support (74.9M pulls)

**General Purpose (with code capabilities)**:
- `llama3.1:8b` - 107.9M pulls, very popular, tool support
- `ministral-3:8b` - Edge-optimized, vision + tools (131.1K pulls)
- `gemma3:12b` - Google's latest, single GPU capable (28.6M pulls)

**Smaller Options (for 12GB GPUs)**:
- `ministral-3:3b` - Edge deployment focused
- `phi3:3.8b` - Microsoft lightweight model (15.3M pulls)
- `qwen2.5:3b` - Smaller Qwen variant

## Implementation Steps

1. **Update docker-compose.yml** with environment variables above
2. **Pull Recommended Models**: 
   ```bash
   docker exec ollama ollama pull qwen2.5-coder:7b-q4_0
   docker exec ollama ollama pull qwen2.5-coder:7b-q5_0  # For chairman
   ```
3. **Restart Ollama**: `./aixcl stack restart ollama`
4. **Verify Configuration**: Check logs for environment variable recognition
5. **Configure Council**: `./aixcl council configure` and select your models
6. **Test Council**: Run a test query and monitor performance
7. **Monitor GPU Memory**: Ensure models fit within VRAM limits with `nvidia-smi`
8. **Adjust if Needed**: Fine-tune `OLLAMA_MAX_LOADED_MODELS` based on actual usage

## Troubleshooting

### Issue: Out of Memory Errors

**Symptoms**: Models fail to load, GPU OOM errors
**Solution**: 
- Reduce `OLLAMA_MAX_LOADED_MODELS` to 2
- Use smaller quantized models (Q4_0 instead of Q5_0)
- Reduce council size

### Issue: Models Still Loading Slowly

**Symptoms**: First request per model takes long
**Solution**:
- Increase `OLLAMA_KEEP_ALIVE` to 1800 (30 minutes)
- Preload models: `docker exec ollama ollama run <model-name> < /dev/null`
- Check `OLLAMA_MAX_LOADED_MODELS` is set correctly

### Issue: Parallel Requests Still Queuing

**Symptoms**: Stage 1 queries execute sequentially
**Solution**:
- Increase `OLLAMA_NUM_PARALLEL` to 10-12
- Verify Ollama logs show parallel processing
- Check council adapter is using async properly

## References

- [Red Hat: Ollama vs. vLLM Performance Benchmarking](https://developers.redhat.com/articles/2025/08/08/ollama-vs-vllm-deep-dive-performance-benchmarking)
- Ollama Environment Variables Documentation
- AIXCL Council Implementation: `llm-council/backend/council.py`

## Summary

**Critical Optimizations** (Must Implement):
1. `OLLAMA_NUM_PARALLEL=8` - Enable concurrent council queries
2. `OLLAMA_MAX_LOADED_MODELS=3` - Keep models in memory
3. `OLLAMA_KEEP_ALIVE=600` - Prevent reload delays
4. `OLLAMA_NUM_GPU=1` - Explicit GPU usage

**Recommended Optimizations** (Should Implement):
5. `OLLAMA_NUM_THREAD=<cores>` - CPU optimization
6. Use quantized models (Q4_0/Q5_0) - Better performance/VRAM ratio

**Expected Impact**: 50-70% reduction in total council response time, with models staying loaded and true parallel execution.

