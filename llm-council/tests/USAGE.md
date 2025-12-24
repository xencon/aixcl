# How to Use the LLM Council Test Suite

## Quick Start

### 1. Create a Branch

First, create a branch for testing the enhanced LLM Council:

```bash
git checkout main
git pull origin main
git checkout -b feature/code-focused-council-enhancements
# Or if you have an issue number:
# git checkout -b issue-<number>/code-focused-council-enhancements
```

### 2. Start the LLM Council Service

Ensure the LLM Council service is running:

```bash
# From the project root
./aixcl stack start
# Or if already running, restart to pick up changes
./aixcl stack restart llm-council
```

Verify it's running:
```bash
curl http://localhost:8000/health
```

### 3. Configure Council Models

Make sure you have council models configured:

```bash
./aixcl council configure
# Or check current configuration
./aixcl council status
```

## Testing Methods

### Method 1: Using Continue Plugin (Recommended)

The Continue plugin integrates directly with LLM Council:

1. **Open Continue in your IDE**
2. **Select a challenge file** from `llm-council/tests/`
3. **Format the challenge** using the template below (IMPORTANT: Models need clear context)
4. **Paste the formatted prompt** into Continue
5. **Submit the query** - Continue will send it to LLM Council via `/v1/chat/completions`
6. **Review the response** - Check Stage 1, Stage 2, and Stage 3 results

**CRITICAL: Use this format to avoid confusion:**

```
You are a software developer solving a coding challenge. Write code to solve the following problem.

[Paste challenge content from challenge_XX_*.md file]

IMPORTANT:
- This is a CODING CHALLENGE - write actual working code
- Provide a complete function/class implementation
- Handle all edge cases mentioned
- Follow best practices and use standard library when available
- Write production-ready code

Provide your solution as Python code.
```

**Example for Challenge 1:**
```
You are a software developer solving a coding challenge. Write code to solve the following problem.

# Challenge 1: Simple String Processing (Beginner)

**CODING CHALLENGE:** Write a function that reverses a string.

**Requirements:**
- Function signature: `reverse_string(s: str) -> str`
- Handle empty strings, special characters, Unicode

**Examples:**
reverse_string("hello") → "olleh"
reverse_string("世界") → "界世"

IMPORTANT: Write actual working Python code to solve this problem.
```

### Method 2: Using curl (Direct API)

Test via the OpenAI-compatible endpoint:

```bash
# Test Challenge 1: Simple String Processing
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "council",
    "messages": [
      {
        "role": "user",
        "content": "Write a function that reverses a string. Function signature: reverse_string(s: str) -> str. Handle empty strings, strings with special characters, and preserve Unicode characters correctly. Examples: reverse_string(\"hello\") should return \"olleh\", reverse_string(\"\") should return \"\", reverse_string(\"世界\") should return \"界世\". Evaluate correctness, code quality, and best practices."
      }
    ],
    "stream": false
  }'
```

### Method 3: Using Python Script

Create a test script:

```python
import requests
import json

def test_challenge(challenge_file):
    """Test a challenge file with LLM Council"""
    with open(challenge_file, 'r') as f:
        challenge_content = f.read()
    
    response = requests.post(
        'http://localhost:8000/v1/chat/completions',
        json={
            'model': 'council',
            'messages': [
                {'role': 'user', 'content': challenge_content}
            ],
            'stream': False
        }
    )
    
    result = response.json()
    return result

# Test a challenge
result = test_challenge('llm-council/tests/challenge_01_simple_string_processing.md')
print(json.dumps(result, indent=2))
```

## What to Evaluate

### Stage 1 Results (Individual Responses)

Check if models provide:
- ✅ Correct solutions
- ✅ Edge case handling
- ✅ Security considerations
- ✅ Code quality

### Stage 2 Results (Peer Rankings)

Verify rankings prioritize:
- ✅ **Correctness (40%)** - Does it work? Edge cases handled?
- ✅ **Security (20%)** - Input validation? Injection risks?
- ✅ **Code Quality (15%)** - Best practices? Documentation?
- ✅ **Performance (10%)** - Efficient algorithms?
- ✅ **Maintainability (10%)** - Readable? Modular?
- ✅ **Standard Practices (5%)** - Uses proven patterns?

Look for:
- Models flagging exotic/novel solutions
- Security concerns being raised
- Standard library solutions being preferred

### Stage 3 Results (Final Synthesis)

Verify the chairman:
- ✅ Prioritizes correctness and security
- ✅ Prefers consensus solutions
- ✅ Synthesizes best aspects from multiple responses
- ✅ Flags exotic approaches unless explicitly requested
- ✅ Produces production-ready code

## Testing Workflow

### Sequential Testing (Recommended)

Test challenges in order to see progressive difficulty handling:

```bash
# Test all challenges sequentially
for i in {1..10}; do
  echo "Testing Challenge $i..."
  # Use your preferred method (Continue, curl, or script)
  # Review results before moving to next challenge
done
```

### Focused Testing

Test specific aspects:

**Security Focus:**
- Challenge 2: Input Validation
- Challenge 5: Password Validator
- Challenge 8: SQL Query Builder
- Challenge 10: Secure File Processor

**Performance Focus:**
- Challenge 4: Find Duplicates
- Challenge 7: API Rate Limiter
- Challenge 9: Cache with TTL

**Algorithm Focus:**
- Challenge 4: Find Duplicates
- Challenge 6: Binary Search Tree
- Challenge 9: Cache with TTL

## Expected Behaviors

### For Easy Challenges (1-3)

**Good Response Should:**
- Use simple, readable solutions
- Prefer standard library (`str[::-1]` for reverse, `email.utils` for validation)
- Handle edge cases gracefully
- Have clear error messages

**Red Flags:**
- Overly complex solutions
- Custom implementations when standard library exists
- Missing edge case handling
- Security vulnerabilities

### For Intermediate Challenges (4-6)

**Good Response Should:**
- Use appropriate data structures (`set`, `dict`, `collections.Counter`)
- Consider time/space complexity
- Maintain code quality while optimizing
- Handle edge cases (empty inputs, single elements)

**Red Flags:**
- O(n²) solutions when O(n) is possible
- Missing edge cases
- Poor code structure
- Security issues (injection risks)

### For Advanced Challenges (7-9)

**Good Response Should:**
- Prioritize security (parameterized queries, input validation)
- Consider thread safety
- Use proven patterns and libraries
- Handle concurrency correctly

**Red Flags:**
- SQL injection vulnerabilities (Challenge 8)
- Race conditions (Challenge 7, 9)
- Memory leaks
- Security bypasses

### For Expert Challenges (9-10)

**Good Response Should:**
- Security is non-negotiable
- Use battle-tested approaches
- Handle all edge cases comprehensively
- Prefer standard library solutions

**Red Flags:**
- Any security vulnerability
- Path traversal risks (Challenge 10)
- Code execution risks
- Missing input validation

## Analyzing Results

### Check Stage 2 Rankings

Look at the `parsed_ranking` in Stage 2 results:

```python
# Example Stage 2 result structure
{
  "model": "model-name",
  "ranking": "Full evaluation text...",
  "parsed_ranking": ["Response C", "Response A", "Response B"]
}
```

**Questions to ask:**
- Does the ranking match the evaluation criteria weights?
- Are security concerns mentioned?
- Are exotic solutions flagged?
- Is correctness prioritized?

### Check Aggregate Rankings

Review `aggregate_rankings` in metadata:

```python
# Example aggregate rankings
[
  {"model": "model1", "average_rank": 1.5, "rankings_count": 3},
  {"model": "model2", "average_rank": 2.0, "rankings_count": 3}
]
```

**Questions to ask:**
- Do models with better correctness/security rank higher?
- Is there consensus on the best solution?
- Are outliers (exotic solutions) ranked lower?

### Check Stage 3 Synthesis

Review the final response:

**Good Synthesis Should:**
- Combine best aspects from multiple responses
- Prioritize correctness and security
- Use proven solutions
- Be production-ready

**Red Flags:**
- Exotic solutions chosen over standard ones
- Security vulnerabilities in final code
- Missing edge case handling
- Poor code quality

## Recording Results

Create a test log:

```markdown
# LLM Council Test Results

## Challenge 1: Simple String Processing
- Date: 2025-12-23
- Stage 2 Ranking: ✅ Correctness prioritized
- Stage 3 Synthesis: ✅ Used standard solution (str[::-1])
- Security: N/A
- Notes: Good edge case handling

## Challenge 2: Input Validation
- Date: 2025-12-23
- Stage 2 Ranking: ✅ Security mentioned
- Stage 3 Synthesis: ✅ Used email.utils
- Security: ✅ No vulnerabilities
- Notes: Proper error handling
```

## Troubleshooting

### Council Not Responding

```bash
# Check service status
docker ps | grep llm-council

# Check logs
docker logs llm-council

# Verify models are configured
./aixcl council status
```

### Models Not Ranking Properly

- Check if models are responding in Stage 1
- Verify ranking prompt format is correct
- Check logs for parsing errors

### Security Not Being Evaluated

- Verify Stage 2 prompt includes security criteria
- Check if models are flagging security issues
- Review aggregate rankings for security-focused models

## Next Steps

After testing:

1. **Document findings** - Record which challenges work well and which need improvement
2. **Refine prompts** - Adjust weights or criteria based on results
3. **Test edge cases** - Try variations of challenges to test robustness
4. **Compare with baseline** - Test same challenges with original prompts to see improvement

## Additional Resources

- See `README.md` for challenge descriptions
- Review `council.py` to understand prompt structure
- Check `main.py` for API endpoint details

