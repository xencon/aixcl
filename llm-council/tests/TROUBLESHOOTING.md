# Troubleshooting: Council Confusion About Challenges

## Problem

When submitting challenge files directly, models may misinterpret them as tool usage instructions rather than coding problems to solve.

**Symptoms:**
- Models suggest using `read_file` or `read_currently_open_file` tools
- Models ask for clarification instead of writing code
- Models don't provide code solutions
- Responses focus on tool usage rather than problem solving

## Root Cause

Challenge markdown files are documentation format. When sent directly to models (especially through Continue plugin), models interpret:
- File paths (`llm-council/tests/challenge_01_*.md`) as instructions to read files
- Markdown structure as documentation to analyze
- Context about "tools" as instructions to use tools

## Solution

### Method 1: Use Pre-formatted Prompts (Recommended)

Use the ready-to-use prompts in `example_prompts/` directory:

1. Open `example_prompts/challenge_01_prompt.txt`
2. Copy entire content
3. Paste into Continue or API
4. Models will understand it's a coding challenge

### Method 2: Format Challenges Manually

Wrap challenge content with this template:

```
You are a software developer solving a coding challenge. Write code to solve the following problem.

[Paste challenge content here]

IMPORTANT INSTRUCTIONS:
- This is a CODING CHALLENGE - write actual working code
- Provide a complete function/class implementation
- Handle all edge cases mentioned
- Follow best practices
- Write production-ready code
```

### Method 3: Use Python Wrapper

```python
from llm_council.tests.challenge_wrapper import format_challenge_prompt

with open('challenge_01_simple_string_processing.md', 'r') as f:
    content = f.read()

prompt = format_challenge_prompt(content)
# Use prompt in API call
```

## Verification

After submitting a properly formatted challenge, you should see:

**Stage 1 Results:**
- Models provide actual Python code
- Functions/classes are implemented
- Edge cases are handled
- No tool usage suggestions

**Stage 2 Rankings:**
- Evaluations focus on code quality
- Security considerations mentioned
- Correctness prioritized
- Standard library usage evaluated

**Stage 3 Synthesis:**
- Final response contains working code
- Code is production-ready
- Best practices followed

## Example: Good vs Bad Prompt

### ❌ Bad (Causes Confusion)

```
# Challenge 1: Simple String Processing

Task: Write a function that reverses a string.

[Models interpret this as: "I need to read a file to understand this challenge"]
```

### ✅ Good (Clear Intent)

```
You are a software developer solving a coding challenge. Write code to solve the following problem.

# Challenge 1: Simple String Processing

CODING CHALLENGE: Write a function that reverses a string.

IMPORTANT: This is a CODING CHALLENGE - write actual working Python code.

[Models understand: "I need to write code to solve this problem"]
```

## Quick Fix Checklist

- [ ] Challenge is wrapped with "You are a software developer..." context
- [ ] Explicitly states "CODING CHALLENGE" or "write code"
- [ ] Includes "IMPORTANT INSTRUCTIONS" section
- [ ] No ambiguous file paths or tool references
- [ ] Clear task description with code requirements

## Files Updated

- All challenge files now include "CODING CHALLENGE" header
- `CHALLENGE_PROMPT_TEMPLATE.md` - Template for formatting
- `example_prompts/` - Ready-to-use formatted prompts
- `challenge_wrapper.py` - Python helper function

