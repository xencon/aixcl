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
- **Date:** 2026-04-23
- **Status:** ⚠️ PARTIAL
- **Engine:** ghcr.io/ggml-org/llama.cpp:server-cuda-b8334
- **Model:** Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf

**Steps Completed:**
1. ✅ Dev container builds successfully
2. ✅ Set engine to llamacpp
3. ⚠️ Stack starts but requires model download

**Issue:**
llama.cpp requires a GGUF model to be downloaded before it can start properly.

**Fix Applied:**
- Fixed entrypoint to use `/app/llama-server` (correct path)
- Added model existence check
- Container exits gracefully if model not found (no crash-loop)

**Next Steps:**
- Add GGUF model: `./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf`
- Restart stack
- Test API

## Summary

| Engine | Status | Notes |
|--------|--------|-------|
| Ollama | ✅ PASS | Fully functional with dev container |
| vLLM | ⚠️ PARTIAL | Entrypoint fixed, GPU runtime issue remains |
| llama.cpp | ⚠️ PARTIAL | Entrypoint fixed, requires GGUF model download |

## Recommendations

1. **Ollama** is production-ready with dev container
2. **vLLM** needs further investigation for GPU runtime issues
3. **llama.cpp** is configured correctly but needs manual model download

## Dev Container Status

| Feature | Status |
|---------|--------|
| Dev Container Build | ✅ PASS |
| Docker-in-Docker | ✅ PASS |
| Host Network Mode | ✅ PASS |
| GPU Passthrough | ✅ PASS |
| OpenCode Integration | ✅ PASS |
| Engine Switching | ✅ PASS |
| Model Management | ✅ PASS (Ollama) |

## Conclusion

The dev container implementation is **successful** with Ollama as the primary engine. vLLM and llama.cpp have configuration fixes applied but require additional setup/testing for full functionality.
