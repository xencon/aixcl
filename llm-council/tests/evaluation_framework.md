# Objective Evaluation Framework

## Purpose

This framework provides objective criteria for evaluating LLM Council responses. Evaluations inform the council's principles and should be direct, factual, and focused on key reasoning points.

## Evaluation Criteria (Weighted)

### 1. Functional Correctness (40%)
**Key Questions:**
- Does it solve the stated problem?
- Does it match the required function signature?
- Are all edge cases handled?
- Do examples work as expected?

**Scoring:**
- 40/40: Perfect match, all cases handled
- 30-39: Minor edge case issues
- 20-29: Some requirements missed
- 10-19: Significant gaps
- 0-9: Wrong problem or broken

### 2. Security (20%)
**Key Questions:**
- Is input validated properly?
- Are there injection vulnerabilities?
- Are error messages safe (no information leakage)?
- Are edge cases handled securely?

**Scoring:**
- 20/20: No security concerns
- 15-19: Minor concerns
- 10-14: Moderate concerns
- 5-9: Significant security issues
- 0-4: Critical vulnerabilities

### 3. Code Quality (15%)
**Key Questions:**
- Is code readable and clear?
- Is there appropriate documentation?
- Are naming conventions followed?
- Is error handling appropriate?

**Scoring:**
- 15/15: Excellent quality
- 12-14: Good quality
- 9-11: Acceptable quality
- 6-8: Poor quality
- 0-5: Very poor quality

### 4. Performance (10%)
**Key Questions:**
- What is the time complexity?
- What is the space complexity?
- Are appropriate data structures used?
- Is it efficient for the problem size?

**Scoring:**
- 10/10: Optimal complexity
- 8-9: Good efficiency
- 6-7: Acceptable efficiency
- 4-5: Inefficient
- 0-3: Very inefficient

### 5. Maintainability (10%)
**Key Questions:**
- Is code modular and well-structured?
- Can it be easily extended?
- Is separation of concerns maintained?
- Is it easy to understand?

**Scoring:**
- 10/10: Highly maintainable
- 8-9: Good maintainability
- 6-7: Acceptable
- 4-5: Difficult to maintain
- 0-3: Very difficult

### 6. Standard Practices (5%)
**Key Questions:**
- Does it use standard library when available?
- Does it follow language conventions?
- Is it a proven, conservative approach?
- Or is it exotic/experimental?

**Scoring:**
- 5/5: Uses standard library/conventions
- 4: Mostly standard
- 3: Some custom code
- 2: Mostly custom
- 0-1: Exotic/experimental approach

## Evaluation Format

**Direct Summary Format:**

```
Score: X/100

Key Points:
- Correctness: [Brief assessment]
- Security: [Brief assessment]
- Code Quality: [Brief assessment]
- Performance: [Brief assessment]
- Maintainability: [Brief assessment]
- Standard Practices: [Brief assessment]

Ranking: [Should be ranked #X]
```

## Principles for Council

Based on evaluations, the council should:
1. Prioritize correctness above all
2. Flag security concerns immediately
3. Prefer standard library solutions
4. Value simplicity and clarity
5. Reject solutions that don't solve the stated problem

