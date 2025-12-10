"""PostgreSQL storage operations for Continue conversations."""

import json
import logging
import time
from typing import List, Dict, Any, Optional
from datetime import datetime
from . import db
from .conversation_tracker import create_message_entry

logger = logging.getLogger(__name__)


async def create_continue_conversation(conversation_id: str, first_message: str, title: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """
    Create a new Continue conversation in PostgreSQL.
    Matches Open WebUI schema format.
    
    Args:
        conversation_id: Unique conversation identifier
        first_message: First user message content
        title: Optional conversation title
        
    Returns:
        Created conversation dict or None if database unavailable
    """
    pool = await db.get_pool()
    if pool is None:
        return None
    
    try:
        # Generate title from first message if not provided
        if not title:
            # Use first 50 chars of first message as title
            title = first_message[:50] + "..." if len(first_message) > 50 else first_message
        
        # Create initial message entry
        user_message = create_message_entry("user", first_message)
        
        # Create conversation structure matching Open WebUI format
        # Open WebUI uses a complex structure, but we'll use a simpler messages array
        conversation_data = {
            "messages": [user_message]
        }
        
        meta_data = {
            "source": "continue",
            "created_via": "continue_plugin",
        }
        
        # Get current timestamp as Unix timestamp (bigint)
        current_timestamp = int(time.time() * 1000)  # milliseconds
        
        # Use a default user_id for Continue conversations
        user_id = "continue-user"
        
        async with pool.acquire() as conn:
            result = await conn.fetchrow(
                """
                INSERT INTO chat (id, user_id, title, chat, meta, source, created_at, updated_at, archived)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                RETURNING id, title, chat, meta, source, created_at, updated_at
                """,
                conversation_id,
                user_id,
                title,
                json.dumps(conversation_data),
                json.dumps(meta_data),
                "continue",
                current_timestamp,
                current_timestamp,
                False  # archived
            )
        
        if result:
            return {
                "id": str(result["id"]),
                "title": result["title"],
                "chat": result["chat"],
                "meta": result["meta"],
                "source": result["source"],
                "created_at": result["created_at"],
                "updated_at": result["updated_at"],
            }
        
        return None
    except Exception as e:
        logger.error(f"Failed to create conversation: {e}")
        raise


async def get_continue_conversation(conversation_id: str) -> Optional[Dict[str, Any]]:
    """
    Retrieve a Continue conversation from PostgreSQL.
    
    Args:
        conversation_id: Conversation identifier
        
    Returns:
        Conversation dict or None if not found
    """
    pool = await db.get_pool()
    if pool is None:
        return None
    
    try:
        async with pool.acquire() as conn:
            result = await conn.fetchrow(
                """
                SELECT id, title, chat, meta, source, created_at, updated_at
                FROM chat
                WHERE id = $1 AND source = 'continue'
                """,
                conversation_id
            )
        
        if result:
            # Handle both timestamp formats (bigint and timestamp)
            created_at = result["created_at"]
            updated_at = result["updated_at"]
            
            # Convert bigint timestamps to ISO format if needed
            if isinstance(created_at, (int, float)):
                created_at_str = datetime.fromtimestamp(created_at / 1000).isoformat()
            else:
                created_at_str = created_at.isoformat() if hasattr(created_at, 'isoformat') else str(created_at)
            
            if isinstance(updated_at, (int, float)):
                updated_at_str = datetime.fromtimestamp(updated_at / 1000).isoformat()
            else:
                updated_at_str = updated_at.isoformat() if hasattr(updated_at, 'isoformat') else str(updated_at)
            
            return {
                "id": str(result["id"]),
                "title": result["title"],
                "chat": result["chat"],
                "meta": result["meta"],
                "source": result["source"],
                "created_at": created_at_str,
                "updated_at": updated_at_str,
            }
        
        return None
    except Exception as e:
        logger.error(f"Failed to get conversation: {e}")
        return None


async def find_conversation_by_messages(messages: List[Dict[str, Any]]) -> Optional[str]:
    """
    Find an existing conversation by matching message history.
    
    Args:
        messages: List of messages to match
        
    Returns:
        Conversation ID if found, None otherwise
    """
    pool = await db.get_pool()
    if pool is None:
        return None
    
    try:
        # Get first user message for matching
        first_user_msg = None
        for msg in messages:
            if msg.get("role") == "user":
                first_user_msg = msg.get("content", "")
                break
        
        if not first_user_msg:
            return None
        
            # Search for conversations with matching first message
        async with pool.acquire() as conn:
            results = await conn.fetch(
                """
                SELECT id, chat, created_at
                FROM chat
                WHERE source = 'continue'
                ORDER BY created_at DESC
                LIMIT 100
                """
            )
        
        # Check each conversation for a match
        for row in results:
            chat_data = row["chat"] if row["chat"] else {}
            conv_messages = chat_data.get("messages", []) if isinstance(chat_data, dict) else []
            if len(conv_messages) > 0:
                conv_first_user = None
                for msg in conv_messages:
                    if msg.get("role") == "user":
                        conv_first_user = msg.get("content", "")
                        break
                
                # Match by first 100 characters
                if conv_first_user and first_user_msg:
                    if conv_first_user[:100] == first_user_msg[:100]:
                        return str(row["id"])
        
        return None
    except Exception as e:
        logger.error(f"Failed to find conversation by messages: {e}")
        return None


async def add_message_to_conversation(
    conversation_id: str,
    role: str,
    content: str,
    stage_data: Optional[Dict[str, Any]] = None
) -> bool:
    """
    Add a message to an existing conversation.
    
    Args:
        conversation_id: Conversation identifier
        role: Message role ('user' or 'assistant')
        content: Message content
        stage_data: Optional stage data for assistant messages
        
    Returns:
        True if successful, False otherwise
    """
    pool = await db.get_pool()
    if pool is None:
        return False
    
    try:
        # Get current conversation
        conversation = await get_continue_conversation(conversation_id)
        if not conversation:
            logger.warning(f"Conversation {conversation_id} not found")
            return False
        
        # Create new message entry
        new_message = create_message_entry(role, content, stage_data)
        
        # Add message to conversation
        messages = conversation["chat"].get("messages", [])
        messages.append(new_message)
        
        # Update conversation in database
        # Use Unix timestamp (milliseconds) for updated_at
        current_timestamp = int(time.time() * 1000)
        
        async with pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE chat
                SET chat = $1, updated_at = $2
                WHERE id = $3 AND source = 'continue'
                """,
                json.dumps({"messages": messages}),
                current_timestamp,
                conversation_id
            )
        
        return True
    except Exception as e:
        logger.error(f"Failed to add message to conversation: {e}")
        return False


async def update_conversation_title(conversation_id: str, title: str) -> bool:
    """
    Update the title of a conversation.
    
    Args:
        conversation_id: Conversation identifier
        title: New title
        
    Returns:
        True if successful, False otherwise
    """
    pool = await db.get_pool()
    if pool is None:
        return False
    
    try:
        # Use Unix timestamp (milliseconds) for updated_at
        current_timestamp = int(time.time() * 1000)
        
        async with pool.acquire() as conn:
            result = await conn.execute(
                """
                UPDATE chat
                SET title = $1, updated_at = $2
                WHERE id = $3 AND source = 'continue'
                """,
                title,
                current_timestamp,
                conversation_id
            )
        
        return result == "UPDATE 1"
    except Exception as e:
        logger.error(f"Failed to update conversation title: {e}")
        return False


async def delete_conversation(conversation_id: str) -> bool:
    """
    Delete a conversation from PostgreSQL.
    
    Args:
        conversation_id: Conversation identifier
        
    Returns:
        True if deleted, False otherwise
    """
    pool = await db.get_pool()
    if pool is None:
        return False
    
    try:
        async with pool.acquire() as conn:
            result = await conn.execute(
                """
                DELETE FROM chat
                WHERE id = $1 AND source = 'continue'
                """,
                conversation_id
            )
        
        # Result format: "DELETE n" where n is number of rows deleted
        return result.startswith("DELETE") and int(result.split()[-1]) > 0
    except Exception as e:
        logger.error(f"Failed to delete conversation: {e}")
        return False


async def list_continue_conversations(limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
    """
    List Continue conversations from PostgreSQL.
    
    Args:
        limit: Maximum number of conversations to return
        offset: Offset for pagination
        
    Returns:
        List of conversation metadata
    """
    pool = await db.get_pool()
    if pool is None:
        return []
    
    try:
        async with pool.acquire() as conn:
            results = await conn.fetch(
                """
                SELECT id, title, chat, meta, created_at, updated_at
                FROM chat
                WHERE source = 'continue'
                ORDER BY created_at DESC
                LIMIT $1 OFFSET $2
                """,
                limit,
                offset
            )
        
        conversations = []
        for row in results:
            messages = row["chat"].get("messages", []) if row["chat"] else []
            
            # Handle timestamp conversion
            created_at = row["created_at"]
            updated_at = row["updated_at"]
            
            if isinstance(created_at, (int, float)):
                created_at_str = datetime.fromtimestamp(created_at / 1000).isoformat()
            else:
                created_at_str = created_at.isoformat() if hasattr(created_at, 'isoformat') else str(created_at)
            
            if isinstance(updated_at, (int, float)):
                updated_at_str = datetime.fromtimestamp(updated_at / 1000).isoformat()
            else:
                updated_at_str = updated_at.isoformat() if hasattr(updated_at, 'isoformat') else str(updated_at)
            
            conversations.append({
                "id": str(row["id"]),
                "title": row["title"],
                "message_count": len(messages),
                "created_at": created_at_str,
                "updated_at": updated_at_str,
            })
        
        return conversations
    except Exception as e:
        logger.error(f"Failed to list conversations: {e}")
        return []

