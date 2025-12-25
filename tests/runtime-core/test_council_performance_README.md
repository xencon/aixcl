# User-Focused Performance Test with Benchmarking Metrics

This test script simulates the **real user experience** by testing the council API from outside the container, exactly as users would interact with it. It includes professional benchmarking metrics like tokens/second, model information, and CSV export capabilities.

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
# Basic test (backward compatible)
./tests/runtime-core/run_test.sh

# With warmup (recommended for accurate benchmarks)
./tests/runtime-core/run_test.sh --warmup

# Export results to CSV
./tests/runtime-core/run_test.sh --csv benchmark.csv

# Both warmup and CSV export
./tests/runtime-core/run_test.sh --warmup --csv benchmark.csv

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
- `--csv [FILE]`: Export results to CSV file. If FILE is not specified, uses default: `benchmark_YYYYMMDD_HHMMSS.csv`
- `--no-warmup`: Explicitly disable warmup (default behavior)
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
2. **Disable other workloads**: Ensure no other processes are using GPU
3. **Consistent prompts**: Test uses standardized prompt length (~50 chars)
4. **Multiple runs**: Run several times and compare CSV exports

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
- **Tokens/Second**: Token generation speed (completion_tokens / elapsed_time)
- **Token Breakdown**: Prompt tokens vs completion tokens
- **Consistency**: Variation between multiple queries (lower is better)
- **Keep-Alive**: Improvement on rapid queries (faster second query = models stayed loaded)
- **Model Information**: Model name, quantization level, context size (if available)

### CSV Export Format

When using `--csv`, the output includes:
- `timestamp`: When the test was run
- `model`: Model name (e.g., "council")
- `quantization`: Quantization level (e.g., "q4_0", "q5_0")
- `context_size`: Model context size (if available)
- `prompt_tokens`: Number of prompt tokens
- `completion_tokens`: Number of completion tokens
- `total_tokens`: Total tokens used
- `elapsed_seconds`: Response time in seconds
- `tokens_per_second`: Token generation speed
- `query_number`: Query sequence number
- `test_type`: "consistency" or "rapid"

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

