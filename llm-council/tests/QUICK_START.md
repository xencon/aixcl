# Quick Start: Testing the Enhanced Council

## 1. Create Branch

```bash
git checkout main
git pull origin main
git checkout -b feature/code-focused-council-enhancements
```

## 2. Start Services

```bash
# Start Council
./aixcl stack start

# Verify it's running
curl http://localhost:8000/health

# Check council configuration
./aixcl council status
```

## 3. Test a Challenge

### Option A: Using Pre-formatted Prompts (Easiest - Recommended)
1. Open `example_prompts/challenge_01_prompt.txt` (or any challenge)
2. Copy the entire content
3. Paste into Continue chat
4. Review Stage 1, Stage 2, and Stage 3 results

**Why?** These prompts are pre-formatted to prevent confusion. Models will understand they need to write code, not use tools.

### Option B: Format Manually
1. Open Continue in your IDE
2. **Format the challenge** using this template:
   ```
   You are a software developer solving a coding challenge. Write code to solve the following problem.
   
   [Paste challenge content]
   
   IMPORTANT: This is a CODING CHALLENGE - write actual working code. Provide a complete implementation.
   ```
3. Paste formatted prompt into Continue chat
4. Review Stage 1, Stage 2, and Stage 3 results

**See `CHALLENGE_PROMPT_TEMPLATE.md` for detailed examples.**

### Option B: Using curl
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "council",
    "messages": [{
      "role": "user",
      "content": "[Paste challenge content here]"
    }],
    "stream": false
  }'
```

## 4. What to Look For

### ✅ Good Signs
- **Stage 2**: Rankings prioritize correctness (40%) and security (20%)
- **Stage 2**: Exotic solutions are flagged
- **Stage 2**: Standard library solutions preferred
- **Stage 3**: Final code is production-ready
- **Stage 3**: Security and correctness prioritized

### ❌ Red Flags
- Security vulnerabilities not mentioned
- Exotic solutions ranked highly
- Custom code when standard library exists
- Missing edge case handling

## 5. Test Progression

Start with easy challenges to verify basic functionality:
1. Challenge 1: Simple String Processing
2. Challenge 2: Input Validation  
3. Challenge 3: Key-Value Parsing

Then test security awareness:
- Challenge 5: Password Validator
- Challenge 8: SQL Query Builder
- Challenge 10: Secure File Processor

## Full Documentation

See `USAGE.md` for detailed testing instructions and evaluation criteria.

