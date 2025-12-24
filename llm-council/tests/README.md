# LLM Council Test Suite

This directory contains 10 progressively challenging coding tests designed to evaluate the enhanced LLM Council system's ability to:

1. **Prioritize correctness** - Handle edge cases and error conditions
2. **Evaluate security** - Identify vulnerabilities and secure coding practices
3. **Prefer proven solutions** - Choose standard library solutions over custom implementations
4. **Assess code quality** - Evaluate readability, maintainability, and best practices
5. **Consider performance** - Analyze algorithmic complexity and efficiency

## Test Progression

| Challenge | Difficulty | Focus Areas |
|-----------|-----------|-------------|
| [Challenge 1: Simple String Processing](challenge_01_simple_string_processing.md) | ⭐ Very Easy | Basic correctness, code quality |
| [Challenge 2: Input Validation](challenge_02_input_validation.md) | ⭐⭐ Easy | Edge cases, error handling |
| [Challenge 3: Key-Value Parsing](challenge_03_key_value_parsing.md) | ⭐⭐ Easy-Intermediate | Security, standard library usage |
| [Challenge 4: Find Duplicates](challenge_04_find_duplicates.md) | ⭐⭐⭐ Intermediate | Algorithm efficiency, data structures |
| [Challenge 5: Password Validator](challenge_05_password_validator.md) | ⭐⭐⭐ Intermediate | Security, validation logic |
| [Challenge 6: Binary Search Tree](challenge_06_binary_search_tree.md) | ⭐⭐⭐⭐ Intermediate-Advanced | Algorithm correctness, complexity |
| [Challenge 7: API Rate Limiter](challenge_07_api_rate_limiter.md) | ⭐⭐⭐⭐ Advanced | Performance, thread safety |
| [Challenge 8: SQL Query Builder](challenge_08_sql_query_builder.md) | ⭐⭐⭐⭐ Advanced | Security (SQL injection prevention) |
| [Challenge 9: Cache with TTL](challenge_09_cache_with_ttl.md) | ⭐⭐⭐⭐⭐ Expert | Performance, concurrency, data structures |
| [Challenge 10: Secure File Processor](challenge_10_secure_file_processor.md) | ⭐⭐⭐⭐⭐ Expert | Security (path traversal, file validation) |

## How to Use

**IMPORTANT:** When submitting challenges, format them as coding problems. See `CHALLENGE_PROMPT_TEMPLATE.md` for the correct format.

Each challenge file contains:
- **Task description** - What needs to be implemented
- **Requirements** - Specific functional requirements
- **Examples** - Expected input/output behavior
- **Evaluation criteria** - What aspects should be evaluated

**Ready-to-use prompts** are available in `example_prompts/` directory for quick testing.

### Testing the LLM Council

1. Submit each challenge to the LLM Council via the API or Continue plugin
2. Review Stage 2 rankings to see if models prioritize:
   - Correctness (40% weight)
   - Security (20% weight)
   - Code quality (15% weight)
   - Performance (10% weight)
   - Maintainability (10% weight)
   - Standard practices (5% weight)
3. Review Stage 3 synthesis to verify:
   - Correctness and security are prioritized
   - Proven solutions are preferred
   - Best aspects are synthesized from multiple responses

### Expected Behaviors

**For Easy Challenges (1-3):**
- Should prefer simple, readable solutions
- Should use standard library functions
- Should handle edge cases gracefully

**For Intermediate Challenges (4-6):**
- Should evaluate algorithmic efficiency
- Should consider appropriate data structures
- Should maintain code quality while optimizing

**For Advanced Challenges (7-9):**
- Should prioritize security and correctness
- Should consider thread safety and concurrency
- Should use proven patterns and libraries

**For Expert Challenges (9-10):**
- Security must be non-negotiable
- Should use battle-tested approaches
- Should handle edge cases comprehensively
- Should prefer standard library solutions over custom implementations

## Success Criteria

The enhanced LLM Council should demonstrate:

✅ **Correctness First**: Solutions handle all edge cases correctly  
✅ **Security Awareness**: Vulnerabilities are identified and prevented  
✅ **Conservative Approach**: Standard library solutions preferred over custom code  
✅ **Code Quality**: Readable, maintainable, well-structured code  
✅ **Performance**: Efficient algorithms with appropriate complexity  
✅ **Best Practices**: Follows language/framework conventions  

## Notes

- Challenges are designed to have multiple valid approaches
- Some challenges intentionally have security pitfalls to test awareness
- Progressive difficulty allows testing at different complexity levels
- Each challenge focuses on specific evaluation criteria from the enhanced prompts

