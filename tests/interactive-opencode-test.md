# Interactive OpenCode Engine Test

## Overview

This test verifies that OpenCode can successfully connect to and use each inference engine.

## Prerequisites

- All three engines configured and tested (Ollama, vLLM, llama.cpp)
- OpenCode CLI available: `which opencode`
- Current directory: repository root

## Test Procedure

### Step 1: Prepare Environment

```bash
cd aixcl
```

### Step 2: Test Each Engine

For each engine, follow these steps:

#### Engine Test Template

1. **Switch to engine**:
   ```bash
   ./aixcl engine set <ENGINE>
   ./aixcl stack start --profile usr
   ./aixcl models add <MODEL>
   ./aixcl stack restart
   ```

2. **Wait for API ready**:
   ```bash
   curl -s http://localhost:11434/v1/models
   # Should return model information
   ```

3. **Start OpenCode**:
   ```bash
   ./opencode
   ```

4. **Run the three test prompts** (record response time and quality)

5. **Exit OpenCode**: Type `/exit` or press Ctrl+C

6. **Stop stack**:
   ```bash
   ./aixcl stack stop
   ```

---

## Standard Test Prompts

### Prompt 1: Easy (String Manipulation)
**Category**: Basic Python
**Expected Time**: 5-15 seconds
**Expected Quality**: Complete, correct, well-formatted

```
Write a Python function that reverses a string without using the built-in reverse() method or [::-1] slicing. Include docstring and example usage.
```

**Scoring Criteria**:
- [ ] Function works correctly
- [ ] No forbidden methods used
- [ ] Includes docstring
- [ ] Includes examples
- [ ] Good variable naming

**Score**: ___/100
**Time**: ___ seconds

---

### Prompt 2: Medium (Algorithm Implementation)
**Category**: Data Structures & Algorithms
**Expected Time**: 15-30 seconds
**Expected Quality**: Correct implementation with complexity analysis

```
Implement a binary search algorithm in Python that finds the first and last occurrence of a target value in a sorted array that may contain duplicates. Return the indices as a tuple [first, last] or [-1, -1] if not found. Include time/space complexity analysis.
```

**Scoring Criteria**:
- [ ] Handles duplicates correctly
- [ ] Returns correct indices
- [ ] O(log n) time complexity
- [ ] Edge cases handled (empty array, not found)
- [ ] Complexity analysis included

**Score**: ___/100
**Time**: ___ seconds

---

### Prompt 3: Hard (System Design with Concurrency)
**Category**: Advanced Python / System Design
**Expected Time**: 30-60 seconds
**Expected Quality**: Production-ready code with thread safety

```
Create a Python decorator that implements a rate limiter using the token bucket algorithm. The decorator should accept `rate` (tokens per second) and `burst` (maximum bucket size) parameters. Ensure thread safety using proper synchronization. Include a demonstration with concurrent requests.
```

**Scoring Criteria**:
- [ ] Correct token bucket implementation
- [ ] Thread-safe (uses locks appropriately)
- [ ] Proper decorator signature preservation
- [ ] Configurable parameters
- [ ] Includes working demonstration
- [ ] Memory efficient

**Score**: ___/100
**Time**: ___ seconds

---

## Test Results Form

### Engine 1: Ollama
**Model**: qwen2.5-coder:0.5b

| Prompt | Difficulty | Response Time | Score (1-100) | Notes |
|--------|------------|---------------|---------------|-------|
| 1 | Easy | ___ sec | ___ | |
| 2 | Medium | ___ sec | ___ | |
| 3 | Hard | ___ sec | ___ | |

**Average Response Time**: ___ seconds  
**Average Score**: ___/100  
**Overall Status**: ☐ PASS  ☐ FAIL

---

### Engine 2: vLLM
**Model**: Qwen/Qwen2.5-Coder-0.5B-Instruct

| Prompt | Difficulty | Response Time | Score (1-100) | Notes |
|--------|------------|---------------|---------------|-------|
| 1 | Easy | ___ sec | ___ | |
| 2 | Medium | ___ sec | ___ | |
| 3 | Hard | ___ sec | ___ | |

**Average Response Time**: ___ seconds  
**Average Score**: ___/100  
**Overall Status**: ☐ PASS  ☐ FAIL

---

### Engine 3: llama.cpp
**Model**: qwen2.5-coder-0.5b-instruct-q4_k_m.gguf

| Prompt | Difficulty | Response Time | Score (1-100) | Notes |
|--------|------------|---------------|---------------|-------|
| 1 | Easy | ___ sec | ___ | |
| 2 | Medium | ___ sec | ___ | |
| 3 | Hard | ___ sec | ___ | |

**Average Response Time**: ___ seconds  
**Average Score**: ___/100  
**Overall Status**: ☐ PASS  ☐ FAIL

---

## Summary Comparison

| Engine | Avg Response Time | Avg Score | Best For |
|--------|-------------------|-----------|----------|
| Ollama | | | |
| vLLM | | | |
| llama.cpp | | | |

---

## Scoring Guidelines

### Response Time Scoring (30%)
- **30 points**: Under expected time
- **20-29 points**: Within expected time
- **10-19 points**: 1.5x expected time
- **0-9 points**: >2x expected time

### Code Quality Scoring (40%)
- **36-40 points**: Production-ready, no issues
- **28-35 points**: Minor issues, mostly correct
- **20-27 points**: Functional but needs work
- **0-19 points**: Significant problems

### Completeness Scoring (30%)
- **30 points**: Full solution with all requirements
- **20-29 points**: Most requirements met
- **10-19 points**: Partial solution
- **0-9 points**: Incomplete or broken

---

## Notes

- Use a stopwatch or timer to measure response time accurately
- Score based on first response only (no follow-up corrections)
- Consider both correctness and code style
- Document any errors or connection issues
- Note if model hallucinates or produces invalid code

---

*Test template version 1.0*
