# Performance Test Results - Multi-Model Configuration Comparison

## Test Date
April 6, 2026

## Test Configurations

All tests use Qwen 2.5 Coder instruct models across different sizes.

### Configuration 1: Ultra-Lightweight (Balanced)

- **Primary Model**: `qwen2.5-coder:1.5b` (~1 GB)
- **Auxiliary Models**: `qwen2.5-coder:0.5b` (~400 MB) + `qwen2.5-coder:3b` (~2 GB)
- **Total VRAM**: ~3.4 GB
- **Status**: Recommended for 4-6GB GPUs and edge devices

**Results:**
- Average time: 18.2s
- Keep-alive: 72.5% improvement
- Performance: Excellent for lightweight tasks

**Pros:**
- Excellent keep-alive performance
- Very low VRAM usage
- Fast response times
- Can run on integrated GPUs

---

### Configuration 2: Development Workstation (Recommended)

- **Primary Model**: `qwen2.5-coder:7b` (~4.5 GB)
- **Auxiliary Models**: `qwen2.5-coder:1.5b` (~1 GB) + `qwen2.5-coder:3b` (~2 GB)
- **Total VRAM**: ~7.5 GB
- **Status**: Recommended for 8GB GPUs

**Results:**
- Average time: 28.5s
- Consistency: 15.3% variation
- Performance: Best balance of quality and speed

**Pros:**
- 7B model for complex tasks
- Fast 1.5B for quick queries
- All models fit in 8GB VRAM
- Reliable multi-model switching

**Cons:**
- Requires 8GB+ GPU for optimal performance
- Monitor VRAM when running additional services

---

### Configuration 3: High Performance

- **Primary Model**: `qwen2.5-coder:14b` (~9 GB)
- **Auxiliary Model**: `qwen2.5-coder:3b` (~2 GB)
- **Total VRAM**: ~11 GB
- **Status**: Requires 12GB+ GPU

**Results:**
- Average time: 42.1s
- Keep-alive: 25.8% improvement
- Performance: Highest quality outputs

**Pros:**
- 14B model for demanding tasks
- Excellent reasoning capabilities
- Better long-context handling

**Cons:**
- Requires 16GB GPU recommended
- Slower initial load time
- Higher VRAM requirements

---

## Key Findings

### GPU Memory Usage

Qwen 2.5 Coder models use approximately 2-2.5x their file size in VRAM when loaded:

| Model | File Size | VRAM Usage |
|-------|-----------|------------|
| 0.5B | ~400 MB | ~1 GB |
| 1.5B | ~1 GB | ~2.5 GB |
| 3B | ~2 GB | ~5 GB |
| 7B | ~4.5 GB | ~9 GB |
| 14B | ~9 GB | ~18 GB |

### Model Eviction

When VRAM is exhausted, Ollama logs show:
`model requires more gpu memory than is currently available, evicting a model to make space`

This causes reload delays (15-45s) for subsequent queries.

### Keep-Alive Performance

| Configuration | Improvement | Notes |
|---------------|-------------|-------|
| Ultra-Lightweight | 72.5% | All models stay resident |
| Development | 68.1% | Fits in 8GB with headroom |
| High Performance | 25.8% | Requires 12GB+ GPU |

---

## Recommendations

### Primary Recommendation: Development Workstation (Configuration 2)

**Setup:**
```bash
./aixcl models add qwen2.5-coder:1.5b qwen2.5-coder:3b qwen2.5-coder:7b
```

**Why:**
- Best balance of quality and performance
- Fits in 8GB VRAM comfortably
- Handles most coding tasks effectively
- Multiple sizes for different use cases

### For Resource-Constrained Environments: Ultra-Lightweight (Configuration 1)

**Setup:**
```bash
./aixcl models add qwen2.5-coder:0.5b qwen2.5-coder:1.5b
```

**Why:**
- Minimal VRAM requirements (~3.5GB)
- Runs on integrated GPUs
- Fast response times
- Good for testing and demos

### For Maximum Quality: High Performance (Configuration 3)

**Setup:**
```bash
./aixcl models add qwen2.5-coder:7b qwen2.5-coder:14b
```

**Why:**
- 14B model for demanding tasks
- Requires 16GB GPU
- Best for production use with dedicated hardware

---

## Optimization Guidelines

1. **Monitor VRAM Usage**
   ```bash
   nvidia-smi
   docker exec ollama ollama ps
   ```

2. **Adjust OLLAMA_MAX_LOADED_MODELS**
   - Set to number of models you want resident
   - For 8GB GPU: 3 models max
   - For 16GB GPU: 4-5 models possible

3. **Use Keep-Alive**
   - Set `OLLAMA_KEEP_ALIVE=1800` (30 minutes)
   - Prevents eviction during active sessions

4. **Choose Appropriate Size**
   - 0.5B/1.5B: Fast autocomplete, simple queries
   - 3B: General coding assistance
   - 7B: Complex tasks, code review
   - 14B: Maximum quality, long contexts

---

## Test Methodology

1. **Cold Start Test**: Measure time to first token after fresh load
2. **Warm Query Test**: Measure response time with model already loaded
3. **Rapid Switching Test**: Switch between models in quick succession
4. **Concurrency Test**: Multiple simultaneous queries
5. **Long-Running Test**: 30-minute session to test keep-alive

All tests performed on NVIDIA 40-series GPU with default Ollama settings unless otherwise noted.
