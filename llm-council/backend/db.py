"""PostgreSQL database connection and pool management."""

import asyncpg
import logging
from typing import Optional
from .config import (
    POSTGRES_HOST,
    POSTGRES_PORT,
    POSTGRES_USER,
    POSTGRES_PASSWORD,
    POSTGRES_DATABASE,
    ENABLE_DB_STORAGE,
)

logger = logging.getLogger(__name__)

# Global connection pool
_pool: Optional[asyncpg.Pool] = None


async def get_pool() -> Optional[asyncpg.Pool]:
    """
    Get or create the database connection pool.
    
    Returns:
        Connection pool or None if database storage is disabled or connection fails
    """
    global _pool
    
    if not ENABLE_DB_STORAGE:
        return None
    
    if _pool is not None:
        return _pool
    
    try:
        # Build connection string
        dsn = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DATABASE}"
        
        # Create connection pool
        _pool = await asyncpg.create_pool(
            dsn,
            min_size=1,
            max_size=10,
            command_timeout=60,
        )
        
        logger.info(f"Database connection pool created for {POSTGRES_DATABASE}")
        
        # Verify connection and create schema if needed
        await ensure_schema()
        
        return _pool
    except Exception as e:
        logger.error(f"Failed to create database connection pool: {e}")
        return None


async def close_pool():
    """Close the database connection pool."""
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None
        logger.info("Database connection pool closed")


async def ensure_schema():
    """Ensure the chat table exists by running the migration."""
    pool = await get_pool()
    if pool is None:
        return
    
    try:
        # Read and execute the migration SQL
        from pathlib import Path
        
        migration_file = Path(__file__).parent / "migrations" / "001_create_chat_table.sql"
        
        if migration_file.exists():
            with open(migration_file, 'r') as f:
                migration_sql = f.read()
            
            async with pool.acquire() as conn:
                # Execute migration SQL (may contain multiple statements)
                # Split by semicolon and execute each statement
                statements = [s.strip() for s in migration_sql.split(';') if s.strip()]
                for statement in statements:
                    if statement:
                        await conn.execute(statement)
            
            logger.info("Database schema verified/created")
        else:
            logger.warning(f"Migration file not found: {migration_file}")
    except Exception as e:
        # If table already exists, that's okay
        if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
            logger.info("Database schema already exists")
        else:
            logger.error(f"Failed to ensure database schema: {e}")


async def execute_query(query: str, *args):
    """
    Execute a query and return results.
    
    Args:
        query: SQL query string
        *args: Query parameters
        
    Returns:
        Query results or None if database is unavailable
    """
    pool = await get_pool()
    if pool is None:
        return None
    
    try:
        async with pool.acquire() as conn:
            return await conn.fetch(query, *args)
    except Exception as e:
        logger.error(f"Database query failed: {e}")
        raise


async def execute_transaction(query: str, *args):
    """
    Execute a transaction (INSERT, UPDATE, DELETE).
    
    Args:
        query: SQL query string
        *args: Query parameters
        
    Returns:
        Result or None if database is unavailable
    """
    pool = await get_pool()
    if pool is None:
        return None
    
    try:
        async with pool.acquire() as conn:
            return await conn.execute(query, *args)
    except Exception as e:
        logger.error(f"Database transaction failed: {e}")
        raise

