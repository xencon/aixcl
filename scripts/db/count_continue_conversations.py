#!/usr/bin/env python3
"""Script to count Continue conversations in the chat table."""

import asyncio
import sys
from pathlib import Path

# Add the council backend to the path (directory name llm-council)
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "llm-council" / "backend"))

from db import get_pool, close_pool


async def count_continue_conversations():
    """Count the number of Continue conversations in the chat table."""
    pool = await get_pool()
    if pool is None:
        print("❌ Database connection failed. Is ENABLE_DB_STORAGE enabled?")
        return None
    
    try:
        async with pool.acquire() as conn:
            # Count conversations with source = 'continue'
            result = await conn.fetchval(
                """
                SELECT COUNT(*) 
                FROM chat 
                WHERE source = 'continue'
                """
            )
            return result
    except Exception as e:
        print(f"❌ Error querying database: {e}")
        return None
    finally:
        await close_pool()


async def main():
    """Main entry point."""
    count = await count_continue_conversations()
    if count is not None:
        print(f"✅ Number of Continue conversations in chat table: {count}")
        return 0
    else:
        print("❌ Failed to get conversation count")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)

