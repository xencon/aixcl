# Performance Test Results - Model Configuration Comparison

## Test Date
December 24, 2025

## Test Configurations

### Option 1: Ultra-Lightweight
- **Chairman**: `deepseek-coder:1.3b` (776 MB)
- **Council Members**: `codegemma:2b` (1.6 GB) + `qwen2.5-coder:3b` (1.9 GB)
- **Total VRAM**: ~4.3 GB
- **Status**: Recommended

**Results:**
- Average time: 24.75s (within expected range)
- Consistency: 60.1% variation
- Keep-alive: 68.1% improvement
- Performance: Meets expectations

**Pros:**
- Excellent keep-alive performance
- Lowest VRAM usage
- Good average response time

**Cons:**
- Higher consistency variation (60.1%)

---

### Option 2: Balanced Small
- **Chairman**: `ministral-3:3b` (3.0 GB)
- **Council Members**: `codegemma:2b` (1.6 GB) + `deepseek-coder:1.3b` (776 MB)
- **Total VRAM**: ~5.9 GB
- **Status**: Warning - GPU Memory Pressure Issues

**Results:**
- Average time: 24.05s (within expected range)
- Consistency: 23.8% variation (best)
- Keep-alive: Second query failed (transient) or slower
- Performance: Meets expectations but has issues

**Pros:**
- Best consistency (23.8% variation)
- Fast average response time
- Good model quality

**Cons:**
- GPU memory pressure causing model evictions
- Rapid query test failures/slowdowns
- Models being evicted: `model requires more gpu memory than is currently available, evicting a model to make space`

**Issue Analysis:**
- GPU memory usage: 7116 MB / 8188 MB (87% used)
- When loaded, `ministral-3:3b` uses ~7.7 GB GPU memory
- All three models together exceed available GPU memory
- Ollama evicts models to make space, causing reload delays

---

### Option 3: Medium Performance
- **Chairman**: `qwen2.5-coder:7b` (4.7 GB)
- **Council Members**: `codegemma:2b` (1.6 GB) + `deepseek-coder:1.3b` (776 MB)
- **Total VRAM**: ~7.6 GB
- **Status**: Warning - Acceptable but could be better

**Results:**
- Average time: 31.91s (slightly above expected range)
- Consistency: 55.7% variation
- Keep-alive: 13.4% improvement
- Performance: Acceptable but could be better

**Pros:**
- Larger model may provide better quality
- Keep-alive working

**Cons:**
- Slower average response time
- Higher consistency variation
- Likely GPU memory pressure

---

## Key Findings

### GPU Memory Pressure
- Models use significantly more GPU memory when loaded than their file sizes suggest
- Example: `ministral-3:3b` (3.0 GB file) uses ~7.7 GB when loaded
- Current GPU: 8188 MB total, 7116 MB used (87%)
- Models are being evicted due to insufficient GPU memory

### Model Eviction Behavior
- Ollama logs show: `model requires more gpu memory than is currently available, evicting a model to make space`
- Only chairman model stays loaded; council members are evicted
- This causes reload delays and inconsistent performance

### Keep-Alive Performance
- Option 1: Excellent (68.1% improvement)
- Option 2: Issues due to memory pressure
- Option 3: Working but minimal improvement (13.4%)

---

## Recommendations

### Recommended Configuration: Option 1 (Ultra-Lightweight)

**Why:**
- Best keep-alive performance (68.1% improvement)
- Lowest VRAM usage (~4.3 GB)
- Good average response time (24.75s)
- No GPU memory pressure issues
- Most reliable performance

**Configuration:**
```bash
Chairman: deepseek-coder:1.3b
Council: codegemma:2b,qwen2.5-coder:3b
```

### If Better Quality Needed: Option 2 (with fixes)

**Requirements:**
- Need more GPU memory (16GB+ recommended)
- Or reduce model sizes further
- Or use model quantization

**Current Issues:**
- GPU memory pressure causing evictions
- Need to ensure all models fit in GPU memory simultaneously

### Optimization Suggestions

1. **Increase GPU Memory** (if possible)
   - Current: 8GB GPU
   - Recommended: 16GB+ for Option 2/3

2. **Use Quantized Models**
   - Use Q4 or Q5 quantized versions
   - Reduces GPU memory usage significantly

3. **Adjust OLLAMA_MAX_LOADED_MODELS**
   - Currently: 3 (correct for 3 models)
   - May need to reduce if memory is tight

4. **Monitor GPU Memory**
   - Use `nvidia-smi` to monitor usage
   - Use `docker exec ollama ollama ps` to see loaded models
   - Check Ollama logs for eviction messages

---

## Test Methodology

1. **Multiple Query Test**: 3 queries to measure consistency
2. **Rapid Query Test**: 2 rapid queries to test keep-alive
3. **Expected Performance**: 15-30s first query, 10-20s subsequent queries, <30% variation

## Next Steps

1. Use Option 1 for production (most reliable)
2. If Option 2 needed: Upgrade GPU or use quantized models
3. Monitor GPU memory usage in production
4. Consider model quantization for larger models

