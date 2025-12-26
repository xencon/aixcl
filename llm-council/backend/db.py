"""PostgreSQL database connection and pool management."""

import asyncpg
import logging
from typing import Optional
from urllib.parse import quote_plus
from .config import (
    POSTGRES_HOST,
    POSTGRES_PORT,
    POSTGRES_USER,
    POSTGRES_PASSWORD,
    POSTGRES_CONTINUE_DATABASE,
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
        # Build connection string using continue database (separate from webui/Open WebUI database)
        # Properly escape special characters in user, password, and database name to prevent injection
        safe_user = quote_plus(POSTGRES_USER)
        safe_password = quote_plus(POSTGRES_PASSWORD)
        # Store in local variable early to avoid NameError in exception handlers
        db_name = POSTGRES_CONTINUE_DATABASE
        safe_database = quote_plus(db_name)
        dsn = f"postgresql://{safe_user}:{safe_password}@{POSTGRES_HOST}:{POSTGRES_PORT}/{safe_database}"
        
        logger.debug("Attempting to create database connection pool for database: %s", db_name)
        
        # Create connection pool
        _pool = await asyncpg.create_pool(
            dsn,
            min_size=1,
            max_size=10,
            command_timeout=60,
        )
        
        logger.info("Database connection pool created for %s", db_name)
        
        # Verify connection and create schema if needed
        await ensure_schema()
        
        return _pool
    except NameError as e:
        import traceback
        logger.error("Failed to create database connection pool - NameError: %s", str(e))
        logger.error("Full traceback:\n%s", traceback.format_exc())
        # Try to get the value safely - re-import if needed
        try:
            from .config import POSTGRES_CONTINUE_DATABASE as db_name_check
            logger.error("POSTGRES_CONTINUE_DATABASE re-import successful: %s", db_name_check)
        except Exception as import_err:
            logger.error("POSTGRES_CONTINUE_DATABASE re-import failed: %s", str(import_err))
        return None
    except Exception as e:
        import traceback
        logger.error(f"Failed to create database connection pool: {type(e).__name__}: {e}")
        logger.error(f"Full traceback:\n{traceback.format_exc()}")
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
        import re
        
        migration_file = Path(__file__).parent / "migrations" / "001_create_chat_table.sql"
        
        if migration_file.exists():
            with open(migration_file, 'r') as f:
                migration_sql = f.read()
            
            async with pool.acquire() as conn:
                # Execute migration SQL (may contain multiple statements)
                # Handle dollar-quoted strings properly (e.g., DO $$ ... END $$;)
                # Split by semicolon, but preserve dollar-quoted blocks
                statements = []
                current_statement = ""
                in_dollar_quote = False
                dollar_tag = None
                
                i = 0
                while i < len(migration_sql):
                    # Check for dollar-quote start/end
                    if migration_sql[i] == '$':
                        # Look ahead for dollar-quote pattern: $tag$ or $$
                        dollar_match = re.match(r'\$([^$]*)\$', migration_sql[i:])
                        if dollar_match:
                            tag = dollar_match.group(1) if dollar_match.group(1) else ""
                            full_match = f'${tag}$'
                            
                            if not in_dollar_quote:
                                # Starting a dollar-quoted string
                                in_dollar_quote = True
                                dollar_tag = tag
                                current_statement += full_match
                                i += len(full_match)
                                continue
                            elif tag == dollar_tag:
                                # Ending the dollar-quoted string
                                in_dollar_quote = False
                                dollar_tag = None
                                current_statement += full_match
                                i += len(full_match)
                                continue
                    
                    current_statement += migration_sql[i]
                    
                    # If we're not in a dollar-quote and hit a semicolon, it's a statement boundary
                    if not in_dollar_quote and migration_sql[i] == ';':
                        stmt = current_statement.strip()
                        if stmt:
                            statements.append(stmt)
                        current_statement = ""
                    
                    i += 1
                
                # Add any remaining statement
                if current_statement.strip():
                    statements.append(current_statement.strip())
                
                # Execute each statement
                for statement in statements:
                    if statement:
                        try:
                            await conn.execute(statement)
                        except Exception as stmt_error:
                            # Some errors are expected (e.g., "already exists", "does not exist")
                            error_msg = str(stmt_error).lower()
                            if any(phrase in error_msg for phrase in [
                                "already exists", "duplicate", "does not exist", "no operator class"
                            ]):
                                # These are expected in some cases, log as debug
                                logger.debug(f"Expected migration message: {stmt_error}")
                            else:
                                # Re-raise unexpected errors
                                raise
            
            logger.info("Database schema verified/created")
        else:
            logger.warning(f"Migration file not found: {migration_file}")
    except Exception as e:
        # If table already exists, that's okay
        error_msg = str(e).lower()
        if "already exists" in error_msg or "duplicate" in error_msg:
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

