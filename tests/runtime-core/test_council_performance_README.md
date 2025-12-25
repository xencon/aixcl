# User-Focused Performance Test with Benchmarking Metrics

This test script simulates the **real user experience** by testing the council API from outside the container, exactly as users would interact with it. It includes professional benchmarking metrics like tokens/second, model information, and aggregated results from multiple iterations.

## What It Tests

1. **Multiple Query Test**: Runs 3 council queries to measure:
   - Average response time
   - Performance consistency
   - Response quality
   - Token generation speed (tokens/sec)
   - Token breakdown (prompt vs completion)

2. **Rapid Query Test**: Tests two queries in quick succession to verify:
   - Keep-alive effectiveness (models staying loaded)
   - Performance improvement on second query
   - Token speed comparison

## Running the Test

### Prerequisites

1. Services must be running: `./aixcl stack start`
2. Council must be configured: `./aixcl council configure`

### Main Entry Point (Recommended)

**Use the wrapper script** - it handles all setup automatically:

```bash
# Basic test (single iteration)
./tests/runtime-core/run_test.sh

# With warmup (recommended for accurate benchmarks)
./tests/runtime-core/run_test.sh --warmup

# Run multiple iterations and aggregate results
./tests/runtime-core/run_test.sh --iterations 5

# Warmup + multiple iterations (recommended for reliable benchmarks)
./tests/runtime-core/run_test.sh --warmup --iterations 3

# Show help
./tests/runtime-core/run_test.sh --help
```

The wrapper script automatically:
- Checks if httpx is available
- Sets up virtual environment if needed
- Installs httpx if missing
- Passes all arguments to the Python script

### Alternative Methods

**Option 1: Direct Python execution (if httpx is installed)**
```bash
python3 tests/runtime-core/test_council_performance.py [OPTIONS]
```

**Option 2: Use uv (if installed)**
```bash
cd llm-council
uv sync
uv run python ../tests/runtime-core/test_council_performance.py [OPTIONS]
```

### Command-Line Options

- `--warmup`: Warm up models before benchmarking (recommended for accurate results)
- `--no-warmup`: Explicitly disable warmup (default behavior)
- `--iterations N`: Run benchmark N times and report mean values (default: 1). Results will be aggregated and mean values with standard deviation will be displayed.
- `--help` or `-h`: Show help message

## What to Expect

### With Optimizations Working

- **First query**: 15-30 seconds (includes model loading)
- **Subsequent queries**: 10-20 seconds (models stay loaded)
- **Consistency**: <30% variation between queries
- **Rapid queries**: Second query should be faster (10-30% improvement)
- **Token speed**: Varies by model, typically 20-100+ tokens/sec for quantized models

### Benchmarking Best Practices

For accurate benchmarks:
1. **Use warmup**: Run with `--warmup` flag to pre-load models
2. **Use multiple iterations**: Run with `--iterations 3` or more to get aggregated mean values and reduce impact of outliers
3. **Disable other workloads**: Ensure no other processes are using GPU
4. **Consistent prompts**: Test uses standardized prompt length (~50 chars)
5. **Review aggregated results**: When using `--iterations`, the output shows mean values ± standard deviation for more reliable measurements

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
  - When using `--iterations`, shows mean ± standard deviation (e.g., `12.34±1.23`)
- **Tokens/Second**: Token generation speed (completion_tokens / elapsed_time)
- **Token Breakdown**: Prompt tokens vs completion tokens
- **Consistency**: Variation between multiple queries (lower is better)
- **Keep-Alive**: Improvement on rapid queries (faster second query = models stayed loaded)
- **Model Information**: Model name, quantization level, context size (if available)
- **Performance Score**: At-a-glance performance metric (0-200 for individual models, 0-100 for council)
- **Runs**: Number of successful test runs included in aggregated results (when using `--iterations`)

### Aggregated Results (Multiple Iterations)

When using `--iterations N`, the benchmark:
- Runs all tests N times
- Aggregates results by model and test type
- Calculates mean values for all metrics
- Computes standard deviation for elapsed time
- Shows min/max ranges in insights
- Displays aggregated results in the benchmark table with "Runs" column showing the number of successful runs

This provides more reliable performance measurements by averaging across multiple iterations, reducing the impact of outliers and variability.

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

