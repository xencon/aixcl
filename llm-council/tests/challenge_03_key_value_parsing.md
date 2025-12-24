# Challenge 3: Key-Value Parsing (Easy-Intermediate)

**Difficulty:** ⭐⭐ Easy-Intermediate

**CODING CHALLENGE:** Write a function that parses comma-separated key-value pairs from user input.

**Your task:** Implement a complete Python function that solves this problem. Provide working code.

**Requirements:**
- Function signature: `parse_key_value_pairs(input_string: str) -> dict`
- Input format: `key1=value1,key2=value2,key3=value3`
- Handle edge cases: empty input, malformed pairs, duplicate keys, whitespace
- Return empty dict for empty input
- For duplicate keys, use the last value or handle appropriately

**Example:**
```python
parse_key_value_pairs("name=John,age=30,city=New York")
# Expected: {"name": "John", "age": "30", "city": "New York"}

parse_key_value_pairs("name=John,age,city=New York")
# Expected: Handle gracefully (skip malformed or raise error)

parse_key_value_pairs("name=John, name=Jane")
# Expected: {"name": "Jane"} (last value wins)
```

**What to evaluate:**
- Correctness: Edge case handling
- Security: Input validation, injection risks
- Code quality: Error handling, code structure
- Best practices: Use standard library (csv, shlex) vs custom parsing?
- Performance: Efficiency for large inputs

