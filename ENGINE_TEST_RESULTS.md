# AIXCL Engine Testing Results

## Test Log

### Test 1: Ollama Engine (Baseline)
- **Date:** 2026-04-23
- **Status:** ✅ PASSED
- **Engine:** ollama:0.20.5
- **Model:** qwen2.5-coder:0.5b
- **Notes:** Successfully tested with dev container. All services healthy.

---

### Test 2: vLLM Engine
- **Date:** 2026-04-23
- **Status:** ⚠️ PARTIAL
- **Engine:** vllm/vllm-openai:v0.19.0
- **Model:** Qwen/Qwen2.5-Coder-0.5B-Instruct

**Steps Completed:**
1. ✅ Dev container builds successfully
2. ✅ Set engine to vllm
3. ⚠️ Stack starts but vLLM has runtime errors

**Issue:**
vLLM container fails with engine core initialization error:
```
RuntimeError: Engine core initialization failed. See root cause above.
```

This appears to be a GPU/CUDA initialization issue within the vLLM container.

**Root Cause:**
vLLM v0.19.0 may have compatibility issues with certain GPU configurations or requires additional CUDA environment variables.

**Next Steps:**
- Try vLLM with `--enforce-eager` flag (already set in docker-compose.gpu.yml)
- Check CUDA driver compatibility
- Consider updating vLLM version or using different startup parameters

---

### Test 3: llama.cpp Engine
- **Date:** TBD
- **Status:** ⏳ PENDING
- **Engine:** ghcr.io/ggml-org/llama.cpp:server-cuda-b8334
- **Model:** Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf

## Summary

| Engine | Status | Notes |
|--------|--------|-------|
| Ollama | ✅ PASS | Fully functional |
| vLLM | ⚠️ PARTIAL | Entrypoint fixed, but runtime GPU issue |
| llama.cpp | ⏳ PENDING | Not yet tested |

## Recommendations

1. **Ollama** is production-ready with dev container
2. **vLLM** needs further investigation for GPU runtime issues
3. **llama.cpp** testing pending
