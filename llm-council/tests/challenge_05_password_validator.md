# Challenge 5: Password Validator (Intermediate)

**Difficulty:** ⭐⭐⭐ Intermediate

**CODING CHALLENGE:** Write a secure password validation function with strength scoring.

**Your task:** Implement a complete Python function that solves this problem. Provide working code.

**Requirements:**
- Function signature: `validate_password(password: str) -> dict`
- Return dict with keys: `valid` (bool), `strength` (str: "weak"/"medium"/"strong"), `issues` (list of strings)
- Validation rules:
  - Minimum 8 characters
  - At least one uppercase letter
  - At least one lowercase letter
  - At least one digit
  - At least one special character (!@#$%^&*)
- Strength scoring:
  - Weak: meets minimum requirements only
  - Medium: 12+ characters OR has 3+ character types
  - Strong: 16+ characters AND has all 4 character types
- Security considerations: Don't leak information about which rules failed

**Example:**
```python
validate_password("Password123!")
# Expected: {"valid": True, "strength": "medium", "issues": []}

validate_password("weak")
# Expected: {"valid": False, "strength": "weak", "issues": ["Too short", "Missing uppercase", ...]}

validate_password("VeryStrongPassword123!@#")
# Expected: {"valid": True, "strength": "strong", "issues": []}
```

**What to evaluate:**
- Correctness: All validation rules work correctly
- Security: Information leakage prevention, secure comparison
- Code quality: Clear validation logic, maintainable
- Best practices: Use of regex vs manual checking?
- Performance: Efficient validation

