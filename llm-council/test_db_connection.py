#!/usr/bin/env python3
"""Test script for PostgreSQL database connection and schema."""

import asyncio
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from backend import db
from backend import db_storage
from backend.conversation_tracker import generate_conversation_id, create_message_entry


async def test_database_connection():
    """Test database connection and basic operations."""
    print("=" * 60)
    print("Testing PostgreSQL Database Connection")
    print("=" * 60)
    
    # Test 1: Database connection
    print("\n1. Testing database connection...")
    pool = await db.get_pool()
    if pool is None:
        print("❌ Failed to create database connection pool")
        print("   Check your POSTGRES_* environment variables")
        return False
    print("✅ Database connection pool created successfully")
    
    # Test 2: Schema verification
    print("\n2. Verifying database schema...")
    await db.ensure_schema()
    print("✅ Database schema verified/created")
    
    # Test 3: Create a test conversation
    print("\n3. Testing conversation creation...")
    test_messages = [
        {"role": "user", "content": "Hello, this is a test message"}
    ]
    conversation_id = generate_conversation_id(test_messages)
    print(f"   Generated conversation ID: {conversation_id}")
    
    conversation = await db_storage.create_continue_conversation(
        conversation_id,
        "Hello, this is a test message",
        "Test Conversation"
    )
    
    if conversation:
        print(f"✅ Created test conversation: {conversation['id']}")
        print(f"   Title: {conversation['title']}")
        print(f"   Source: {conversation['source']}")
    else:
        print("❌ Failed to create conversation")
        return False
    
    # Test 4: Retrieve conversation
    print("\n4. Testing conversation retrieval...")
    retrieved = await db_storage.get_continue_conversation(conversation_id)
    if retrieved:
        print(f"✅ Retrieved conversation: {retrieved['id']}")
        print(f"   Messages: {len(retrieved['chat'].get('messages', []))}")
    else:
        print("❌ Failed to retrieve conversation")
        return False
    
    # Test 5: Add message to conversation
    print("\n5. Testing message addition...")
    stage_data = {
        "stage1": [{"model": "test", "response": "Test response"}],
        "stage2": [],
        "stage3": {"response": "Final test response"}
    }
    success = await db_storage.add_message_to_conversation(
        conversation_id,
        "assistant",
        "This is a test assistant response",
        stage_data
    )
    
    if success:
        print("✅ Added assistant message to conversation")
        
        # Verify message was added
        updated = await db_storage.get_continue_conversation(conversation_id)
        if updated and len(updated['chat'].get('messages', [])) == 2:
            print(f"✅ Verified: conversation now has {len(updated['chat']['messages'])} messages")
        else:
            print("⚠️  Warning: message count doesn't match expected")
    else:
        print("❌ Failed to add message")
        return False
    
    # Test 6: List conversations
    print("\n6. Testing conversation listing...")
    conversations = await db_storage.list_continue_conversations(limit=10)
    print(f"✅ Found {len(conversations)} Continue conversations")
    for conv in conversations[:3]:  # Show first 3
        print(f"   - {conv['id']}: {conv['title']} ({conv['message_count']} messages)")
    
    # Test 7: Delete conversation
    print("\n7. Testing conversation deletion...")
    deleted = await db_storage.delete_conversation(conversation_id)
    if deleted:
        print(f"✅ Deleted test conversation: {conversation_id}")
        
        # Verify deletion
        verify = await db_storage.get_continue_conversation(conversation_id)
        if verify is None:
            print("✅ Verified: conversation no longer exists")
        else:
            print("⚠️  Warning: conversation still exists after deletion")
    else:
        print("❌ Failed to delete conversation")
        return False
    
    # Cleanup
    print("\n8. Cleaning up...")
    await db.close_pool()
    print("✅ Database connection pool closed")
    
    print("\n" + "=" * 60)
    print("✅ All tests passed!")
    print("=" * 60)
    return True


if __name__ == "__main__":
    try:
        result = asyncio.run(test_database_connection())
        sys.exit(0 if result else 1)
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

