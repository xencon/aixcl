# Council Principles

## Core Principles

### 1. Solve the Stated Problem Only

**Rule:** Implement exactly what is requested. Do not add extra functionality.

**Examples:**
- ✅ If asked for `reverse_string(s: str) -> str`, provide only that function
- ❌ Do NOT add `custom_concat`, `validate_phone`, or other unrelated functions
- ❌ Do NOT read files or interpret challenge files as input

**Rationale:** Extra code adds complexity, violates requirements, and shows misunderstanding.

### 2. Match Function Signatures Exactly

**Rule:** Function signatures must match requirements precisely.

**Examples:**
- ✅ `validate_email(email: str) -> tuple[bool, str]` - matches requirement
- ❌ `validate_email(email)` returning `bool` - wrong signature
- ❌ Missing return type annotations when specified

**Rationale:** Wrong signatures indicate the problem wasn't understood.

### 3. Handle All Edge Cases

**Rule:** Explicitly handle all edge cases mentioned in requirements.

**Examples:**
- ✅ Empty strings, None, whitespace-only inputs
- ✅ Single character inputs
- ✅ Unicode characters
- ❌ Assuming inputs are always valid
- ❌ Missing None checks causing AttributeError

**Rationale:** Production code must handle edge cases gracefully.

### 4. Provide Complete Solutions

**Rule:** Solutions must be complete and production-ready.

**Examples:**
- ✅ Includes normalization when specified (lowercase, trim whitespace)
- ✅ Returns error messages when required
- ✅ Handles all specified edge cases
- ❌ Missing required functionality
- ❌ Incomplete implementations

**Rationale:** Incomplete solutions don't solve the problem.

### 5. Use Standard Library Solutions

**Rule:** Prefer standard library over custom implementations.

**Examples:**
- ✅ `s[::-1]` for string reversal (Python idiom)
- ✅ `email.utils` for email validation when appropriate
- ✅ `csv` module for parsing key-value pairs
- ❌ Custom regex when standard library exists
- ❌ Reinventing wheel unnecessarily

**Rationale:** Standard solutions are proven, tested, and maintainable.

### 6. No Clarification Requests

**Rule:** Provide solutions, not questions. Make reasonable assumptions.

**Examples:**
- ✅ Assume standard behavior when not specified
- ✅ Use common conventions (e.g., last value wins for duplicates)
- ❌ Asking "what should I do if..."
- ❌ Requesting additional context

**Rationale:** Fast fail, fast fix approach. Solutions over questions.

### 7. Direct Code Output

**Rule:** Provide code directly. No meta-commentary or process explanations.

**Examples:**
- ✅ Code solution immediately
- ❌ "Given the context and evaluations..."
- ❌ "Based on the markdown file..."
- ❌ Tool usage suggestions

**Rationale:** Users want code, not explanations about the process.

### 8. Correctness First

**Rule:** Correctness (40% weight) is mandatory. Code must work.

**Examples:**
- ✅ Handles all test cases correctly
- ✅ No logic errors (e.g., regex typos)
- ✅ Correct algorithm implementation
- ❌ Bugs that cause incorrect output
- ❌ Logic errors (e.g., `a-zAZ` instead of `a-zA-Z`)

**Rationale:** Incorrect code is useless regardless of other qualities.

### 9. Security Awareness

**Rule:** Consider security implications (20% weight).

**Examples:**
- ✅ Input validation
- ✅ SQL injection prevention (parameterized queries)
- ✅ Path traversal prevention
- ✅ Safe error messages (no information leakage)
- ❌ Unsafe string concatenation
- ❌ Missing input validation

**Rationale:** Security vulnerabilities are critical failures.

### 10. Code Quality Matters

**Rule:** Code should be readable, documented, and maintainable (15% weight).

**Examples:**
- ✅ Clear docstrings
- ✅ Descriptive variable names
- ✅ Appropriate type hints
- ✅ Clean structure
- ❌ Single-letter variables
- ❌ No documentation
- ❌ Unclear logic

**Rationale:** Maintainable code reduces long-term costs.

## Evaluation Criteria (Weighted)

### Stage 2 Ranking Priorities

1. **Correctness (40%)** - Does it solve the problem correctly?
   - Function signature matches?
   - All requirements met?
   - Edge cases handled?
   - No logic errors?

2. **Security (20%)** - Is it secure?
   - Input validation?
   - Injection prevention?
   - Safe error handling?

3. **Code Quality (15%)** - Is it well-written?
   - Documentation?
   - Readability?
   - Best practices?

4. **Performance (10%)** - Is it efficient?
   - Appropriate complexity?
   - Efficient algorithms?

5. **Maintainability (10%)** - Is it maintainable?
   - Modular?
   - Clear structure?

6. **Standard Practices (5%)** - Uses proven solutions?
   - Standard library?
   - Conservative approach?

### Stage 3 Synthesis Rules

1. **Prioritize Correctness** - Reject solutions that don't work
2. **Prefer Consensus** - Solutions ranked highly by multiple models
3. **Synthesize Best Aspects** - Correctness from one, efficiency from another
4. **Flag Exotic Solutions** - Note if non-standard approaches are used
5. **Direct Code Output** - No preamble, just the solution

## Red Flags to Flag in Stage 2

1. Wrong function signature
2. Missing required functionality
3. Logic errors (bugs)
4. Extra unrelated code
5. Misunderstanding of problem (e.g., reading challenge file as input)
6. Missing edge case handling
7. Security vulnerabilities
8. Exotic solutions when standard exists

## Examples of Good vs Bad

### Good Response (Challenge 1)
```python
def reverse_string(s: str) -> str:
    """Reverses a given string."""
    return s[::-1]
```
- ✅ Correct signature
- ✅ Solves problem
- ✅ Uses standard idiom
- ✅ Simple and clear

### Bad Response (Challenge 1)
```python
def custom_concat(A: str, B: str) -> str:
    # Wrong problem entirely
```
- ❌ Wrong function name
- ❌ Wrong problem
- ❌ Wrong signature

### Bad Response (Challenge 2)
```python
def validate_email(email):
    return re.match(pattern, email) is not None
```
- ❌ Wrong return type (should be tuple)
- ❌ Missing normalization
- ❌ Missing error messages
- ❌ Missing edge cases

## Implementation Guidelines

### For Stage 1 (Individual Responses)
- Read the problem carefully
- Implement exactly what's requested
- Handle all edge cases
- Use standard library when available
- Provide complete solution
- No extra functions

### For Stage 2 (Peer Ranking)
- Evaluate against weighted criteria
- Flag correctness issues immediately
- Note security concerns
- Prefer standard solutions
- Rank based on actual problem solving

### For Stage 3 (Synthesis)
- Reject incorrect solutions
- Synthesize from correct solutions
- Prioritize correctness and security
- Provide code directly
- No meta-commentary

## Summary

**The council must:**
1. Solve the exact problem stated
2. Match requirements precisely
3. Handle all edge cases
4. Use standard solutions
5. Provide code directly
6. Prioritize correctness above all

**The council must NOT:**
1. Add extra functionality
2. Ask for clarification
3. Misunderstand the problem
4. Provide incomplete solutions
5. Use exotic approaches unnecessarily
6. Include meta-commentary

