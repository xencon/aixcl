# Performance Optimizations

## Problem

The LLM Council was taking too long to respond, causing poor user experience.

## Root Causes Identified

1. **Verbose Prompts**: Stage 2 and Stage 3 prompts were very long (~70 lines), causing models to generate lengthy responses
2. **Long Timeout**: Default 120 second timeout per model was too high
3. **Sequential Execution**: Stages run sequentially (Stage 1 → Stage 2 → Stage 3), compounding delays

## Optimizations Implemented

### 1. Solution-Only Policy (No Clarification Requests)

**Added explicit instructions:**
- Stage 1: Models must provide solutions, not ask questions
- Stage 2: Provide ranking only, no clarification requests
- Stage 3: Deliver complete solution, make reasonable assumptions

**Impact:** Eliminates back-and-forth delays, implements "fail fast, fix fast" approach

### 2. Condensed Prompts (70% reduction)

**Before (Stage 2):** ~70 lines with detailed explanations
**After (Stage 2):** ~15 lines with essential criteria

**Before (Stage 3):** ~40 lines with detailed framework
**After (Stage 3):** ~10 lines with core requirements

**Impact:** Faster model responses, less token usage, same evaluation quality

### 3. Reduced Timeout (50% reduction)

**Before:** 120 seconds default timeout
**After:** 60 seconds default timeout (configurable via `MODEL_TIMEOUT`)

**Impact:** Faster failure detection, prevents hanging on slow models

### 4. Configurable Timeout

Added `MODEL_TIMEOUT` environment variable for fine-tuning:
- Default: 60 seconds
- Can be adjusted per deployment: `MODEL_TIMEOUT=45.0`

## Expected Performance Improvements

- **No clarification delays:** Eliminates back-and-forth questioning
- **Prompt length reduction:** ~70% fewer tokens → faster generation
- **Timeout reduction:** 50% faster failure detection
- **Overall:** Estimated 50-70% reduction in total response time

## Trade-offs

- Prompts are more concise but retain all evaluation criteria
- Shorter timeout may cause failures on slower models (can be adjusted)
- Evaluation quality maintained through focused criteria

## Configuration

Set `MODEL_TIMEOUT` in `.env` or environment:
```bash
MODEL_TIMEOUT=45.0  # seconds
```

## Monitoring

Watch for:
- Timeout errors (may need to increase `MODEL_TIMEOUT`)
- Response quality (verify evaluation criteria still work)
- Total response time (should be significantly reduced)

