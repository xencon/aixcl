# Challenge 4: Find Duplicates (Intermediate)

**Difficulty:** ⭐⭐⭐ Intermediate

**CODING CHALLENGE:** Write a function that finds duplicate elements in a list and returns their indices.

**Your task:** Implement a complete Python function that solves this problem. Provide working code.

**Requirements:**
- Function signature: `find_duplicates(items: list) -> dict`
- Return a dictionary where keys are duplicate values and values are lists of indices where they appear
- Handle empty lists, lists with no duplicates, lists with multiple duplicates
- Preserve order of first occurrence
- Should work with any hashable types (strings, numbers, tuples)

**Example:**
```python
find_duplicates([1, 2, 3, 2, 4, 2, 5])
# Expected: {2: [1, 3, 5]}

find_duplicates(["a", "b", "a", "c", "b"])
# Expected: {"a": [0, 2], "b": [1, 4]}

find_duplicates([1, 2, 3])
# Expected: {}
```

**What to evaluate:**
- Correctness: Algorithm correctness, edge cases
- Performance: Time/space complexity (O(n) vs O(n²))
- Code quality: Readability, maintainability
- Best practices: Use of collections.Counter or defaultdict?

