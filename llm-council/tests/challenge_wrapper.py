"""Helper function to format challenge files as coding problems for Council."""

def format_challenge_prompt(challenge_content: str) -> str:
    """
    Format a challenge file content as a clear coding problem prompt.
    
    This wrapper ensures challenges are interpreted as coding problems to solve,
    not as tool usage instructions.
    
    Args:
        challenge_content: Raw content from challenge markdown file
        
    Returns:
        Formatted prompt that clearly requests code solution
    """
    prompt = f"""You are a software developer solving a coding challenge. Please write code to solve the following problem.

{challenge_content}

IMPORTANT INSTRUCTIONS:
- This is a CODING CHALLENGE - write actual code to solve it
- Provide a complete, working solution
- Include the function/class implementation
- Handle all edge cases mentioned
- Follow best practices for the language
- Consider security implications if applicable
- Use standard library solutions when available
- Write production-ready code

Please provide your solution as code with brief explanations where helpful."""
    
    return prompt

