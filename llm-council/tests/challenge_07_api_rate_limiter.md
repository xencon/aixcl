# Challenge 7: API Rate Limiter (Advanced)

**Difficulty:** ⭐⭐⭐⭐ Advanced

**CODING CHALLENGE:** Implement a rate limiter that tracks API requests per user/IP.

**Your task:** Implement a complete Python class that solves this problem. Provide working code.

**Requirements:**
- Create a `RateLimiter` class with method `is_allowed(user_id: str) -> bool`
- Configuration: max requests per time window (e.g., 100 requests per minute)
- Use sliding window algorithm (not fixed window)
- Thread-safe implementation
- Handle memory: Clean up old entries periodically
- Return `True` if request allowed, `False` if rate limit exceeded

**Example:**
```python
limiter = RateLimiter(max_requests=5, window_seconds=60)

# First 5 requests should be allowed
for i in range(5):
    assert limiter.is_allowed("user1") == True

# 6th request should be denied
assert limiter.is_allowed("user1") == False

# After 60 seconds, should be allowed again
```

**What to evaluate:**
- Correctness: Accurate rate limiting, edge cases
- Performance: Efficient data structures, O(1) or O(log n) operations
- Security: Prevent bypass attempts, handle concurrent requests
- Code quality: Clean design, proper resource management
- Best practices: Use of appropriate data structures (deque, dict), thread safety

