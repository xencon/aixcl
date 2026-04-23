# Test Plan Improvement Analysis

| Field | Value |
|-------|-------|
| **Issue** | #871 |
| **Date** | 2026-04-23 |
| **Analyst** | AI Assistant |
| **Status** | ANALYSIS COMPLETE |

---

## Executive Summary

Analysis of the current engine-switching-test-plan.md (v1.0) reveals gaps in test coverage for comprehensive engine-model integration. This document provides detailed recommendations for expanding test coverage.

---

## Current State Analysis

### Existing Test Plan Coverage

| Phase | Current Coverage | Gap Analysis |
|-------|-----------------|--------------|
| Phase 1: Environment Setup | Basic prerequisite check | Missing: CUDA version validation, disk space requirements |
| Phase 2: Engine Switching | 1 model per engine (0.5B) | Missing: Multi-model support, model eviction testing |
| Phase 3: Prompt Testing | 3 prompts with scoring | Missing: Automated scoring, regression tracking |
| Phase 4: OpenCode Integration | Basic connectivity | Missing: End-to-end workflow validation |

### Current Test Scripts

| Test | Purpose | Model Coverage |
|------|---------|----------------|
| test-07-models-add-ollama.sh | Add Ollama model | qwen2.5-coder:0.5b only |
| test-08-models-add-vllm.sh | Add vLLM model | Qwen/Qwen2.5-Coder-0.5B-Instruct only |
| test-09-models-add-llamacpp.sh | Add llama.cpp model | 0.5B GGUF only |

### Model Coverage Gap

From model-recommendations.md:

| Engine | Recommended Models | Currently Tested | Coverage % |
|--------|-------------------|------------------|------------|
| Ollama | 0.5b, 1.5b, 3b, 7b, 14b | 0.5b | 20% |
| vLLM | 0.5B, 1.5B, 3B, 7B, 14B | 0.5B | 20% |
| llama.cpp | 0.5B, 1.5B, 3B GGUF | 0.5B GGUF | 33% |

---

## Recommended Improvements

### 1. Expanded Model Matrix Testing

Create a comprehensive test matrix:

```
Engine × Model Matrix (Target Coverage)

Ollama:
  ✓ qwen2.5-coder:0.5b  [TEST-07]
  ○ qwen2.5-coder:1.5b  [NEW]
  ○ qwen2.5-coder:3b    [NEW]
  ○ qwen2.5-coder:7b    [NEW]
  ○ qwen2.5-coder:14b   [NEW - ops profile]

vLLM:
  ✓ Qwen/Qwen2.5-Coder-0.5B-Instruct  [TEST-08]
  ○ Qwen/Qwen2.5-Coder-1.5B-Instruct [NEW]
  ○ Qwen/Qwen2.5-Coder-3B-Instruct   [NEW]
  ○ Qwen/Qwen2.5-Coder-7B-Instruct   [NEW - requires 8GB+]
  ○ Qwen/Qwen2.5-Coder-14B-Instruct  [NEW - requires 16GB+]

llama.cpp:
  ✓ qwen2.5-coder-0.5b-instruct-q4_k_m.gguf  [TEST-09]
  ○ qwen2.5-coder-1.5b-instruct-q4_k_m.gguf  [NEW]
  ○ qwen2.5-coder-3b-instruct-q4_k_m.gguf    [NEW]
  ○ qwen2.5-coder-7b-instruct-q4_k_m.gguf    [NEW - requires 8GB+]
  ○ qwen2.5-coder-14b-instruct-q4_k_m.gguf   [NEW - requires 16GB+]
```

### 2. Integration Test Suite (NEW)

Create test-16-engine-model-integration.sh:

**Test Flow:**
1. Capture initial state
2. Engine set <ENGINE>
3. Stack start --profile <PROFILE>
4. For each model in engine's model list:
   - models add <MODEL>
   - Verify opencode.json updated
   - API test (curl /v1/models)
   - Prompt response test (optional)
   - models remove <MODEL> (if supported)
5. Stack stop
6. Restore state

**Validation Points:**
- Engine switch successful
- All models load without error
- opencode.json correctly synced for each model
- API responds for each model
- Clean state after completion

### 3. Multi-Model Concurrent Testing (NEW)

Create test-17-multi-model-loading.sh:

**Purpose:** Validate Ollama multi-model support (vLLM and llamacpp are single-model)

**Test:**
- Load 0.5b + 1.5b simultaneously
- Verify both respond via API
- Verify VRAM usage is within expected range
- Test model eviction when loading exceeds VRAM

**Validation:**
- OLLAMA_MAX_LOADED_MODELS respected
- Proper model eviction behavior
- No crashes during transitions

### 4. Engine-Model Compatibility Validation (NEW)

Create test-18-engine-model-compatibility.sh:

**Negative Tests:**

| Attempt | Expected Result |
|---------|-----------------|
| Ollama + GGUF format | Error: unsupported format |
| vLLM + Ollama registry model | Error: use HF format |
| llamacpp + safetensors | Error: use GGUF format |
| llamacpp + Ollama registry | Error: use HF GGUF |

**Purpose:** Ensure proper error messages for incompatible combinations.

### 5. Performance Benchmark Tests (NEW)

Create test-19-model-performance.sh:

**Metrics:**
- Time to first token (cold start)
- Time to first token (warm)
- Tokens/second generation rate
- VRAM usage per model
- Model load/unload time

**Test Prompt:** Standardized prompt for consistency

**Expected Results (Reference):**

| Model | Cold Start | Warm | Tokens/sec | VRAM |
|-------|------------|------|------------|------|
| 0.5B | 3-5s | <1s | 50-100 | ~1GB |
| 1.5B | 5-10s | 1-2s | 40-80 | ~2.5GB |
| 3B | 10-20s | 2-4s | 30-60 | ~5GB |
| 7B | 20-30s | 4-6s | 20-40 | ~9GB |
| 14B | 30-45s | 6-10s | 10-25 | ~18GB |

### 6. Profile-Specific Testing (NEW)

Create test-20-profile-validation.sh:

**Test Matrix:**

| Profile | Engine | Models to Test |
|---------|--------|----------------|
| usr | ollama | 0.5b, 1.5b |
| dev | ollama/vllm | 1.5b, 3b, 7b |
| ops | ollama | 7b, 14b |
| sys | all | all models |

---

## Implementation Priority

| Priority | Test | Effort | Impact |
|----------|------|--------|--------|
| P1 | test-16-engine-model-integration.sh | Medium | High |
| P1 | Expand test-07-09 for multi-model | Medium | High |
| P2 | test-17-multi-model-loading.sh | Medium | Medium |
| P2 | test-18-engine-model-compatibility.sh | Low | Medium |
| P3 | test-19-model-performance.sh | High | Medium |
| P3 | test-20-profile-validation.sh | Medium | Low |

---

## Test Plan Document Updates

### Phase 1: Document Structure

Update engine-switching-test-plan.md:
1. Update version to 2.0
2. Update date
3. Add new sections for:
   - Multi-model testing
   - Integration workflow
   - Performance benchmarks
   - Profile-specific tests

### Phase 2: New Test Procedures

Add sections:

```markdown
### Phase 2.5: Multi-Model Testing (Ollama only)

Test OLLAMA_MAX_LOADED_MODELS behavior:
1. Set OLLAMA_MAX_LOADED_MODELS=3
2. Load 0.5b, 1.5b, 3b sequentially
3. Verify all loaded: docker exec ollama ollama ps
4. Load 7b (should trigger eviction)
5. Verify oldest model evicted

Pass Criteria:
- [ ] Models loaded up to limit
- [ ] Eviction works correctly
- [ ] API responds for loaded models
```

### Phase 3: Scoring Updates

Add multi-model scoring:
- Model load time: 20 points
- API response: 30 points
- opencode.json sync: 30 points
- Clean shutdown: 20 points

---

## Files to Create/Modify

### New Files

| File | Purpose | Lines Est. |
|------|---------|------------|
| tests/command-tests/test-16-engine-model-integration.sh | Full integration test | 150 |
| tests/command-tests/test-17-multi-model-loading.sh | Ollama multi-model | 100 |
| tests/command-tests/test-18-engine-model-compatibility.sh | Error validation | 80 |
| tests/command-tests/test-19-model-performance.sh | Benchmark suite | 200 |
| tests/command-tests/test-20-profile-validation.sh | Profile testing | 120 |

### Modified Files

| File | Changes |
|------|---------|
| docs/operations/engine-switching-test-plan.md | v2.0 updates |
| tests/command-tests/test-07-models-add-ollama.sh | Multi-model expansion |
| tests/command-tests/test-08-models-add-vllm.sh | Multi-model expansion |
| tests/command-tests/test-09-models-add-llamacpp.sh | Multi-model expansion |
| docs/operations/model-recommendations.md | Test coverage matrix |

---

## Verification Checklist

- [ ] All new tests pass
- [ ] Existing tests continue to pass
- [ ] Test plan document updated
- [ ] Coverage matrix documented
- [ ] Performance baselines established
- [ ] Integration test validates full workflow

---

## Next Steps

1. Review and approve Issue #871
2. Create branch for implementation
3. Implement P1 items first
4. Run full test suite
5. Update documentation
6. Create PR for review

---

*Analysis completed for Issue #871*
