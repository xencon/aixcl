# AIXCL Engine Test Report

**Test Date**: 2025-01-20  
**Status**: ALL ENGINES WORKING ✓

---

## Summary

| Engine | Status | Key Fixes Applied |
|--------|--------|-------------------|
| **Ollama** | ✓ WORKING | Fully functional |
| **vLLM** | ✓ WORKING | Disabled CUDA graphs, reduced memory usage, added `--enforce-eager` |
| **llama.cpp** | ✓ WORKING | Fixed model key extraction (filename only) |

---

## Fixes Applied

### Fix 1: vLLM Configuration (CRITICAL)
**File**: `services/docker-compose.yml`

**Changes**:
- Added `--enforce-eager` flag (disables CUDA graphs)
- Reduced `--gpu-memory-utilization` from 0.8 to 0.6
- Reduced `--max-model-len` from 32768 to 8192
- Added `VLLM_CUDA_GRAPH_CAPTURE=0` environment variable
- Changed default model from invalid GGUF to valid HF model

**Result**: vLLM now works on RTX 4060 Laptop GPU

### Fix 2: llama.cpp Model Key Format
**File**: `lib/aixcl/commands/models.sh`

**Changes**:
- Extract filename only for llama.cpp model keys in opencode.json
- Full HF path no longer stored as model key

**Result**: Model keys consistent with expected format

---

## Test Results

### Ollama
```bash
./aixcl engine set ollama
./aixcl stack start --profile usr
./aixcl models add qwen2.5-coder:0.5b
# Result: ✓ Working
```

### vLLM
```bash
./aixcl engine set vllm
./aixcl stack start --profile usr
./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct
# Result: ✓ Working (with CUDA fixes)
```

### llama.cpp
```bash
./aixcl engine set llamacpp
./aixcl stack start --profile usr
./aixcl models add Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf
# Result: ✓ Working (model key fix applied)
```

---

## API Verification

All engines respond correctly on `http://localhost:11434/v1/models`

---

## Current State

**Active Engine**: vLLM  
**Model**: Qwen/Qwen2.5-Coder-0.5B-Instruct  
**Status**: Running and healthy

---

## Files Modified

1. `lib/aixcl/commands/models.sh` - llama.cpp model key fix
2. `services/docker-compose.yml` - vLLM configuration fixes

---

## Ready for Commit

All three engines (Ollama, vLLM, llama.cpp) are now working correctly.
