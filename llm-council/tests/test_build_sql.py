#!/usr/bin/env python3
"""Test script for build_sql function."""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from tests.build_sql_fixed import build_sql

def test_build_sql():
    """Test the build_sql function."""
    result = build_sql("users", ["id INT PRIMARY KEY", "name VARCHAR(50)", "email VARCHAR(100)"])
    print("Result:", result)
    print("\nSQL:", result['sql'])
    print("\nExpected: CREATE TABLE users( id INT PRIMARY KEY, name VARCHAR(50), email VARCHAR(100));")
    
    # Verify it matches expected output
    expected = "CREATE TABLE users( id INT PRIMARY KEY, name VARCHAR(50), email VARCHAR(100));"
    assert result['sql'] == expected, f"Expected '{expected}', got '{result['sql']}'"
    print("\n✅ Test passed!")

if __name__ == "__main__":
    test_build_sql()

