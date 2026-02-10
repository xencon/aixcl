# Challenge Prompt Template

When submitting challenges to Council, use this format to ensure models understand they need to write code:

## Template

```
You are a software developer solving a coding challenge. Write code to solve the following problem.

[CHALLENGE CONTENT FROM FILE]

IMPORTANT:
- This is a CODING CHALLENGE - write actual working code
- Provide a complete function/class implementation
- Handle all edge cases mentioned in the requirements
- Follow best practices and use standard library when available
- Consider security implications
- Write production-ready code

Provide your solution as Python code with brief explanations.
```

## Example: Challenge 1

```
You are a software developer solving a coding challenge. Write code to solve the following problem.

# Challenge 1: Simple String Processing (Beginner)

**Difficulty:** ⭐ Very Easy

**CODING CHALLENGE:** Write a function that reverses a string.

**Your task:** Implement a complete Python function that solves this problem. Provide working code.

**Requirements:**
- Function signature: `reverse_string(s: str) -> str`
- Handle empty strings
- Handle strings with special characters
- Preserve Unicode characters correctly

**Example:**
```python
reverse_string("hello")  # Expected: "olleh"
reverse_string("")       # Expected: ""
reverse_string("a")      # Expected: "a"
reverse_string("世界")    # Expected: "界世"
```

IMPORTANT:
- This is a CODING CHALLENGE - write actual working code
- Provide a complete function implementation
- Handle all edge cases (empty strings, Unicode, special characters)
- Follow Python best practices and use standard library when available
- Write production-ready code

Provide your solution as Python code.
```

## Using the Wrapper Function

You can also use the Python wrapper function:

```python
from llm_council.tests.challenge_wrapper import format_challenge_prompt

# Read challenge file
with open('llm-council/tests/challenge_01_simple_string_processing.md', 'r') as f:
    challenge_content = f.read()

# Format as coding challenge prompt
prompt = format_challenge_prompt(challenge_content)

# Send to Council
# ... use prompt in API call
```

