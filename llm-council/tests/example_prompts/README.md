# Example Prompts

This directory contains ready-to-use prompts formatted correctly for Council.

## Usage

These prompts are pre-formatted to ensure models understand they need to write code, not use tools.

### Copy and Paste Method

1. Open any `challenge_XX_prompt.txt` file
2. Copy the entire content
3. Paste into Continue plugin or send via API
4. Models will understand it's a coding challenge

### Available Prompts

- `challenge_01_prompt.txt` - Simple string reversal (beginner)
- `challenge_03_prompt.txt` - Key-value parsing (intermediate)
- `challenge_08_prompt.txt` - SQL query builder (advanced, security-focused)

### Creating Your Own

Use the format from `CHALLENGE_PROMPT_TEMPLATE.md`:

```
You are a software developer solving a coding challenge. Write code to solve the following problem.

[Challenge content]

IMPORTANT INSTRUCTIONS:
- This is a CODING CHALLENGE - write actual working code
- Provide a complete implementation
- Handle all edge cases
- Follow best practices
- Write production-ready code
```

