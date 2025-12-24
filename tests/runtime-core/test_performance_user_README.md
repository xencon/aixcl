# User-Focused Performance Test

This test script simulates the **real user experience** by testing the council API from outside the container, exactly as users would interact with it.

## What It Tests

1. **Multiple Query Test**: Runs 3 council queries to measure:
   - Average response time
   - Performance consistency
   - Response quality

2. **Rapid Query Test**: Tests two queries in quick succession to verify:
   - Keep-alive effectiveness (models staying loaded)
   - Performance improvement on second query

## Running the Test

### Prerequisites

1. Services must be running: `./aixcl stack start`
2. Council must be configured: `./aixcl council configure`
3. Install httpx using one of these methods:

**Option 1: Install globally (simplest)**

First, install pip if not already installed:
```bash
# On Ubuntu/Debian
sudo apt update
sudo apt install python3-pip

# Then install httpx
pip3 install httpx

# Run test
python3 tests/runtime-core/test_performance_user.py
```

**Option 2: Use virtual environment (recommended)**
```bash
# Setup venv (first time only)
./tests/runtime-core/setup_test_env.sh

# Run test
source tests/runtime-core/.venv/bin/activate
python3 tests/runtime-core/test_performance_user.py
```

**Option 3: Use wrapper script (easiest - auto-setup)**
```bash
./tests/runtime-core/run_test.sh
```

**Option 4: Use uv (if installed)**
```bash
cd llm-council
uv sync
uv run python ../tests/runtime-core/test_performance_user.py
```

### Run the Test

```bash
# From project root (after installing httpx)
python3 tests/runtime-core/test_performance_user.py

# Or use the wrapper script (handles venv setup automatically)
./tests/runtime-core/run_test.sh
```

## What to Expect

### With Optimizations Working

- **First query**: 15-30 seconds (includes model loading)
- **Subsequent queries**: 10-20 seconds (models stay loaded)
- **Consistency**: <30% variation between queries
- **Rapid queries**: Second query should be faster (10-30% improvement)

### Performance Indicators

**Good Performance**:
- ✅ Average time < 30s
- ✅ Second query faster than first
- ✅ Consistent response times

**Needs Tuning**:
- ⚠️ Average time 30-45s (acceptable but could be better)
- ⚠️ Second query similar to first (keep-alive may need tuning)

**Issues**:
- ❌ Average time > 45s (check GPU memory, model sizes)
- ❌ High variation between queries (check Ollama logs)

## Interpreting Results

The test measures **real user experience** - the time from when a user sends a request to when they receive a response through the council API.

### Key Metrics

- **Elapsed Time**: Total time for complete council workflow (Stage 1 → Stage 2 → Stage 3)
- **Consistency**: Variation between multiple queries (lower is better)
- **Keep-Alive**: Improvement on rapid queries (faster second query = models stayed loaded)

## Troubleshooting

### Slow Performance

1. **Check GPU memory**: `nvidia-smi`
   - If VRAM is full, reduce `OLLAMA_MAX_LOADED_MODELS`
   - Consider using smaller quantized models

2. **Check Ollama logs**: `docker logs ollama`
   - Look for errors or warnings
   - Verify environment variables are recognized

3. **Verify optimizations**: `docker exec ollama env | grep OLLAMA`
   - Should show all optimization variables

### Inconsistent Performance

1. **Models reloading**: Increase `OLLAMA_KEEP_ALIVE` to 1800 (30 min)
2. **GPU memory pressure**: Reduce `OLLAMA_MAX_LOADED_MODELS`
3. **Check model sizes**: Ensure models fit in VRAM

## Next Steps

After reviewing results:

1. **If performance is good**: Monitor during normal usage
2. **If performance needs tuning**: Adjust environment variables in `docker-compose.yml`
3. **If issues persist**: Check Ollama logs and GPU memory usage

