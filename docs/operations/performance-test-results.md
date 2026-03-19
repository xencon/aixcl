# Performance Test Results - Multi-Model Configuration Comparison

## Test Date
December 24, 2025

## Test Configurations

### Option 1: Ultra-Lightweight (Balanced)
- **Primary Model**: `qwen2.5-coder:3b` (1.9 GB)
- **Auxiliary Models**: `deepseek-coder:1.3b` (776 MB) + `codegemma:2b` (1.6 GB)
- **Total VRAM**: ~4.3 GB
- **Status**: Recommended for 8GB GPUs

**Results:**
- Average time: 24.75s
- Keep-alive: 68.1% improvement
- Performance: Meets expectations

**Pros:**
- Excellent keep-alive performance
- Lowest VRAM usage
- Good average response time

---

### Option 2: High Quality (Small)
- **Primary Model**: `ministral-3:3b` (3.0 GB)
- **Auxiliary Models**: `codegemma:2b` (1.6 GB) + `deepseek-coder:1.3b` (776 MB)
- **Total VRAM**: ~5.9 GB
- **Status**: Warning - GPU Memory Pressure on 8GB GPUs

**Results:**
- Average time: 24.05s
- Consistency: 23.8% variation (best)
- Issues: Second query failed or slowed significantly due to memory pressure

**Pros:**
- Best consistency when memory is available
- High model quality

**Cons:**
- GPU memory pressure causing model evictions
- Models being evicted: `model requires more gpu memory than is currently available, evicting a model to make space`

---

### Option 3: Medium Performance
- **Primary Model**: `qwen2.5-coder:7b` (4.7 GB)
- **Auxiliary Models**: `codegemma:2b` (1.6 GB) + `deepseek-coder:1.3b` (776 MB)
- **Total VRAM**: ~7.6 GB
- **Status**: Warning - Approaching 8GB VRAM limit

**Results:**
- Average time: 31.91s
- Keep-alive: 13.4% improvement
- Performance: Acceptable but slower than Option 1

---

## Key Findings

### GPU Memory Pressure
- Models use significantly more GPU memory when loaded than their file sizes suggest.
- Example: `ministral-3:3b` (3.0 GB file) can use ~7.7 GB when fully loaded for inference.
- On an 8GB GPU, loading multiple models simultaneously often triggers evictions.

### Model Eviction Behavior
- Ollama logs show: `model requires more gpu memory than is currently available, evicting a model to make space`.
- When eviction occurs, the next request for that model must reload it from disk, causing massive latency spikes (30-60s).

### Keep-Alive Performance
- **Option 1**: Excellent (68.1% improvement) because all models fit in VRAM.
- **Option 2/3**: Variable performance due to memory pressure and frequent evictions.

---

## Recommendations

### Recommended Configuration: Option 1 (Balanced)

**Why:**
- Best keep-alive performance (68.1% improvement).
- Lowest VRAM usage (~4.3 GB).
- No GPU memory pressure issues on 8GB cards.
- Most reliable performance for rapid switching.

### Optimization Suggestions

1. **Use Quantized Models**
   - Use Q4 or Q5 quantized versions to reduce VRAM footprint.

2. **Adjust OLLAMA_MAX_LOADED_MODELS**
   - Match this to the number of models you need active simultaneously.

3. **Monitor GPU Memory**
   - Use `nvidia-smi` to monitor usage.
   - Use `docker exec ollama ollama ps` to see currently loaded models.
   - Check Ollama logs for eviction messages.

---

## Test Methodology

1. **Multiple Query Test**: 3 queries to measure consistency and switching latency.
2. **Rapid Query Test**: 2 rapid queries to test keep-alive.
3. **Expected Performance**: 15-30s first query, 10-20s subsequent queries.
