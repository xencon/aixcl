# Challenge 9: Cache with TTL (Expert)

**Difficulty:** ⭐⭐⭐⭐⭐ Expert

**CODING CHALLENGE:** Implement a thread-safe cache with Time-To-Live (TTL) and LRU eviction.

**Your task:** Implement a complete Python class that solves this problem. Provide working code.

**Requirements:**
- Create a `TTLCache` class with methods: `get(key)`, `set(key, value, ttl)`, `delete(key)`
- TTL: Each entry expires after specified seconds
- LRU eviction: When cache is full, evict least recently used expired entries, then LRU entries
- Thread-safe: Support concurrent access
- Performance: O(1) get/set operations
- Memory management: Auto-cleanup expired entries

**Example:**
```python
cache = TTLCache(max_size=3)

cache.set("a", 1, ttl=10)  # Expires in 10 seconds
cache.set("b", 2, ttl=5)   # Expires in 5 seconds
cache.get("a")  # Expected: 1

# After 6 seconds
cache.get("b")  # Expected: None (expired)
cache.get("a")  # Expected: 1 (still valid)

# When adding 4th item, evict LRU if all valid
cache.set("c", 3, ttl=10)
cache.set("d", 4, ttl=10)  # Should evict least recently used
```

**What to evaluate:**
- Correctness: TTL expiration, LRU eviction logic
- Performance: O(1) operations, efficient data structures
- Thread safety: Proper locking mechanisms
- Code quality: Clean design, resource management
- Best practices: Use of appropriate data structures (OrderedDict, heapq), proper synchronization

