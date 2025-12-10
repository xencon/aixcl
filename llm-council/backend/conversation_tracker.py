"""Conversation ID generation and tracking for Continue plugin."""

import hashlib
import json
from typing import List, Dict, Any, Optional
from datetime import datetime


def generate_conversation_id(messages: List[Dict[str, Any]]) -> str:
    """
    Generate a stable conversation ID from the first user message.
    
    Args:
        messages: List of messages from Continue plugin
        
    Returns:
        Conversation ID in format 'continue-{hash}'
    """
    # Find the first user message
    first_user_message = None
    for msg in messages:
        if msg.get("role") == "user":
            first_user_message = msg.get("content", "")
            break
    
    if not first_user_message:
        # Fallback: use all messages to generate hash
        messages_str = json.dumps(messages, sort_keys=True)
        hash_value = hashlib.sha256(messages_str.encode()).hexdigest()[:16]
    else:
        # Hash the first user message
        hash_value = hashlib.sha256(first_user_message.encode()).hexdigest()[:16]
    
    return f"continue-{hash_value}"


def extract_conversation_context(messages: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Extract conversation context from Continue's message array.
    
    Args:
        messages: List of messages from Continue plugin
        
    Returns:
        Dictionary with extracted context information
    """
    user_messages = []
    assistant_messages = []
    system_messages = []
    
    for msg in messages:
        role = msg.get("role", "")
        content = msg.get("content", "")
        
        if role == "user":
            user_messages.append(content)
        elif role == "assistant":
            assistant_messages.append(content)
        elif role == "system":
            system_messages.append(content)
    
    return {
        "user_messages": user_messages,
        "assistant_messages": assistant_messages,
        "system_messages": system_messages,
        "total_messages": len(messages),
        "first_user_message": user_messages[0] if user_messages else None,
    }


def find_existing_conversation_id(messages: List[Dict[str, Any]], existing_conversations: List[Dict[str, Any]]) -> Optional[str]:
    """
    Find an existing conversation ID by matching message history.
    
    Args:
        messages: Current message list from Continue
        existing_conversations: List of existing conversations from database
        
    Returns:
        Conversation ID if match found, None otherwise
    """
    if not existing_conversations or not messages:
        return None
    
    # Extract first user message for matching
    first_user_msg = None
    for msg in messages:
        if msg.get("role") == "user":
            first_user_msg = msg.get("content", "")
            break
    
    if not first_user_msg:
        return None
    
    # Hash the first user message
    first_hash = hashlib.sha256(first_user_msg.encode()).hexdigest()[:16]
    expected_id = f"continue-{first_hash}"
    
    # Check if conversation with this ID exists
    for conv in existing_conversations:
        if conv.get("id") == expected_id:
            return expected_id
    
    # Try to match by message count and first message similarity
    # This is a fallback for cases where hash might differ slightly
    for conv in existing_conversations:
        conv_messages = conv.get("chat", {}).get("messages", [])
        if len(conv_messages) > 0:
            conv_first_user = None
            for msg in conv_messages:
                if msg.get("role") == "user":
                    conv_first_user = msg.get("content", "")
                    break
            
            # Simple similarity check: first 100 chars match
            if conv_first_user and first_user_msg:
                if conv_first_user[:100] == first_user_msg[:100]:
                    return conv.get("id")
    
    return None


def create_message_entry(role: str, content: str, stage_data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Create a message entry for storage in PostgreSQL.
    
    Args:
        role: Message role ('user' or 'assistant')
        content: Message content
        stage_data: Optional stage data (stage1, stage2, stage3) for assistant messages
        
    Returns:
        Message dictionary ready for JSONB storage
    """
    message = {
        "role": role,
        "content": content,
        "timestamp": datetime.utcnow().isoformat(),
    }
    
    if stage_data and role == "assistant":
        # Add stage data for assistant messages
        if "stage1" in stage_data:
            message["stage1"] = stage_data["stage1"]
        if "stage2" in stage_data:
            message["stage2"] = stage_data["stage2"]
        if "stage3" in stage_data:
            message["stage3"] = stage_data["stage3"]
    
    return message

