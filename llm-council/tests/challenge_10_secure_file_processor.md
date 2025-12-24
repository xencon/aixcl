# Challenge 10: Secure File Processor (Expert)

**Difficulty:** ⭐⭐⭐⭐⭐ Expert

**CODING CHALLENGE:** Implement a secure file processor that safely handles user-uploaded files.

**Your task:** Implement a complete Python class that solves this problem. Provide working code.

**Requirements:**
- Create a `SecureFileProcessor` class with method `process_file(file_path: str, allowed_extensions: list) -> dict`
- Security requirements:
  - Validate file extension against whitelist
  - Check file size limits (max 10MB)
  - Scan for malicious patterns (basic: no executable code in text files)
  - Sanitize file names (prevent path traversal)
  - Use secure temporary file handling
- Return dict with: `success` (bool), `content` (str if text file), `error` (str if failed)
- Handle both text and binary files appropriately
- Clean up temporary files securely

**Example:**
```python
processor = SecureFileProcessor()

# Valid text file
result = processor.process_file("document.txt", [".txt", ".md"])
# Expected: {"success": True, "content": "...", "error": None}

# Invalid extension
result = processor.process_file("script.exe", [".txt", ".md"])
# Expected: {"success": False, "content": None, "error": "File extension not allowed"}

# Path traversal attempt
result = processor.process_file("../../../etc/passwd", [".txt"])
# Expected: {"success": False, "content": None, "error": "Invalid file path"}
```

**What to evaluate:**
- Correctness: File processing logic, edge cases
- Security: Path traversal prevention, file type validation, size limits (CRITICAL)
- Code quality: Error handling, resource cleanup
- Best practices: Secure file handling, use of pathlib, proper validation
- Security: No code execution risks, proper sanitization, secure temp file handling

