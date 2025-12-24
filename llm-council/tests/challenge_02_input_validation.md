# Challenge 2: Input Validation (Easy)

**Difficulty:** ⭐⭐ Easy

**CODING CHALLENGE:** Write a function that validates and parses an email address.

**Your task:** Implement a complete Python function that solves this problem. Provide working code.

**Requirements:**
- Function signature: `validate_email(email: str) -> tuple[bool, str]`
- Return `(True, normalized_email)` if valid, `(False, error_message)` if invalid
- Basic format validation (contains @, has domain, etc.)
- Normalize by converting to lowercase and trimming whitespace
- Handle edge cases: None, empty string, whitespace-only

**Example:**
```python
validate_email("user@example.com")     # Expected: (True, "user@example.com")
validate_email("  USER@EXAMPLE.COM  ")  # Expected: (True, "user@example.com")
validate_email("invalid")               # Expected: (False, "Invalid email format")
validate_email("")                      # Expected: (False, "Email cannot be empty")
```

**What to evaluate:**
- Correctness: Edge case handling
- Security: Input validation approach
- Code quality: Error handling patterns
- Best practices: Use of standard library (email.utils)?

