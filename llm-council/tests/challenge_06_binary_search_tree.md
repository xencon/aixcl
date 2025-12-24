# Challenge 6: Binary Search Tree Operations (Intermediate-Advanced)

**Difficulty:** ⭐⭐⭐⭐ Intermediate-Advanced

**CODING CHALLENGE:** Implement a Binary Search Tree (BST) with insert, search, and delete operations.

**Your task:** Implement a complete Python class that solves this problem. Provide working code.

**Requirements:**
- Create a `BST` class with methods:
  - `insert(value)`: Insert a value maintaining BST property
  - `search(value) -> bool`: Check if value exists
  - `delete(value)`: Remove value maintaining BST property
  - `inorder() -> list`: Return values in sorted order
- Handle edge cases: empty tree, deleting root, deleting node with two children
- Maintain BST invariants: left < node < right

**Example:**
```python
bst = BST()
bst.insert(5)
bst.insert(3)
bst.insert(7)
bst.insert(2)
bst.search(3)  # Expected: True
bst.search(10) # Expected: False
bst.inorder()  # Expected: [2, 3, 5, 7]
bst.delete(3)
bst.inorder()  # Expected: [2, 5, 7]
```

**What to evaluate:**
- Correctness: All operations maintain BST properties
- Algorithm efficiency: O(log n) average case for operations
- Code quality: Clean class design, error handling
- Best practices: Proper tree traversal, recursion vs iteration
- Edge cases: Deletion scenarios handled correctly

