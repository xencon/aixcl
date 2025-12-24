# Evaluation Learnings and System Prompt Updates

## Issues Identified from Evaluations

### Challenge 1 Learnings
- ✅ Good: Simple solutions using standard library (`s[::-1]`) score high
- ❌ Bad: Wrong function names (`process` instead of `reverse_string`) reduce score
- ❌ Bad: Wrong empty string handling reduces score

### Challenge 2 Learnings
- ❌ Critical: Wrong function signatures (returning `bool` instead of `tuple[bool, str]`) are major issues
- ❌ Critical: Missing error messages when required reduces correctness score
- ❌ Critical: Missing normalization (lowercase, trim) reduces correctness score
- ⚠️ Issue: High confidence (95%) doesn't match actual correctness when requirements aren't met
- ✅ Good: Using standard library (`email.utils`) improves score

## Updates Made to System Prompts

### Stage 1 (Individual Responses)
**Added:**
- "Solve ONLY the stated problem. Do not add extra functions or features."
- "Match function signatures exactly as specified."
- "Do NOT read files or interpret challenge descriptions as input."

### Stage 2 (Peer Ranking)
**Added:**
- Detailed sub-questions for each criterion
- Explicit red flags list:
  - Wrong function signature
  - Missing required functionality
  - Extra unrelated functions
  - Logic errors/bugs
  - Misunderstanding problem
- "Rank solutions with extra code or wrong signatures lowest"

### Stage 3 (Synthesis)
**Added:**
- "REJECT solutions that don't match function signature"
- Confidence guidelines with explicit ranges:
  - 90-100%: Perfect match
  - 70-89%: Good solution (minor issues)
  - 50-69%: Partial solution (wrong signature OR missing requirements)
  - 30-49%: Poor solution (multiple issues)
  - 0-29%: Wrong solution
- "If function signature doesn't match requirements, confidence MUST be below 70%"
- "If key requirements are missing, confidence MUST be below 60%"

### Confidence Calculation (Backend)
**Added automatic penalties:**
- Wrong return type detected → -30 points
- Missing error messages → -20 points
- Missing normalization → -15 points
- Minimum confidence floor: 30%

## Principles Documented

**File:** `llm-council/COUNCIL_PRINCIPLES.md`

Contains:
- 10 core principles
- Evaluation criteria with weights
- Red flags to flag
- Examples of good vs bad responses
- Implementation guidelines for each stage

## Key Improvements

1. **Function Signature Enforcement**
   - Stage 1: Explicit instruction to match signatures
   - Stage 2: Red flag for wrong signatures
   - Stage 3: Reject wrong signatures, confidence penalty
   - Backend: Automatic detection and penalty

2. **Confidence Calibration**
   - Guidelines provided to chairman
   - Automatic penalties for correctness issues
   - Confidence must reflect actual correctness, not just consensus

3. **Requirement Completeness**
   - Stage 2: Check for missing functionality
   - Stage 3: Confidence penalty for missing requirements
   - Backend: Heuristic checks for common missing requirements

4. **Problem Understanding**
   - Stage 1: Explicit "do not read challenge files as input"
   - Stage 2: Flag misunderstanding as red flag
   - Stage 3: Reject solutions that solve wrong problem

## Testing Results

### Challenge 1
- Good solution: 100/100 (perfect)
- Partial solution: 74/100 (wrong name, wrong empty handling)
- Bad solution: 14/100 (wrong problem)

### Challenge 2
- First attempt: 51/100 (wrong signature, missing requirements)
- Second attempt: 61/100 (better approach, still wrong signature)
- Both had 95% confidence (too high)

## Next Steps

1. ✅ Principles documented
2. ✅ Prompts updated
3. ✅ Confidence calculation improved
4. ⏳ Test with rebuilt council
5. ⏳ Verify confidence reflects actual correctness
6. ⏳ Continue testing with remaining challenges

## Files Updated

- `llm-council/COUNCIL_PRINCIPLES.md` - Complete principles document
- `llm-council/backend/council.py` - Updated all 3 stage prompts + confidence calculation
- `llm-council/backend/main.py` - Response formatting with model info
- `llm-council/PERFORMANCE_OPTIMIZATIONS.md` - Performance improvements
- `llm-council/tests/` - Test suite and evaluation examples

