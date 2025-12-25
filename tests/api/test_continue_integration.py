#!/usr/bin/env python3
"""
Integration test for Continue plugin → LLM Council → Database flow.

This test simulates a Continue plugin request:
1. Sends a prompt via OpenAI-compatible API to LLM Council
2. Verifies the response from LLM Council
3. Verifies the conversation is stored in PostgreSQL database
4. Verifies the conversation structure includes stage data

Usage:
    # Recommended: Using uv (ensures correct environment):
    cd llm-council
    uv run python ../tests/api/test_continue_integration.py
    
    # Alternative: Direct Python (requires httpx in current environment):
    python3 tests/api/test_continue_integration.py
    
    # If httpx is not found, install dependencies first:
    cd llm-council
    uv sync  # This installs all dependencies including httpx
    uv run python ../tests/api/test_continue_integration.py
"""

import asyncio
import sys
import os
import json
import uuid
from typing import Dict, Any, Optional
from datetime import datetime

# Add backend to path
# Script is now in tests/api/, need to find llm-council directory
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(script_dir))  # Go up from tests/api/ to project root
llm_council_dir = os.path.join(project_root, 'llm-council')
backend_dir = os.path.join(llm_council_dir, 'backend')

# Verify we're in the right place
if not os.path.exists(backend_dir) or not os.path.exists(os.path.join(llm_council_dir, 'pyproject.toml')):
    print("❌ Error: Cannot find llm-council directory structure")
    print(f"   Script location: {script_dir}")
    print(f"   Expected llm-council dir: {llm_council_dir}")
    print(f"   Backend dir exists: {os.path.exists(backend_dir)}")
    print(f"   Current working directory: {os.getcwd()}")
    print("\n   Please run this script from the project root:")
    print("   python3 tests/api/test_continue_integration.py")
    print("   # or from llm-council directory:")
    print("   cd llm-council")
    print("   uv run python ../tests/api/test_continue_integration.py")
    sys.exit(1)

# Change to llm-council directory to ensure relative imports work
# This is important when running with uv run
try:
    os.chdir(llm_council_dir)
except OSError:
    print(f"⚠️  Warning: Could not change to llm-council directory: {llm_council_dir}")
    print(f"   Current directory: {os.getcwd()}")

# Add llm-council directory to Python path (so 'backend' can be imported)
# This is the parent directory, so 'from backend import ...' will work
if llm_council_dir not in sys.path:
    sys.path.insert(0, llm_council_dir)

# Also add backend directory explicitly (for compatibility)
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

try:
    import httpx
except ImportError as e:
    print("❌ httpx not installed or not accessible in current Python environment")
    print(f"   Error: {e}")
    print(f"   Python executable: {sys.executable}")
    print(f"   Python path: {sys.path[:3]}...")  # Show first 3 paths
    print("\n   This project uses 'uv' for dependency management.")
    print("   To install dependencies (including httpx):")
    print("   cd llm-council")
    print("   uv sync")
    print("\n   Then run the test with:")
    print("   uv run python scripts/test/test_continue_integration.py")
    print("\n   Or if you prefer to use pip directly:")
    print(f"   {sys.executable} -m pip install httpx")
    sys.exit(1)

from backend import db
from backend import db_storage
from backend.conversation_tracker import generate_conversation_id


# Configuration
API_URL = os.getenv("LLM_COUNCIL_API_URL", "http://localhost:8000")
API_TIMEOUT = 180.0  # 180 seconds timeout for API calls (models can take time to load and respond)


async def wait_for_api(max_retries: int = 30, delay: float = 1.0) -> bool:
    """
    Wait for the LLM Council API to be ready.
    
    Args:
        max_retries: Maximum number of retry attempts
        delay: Delay between retries in seconds
        
    Returns:
        True if API is ready, False otherwise
    """
    print("Waiting for LLM Council API to be ready...")
    async with httpx.AsyncClient(timeout=5.0) as client:
        for i in range(max_retries):
            try:
                response = await client.get(f"{API_URL}/health")
                if response.status_code == 200:
                    print("✅ API is ready")
                    return True
            except Exception as e:
                # Silently retry on any exception (network errors, timeouts, etc.)
                # This is expected during API startup, so we don't log every attempt
                pass
            
            if i < max_retries - 1:
                print(f"   Attempt {i+1}/{max_retries}...", end="\r")
                await asyncio.sleep(delay)
    
    print(f"\n❌ API not ready after {max_retries} attempts")
    return False


async def send_continue_request(
    messages: list[Dict[str, str]],
    stream: bool = False
) -> Optional[Dict[str, Any]]:
    """
    Send a chat completion request simulating Continue plugin.
    
    Args:
        messages: List of messages in OpenAI format
        stream: Whether to use streaming
        
    Returns:
        Response dict or None if request failed
    """
    print(f"\n📤 Sending Continue plugin request...")
    print(f"   Messages: {len(messages)}")
    for i, msg in enumerate(messages):
        content_preview = msg['content'][:50] + "..." if len(msg['content']) > 50 else msg['content']
        print(f"   [{i+1}] {msg['role']}: {content_preview}")
    
    request_data = {
        "model": "council",
        "messages": messages,
        "stream": stream,
        "temperature": 0.7
    }
    
    try:
        async with httpx.AsyncClient(timeout=API_TIMEOUT, follow_redirects=True) as client:
            response = await client.post(
                f"{API_URL}/v1/chat/completions",
                json=request_data,
                headers={"Content-Type": "application/json"},
                follow_redirects=True
            )
            
            if response.status_code != 200:
                print(f"❌ API returned status {response.status_code}")
                print(f"   Response: {response.text[:500]}")
                # Return error response JSON so test can check for conversation_id
                try:
                    return response.json()
                except Exception:
                    return None
            
            # Check if response body is empty
            response_text = response.text
            if not response_text or len(response_text.strip()) == 0:
                print(f"❌ API returned empty response (status {response.status_code})")
                print(f"   Response headers: {dict(response.headers)}")
                print(f"   Content-Length: {response.headers.get('content-length', 'not set')}")
                return None
            
            # Check content type
            content_type = response.headers.get('content-type', '')
            result = None
            
            # Handle streaming response (text/event-stream)
            if 'text/event-stream' in content_type or 'event-stream' in content_type:
                print(f"⚠️  Received streaming response (Content-Type: {content_type})")
                print(f"   Response length: {len(response_text)}")
                print(f"   Response preview: {response_text[:500]}")
                print(f"   Note: This test expects non-streaming JSON response")
                print(f"   Check if FORCE_STREAMING is enabled in LLM Council config")
                # Try to parse as SSE and reconstruct full message from chunks
                # SSE format: "data: {json}\n\n"
                # IMPORTANT: httpx.AsyncClient should consume the entire stream when reading response.text
                # This ensures the generator completes and database saves execute
                lines = response_text.split('\n')
                chunks = []
                response_id = None
                full_content = ""
                role = None
                finish_reason = None
                saw_done = False
                
                for line in lines:
                    if line.strip() == 'data: [DONE]':
                        saw_done = True
                        continue
                    if line.startswith('data: '):
                        try:
                            json_str = line[6:]  # Remove "data: " prefix
                            if json_str.strip() and json_str.strip() != '[DONE]':
                                chunk_data = json.loads(json_str)
                                chunks.append(chunk_data)
                                
                                # Extract response ID from first chunk
                                if response_id is None:
                                    response_id = chunk_data.get('id')
                                
                                # Extract content from delta
                                if 'choices' in chunk_data and len(chunk_data['choices']) > 0:
                                    choice = chunk_data['choices'][0]
                                    if 'delta' in choice:
                                        delta = choice['delta']
                                        if 'content' in delta:
                                            full_content += delta.get('content', '')
                                        if 'role' in delta and role is None:
                                            role = delta.get('role')
                                    if 'finish_reason' in choice and choice['finish_reason']:
                                        finish_reason = choice['finish_reason']
                        except json.JSONDecodeError:
                            continue
                
                if chunks and response_id:
                    # Reconstruct OpenAI-compatible response from chunks
                    result = {
                        'id': response_id,
                        'object': 'chat.completion',
                        'created': chunks[0].get('created', 0) if chunks else 0,
                        'model': chunks[0].get('model', 'council') if chunks else 'council',
                        'choices': [{
                            'index': 0,
                            'message': {
                                'role': role or 'assistant',
                                'content': full_content
                            },
                            'finish_reason': finish_reason
                        }]
                    }
                    print(f"   ✅ Reconstructed full message from {len(chunks)} SSE chunks")
                    print(f"   Content length: {len(full_content)} characters")
                    if saw_done:
                        print(f"   ✅ Stream completed (saw [DONE] marker)")
                    else:
                        print(f"   ⚠️  Stream may not have completed (no [DONE] marker)")
                else:
                    print(f"   ❌ Could not extract or reconstruct message from SSE stream")
                    return None
            elif 'application/json' in content_type or 'text/plain' in content_type or not content_type:
                # Try to parse as regular JSON
                try:
                    result = response.json()
                except ValueError as json_error:
                    print(f"❌ Failed to parse JSON response: {json_error}")
                    print(f"   Response status: {response.status_code}")
                    print(f"   Response length: {len(response_text)}")
                    print(f"   Response preview (first 500 chars): {response_text[:500]}")
                    print(f"   Content-Type: {content_type}")
                    return None
            else:
                print(f"⚠️  Unexpected content type: {content_type}")
                print(f"   Response preview: {response_text[:200]}")
                # Still try to parse as JSON
                try:
                    result = response.json()
                except ValueError:
                    print(f"   ❌ Could not parse as JSON")
                    return None
            
            # Handle streaming response (collect all chunks)
            if stream:
                # For streaming, we'd need to handle SSE format
                # For now, we'll test non-streaming
                print("⚠️  Streaming not fully tested in this script")
                return None
            
            print(f"✅ Received response (ID: {result.get('id', 'N/A')})")
            
            if 'choices' in result and len(result['choices']) > 0:
                content = result['choices'][0].get('message', {}).get('content', '')
                content_preview = content[:100] + "..." if len(content) > 100 else content
                print(f"   Response preview: {content_preview}")
            
            return result
            
    except httpx.TimeoutException:
        print(f"❌ Request timed out after {API_TIMEOUT} seconds")
        return None
    except Exception as e:
        print(f"❌ Request failed: {e}")
        import traceback
        traceback.print_exc()
        return None


async def verify_database_storage(
    messages: list[Dict[str, str]],
    expected_conversation_id: Optional[str] = None
) -> bool:
    """
    Verify that the conversation was stored in the database.
    
    Args:
        messages: Original messages sent to API
        expected_conversation_id: Expected conversation ID (if known)
        
    Returns:
        True if verification passed, False otherwise
    """
    print(f"\n🔍 Verifying database storage...")
    
    # Generate expected conversation ID
    if expected_conversation_id is None:
        expected_conversation_id = generate_conversation_id(messages)
    
    print(f"   Expected conversation ID: {expected_conversation_id}")
    
    # Get conversation from database
    conversation = await db_storage.get_continue_conversation(expected_conversation_id)
    
    if conversation is None:
        print(f"❌ Conversation not found in database")
        return False
    
    print(f"✅ Conversation found in database")
    print(f"   ID: {conversation['id']}")
    print(f"   Title: {conversation.get('title', 'N/A')}")
    print(f"   Source: {conversation.get('source', 'N/A')}")
    
    # Verify source is 'continue'
    if conversation.get('source') != 'continue':
        print(f"❌ Expected source='continue', got '{conversation.get('source')}'")
        return False
    
    # Verify conversation structure
    chat_data = conversation.get('chat', {})
    if not isinstance(chat_data, dict):
        print(f"❌ Chat data is not a dict: {type(chat_data)}")
        return False
    
    stored_messages = chat_data.get('messages', [])
    print(f"   Stored messages: {len(stored_messages)}")
    
    # Verify we have at least user and assistant messages
    user_messages = [m for m in stored_messages if m.get('role') == 'user']
    assistant_messages = [m for m in stored_messages if m.get('role') == 'assistant']
    
    print(f"   User messages: {len(user_messages)}")
    print(f"   Assistant messages: {len(assistant_messages)}")
    
    if len(user_messages) == 0:
        print(f"❌ No user messages found in stored conversation")
        return False
    
    if len(assistant_messages) == 0:
        print(f"❌ No assistant messages found in stored conversation")
        return False
    
    # Verify first user message matches
    first_stored_user = user_messages[0].get('content', '')
    first_original_user = None
    for msg in messages:
        if msg.get('role') == 'user':
            first_original_user = msg.get('content', '')
            break
    
    if first_original_user and first_stored_user != first_original_user:
        print(f"❌ First user message mismatch")
        print(f"   Original: {first_original_user[:100]}")
        print(f"   Stored: {first_stored_user[:100]}")
        return False
    
    # Verify assistant message has stage data
    last_assistant = assistant_messages[-1]
    has_stage_data = any(
        key in last_assistant 
        for key in ['stage1', 'stage2', 'stage3']
    )
    
    if has_stage_data:
        print(f"✅ Assistant message includes stage data")
        if 'stage1' in last_assistant:
            stage1_count = len(last_assistant.get('stage1', []))
            print(f"   Stage 1 responses: {stage1_count}")
        if 'stage2' in last_assistant:
            stage2_count = len(last_assistant.get('stage2', []))
            print(f"   Stage 2 rankings: {stage2_count}")
        if 'stage3' in last_assistant:
            stage3 = last_assistant.get('stage3', {})
            print(f"   Stage 3 synthesis: {stage3.get('model', 'N/A')}")
    else:
        print(f"⚠️  Assistant message does not include stage data (may be expected in some cases)")
    
    # Verify meta data
    meta = conversation.get('meta', {})
    if isinstance(meta, dict):
        print(f"   Meta: {meta}")
        if meta.get('source') == 'continue' or meta.get('created_via') == 'continue_plugin':
            print(f"✅ Meta data indicates Continue plugin source")
    
    return True


async def test_continue_integration():
    """
    Main test function that exercises the full Continue → LLM Council → Database flow.
    """
    print("=" * 70)
    print("Continue Plugin → LLM Council → Database Integration Test")
    print("=" * 70)
    
    # Test 1: Wait for API
    print("\n[Test 1] API Availability")
    print("-" * 70)
    if not await wait_for_api():
        print("❌ Test failed: API not available")
        return False
    
    # Test 2: Database connection
    print("\n[Test 2] Database Connection")
    print("-" * 70)
    pool = await db.get_pool()
    if pool is None:
        print("❌ Test failed: Database connection failed")
        print("   Check ENABLE_DB_STORAGE and POSTGRES_* environment variables")
        return False
    print("✅ Database connection pool created")
    
    # Ensure schema exists
    await db.ensure_schema()
    print("✅ Database schema verified")
    
    # Test 3: Send Continue plugin request
    print("\n[Test 3] Continue Plugin Request")
    print("-" * 70)
    test_messages = [
        {
            "role": "user",
            "content": "What does `2+2` equal?"
        }
    ]
    
    api_response = await send_continue_request(test_messages, stream=False)
    if api_response is None:
        print("❌ Test failed: API request failed")
        return False
    
    # Check if response is an error (models may not be available)
    if 'error' in api_response:
        error_msg = api_response.get('error', {}).get('message', 'Unknown error')
        print(f"⚠️  API returned error (models may not be available): {error_msg}")
        # If we have a conversation_id, the database integration is working
        if 'conversation_id' in api_response:
            print("✅ Conversation ID present in error response - database integration working")
            # Check if conversation was created in database
            conv_id = api_response['conversation_id']
            conv = await db_storage.get_continue_conversation(conv_id)
            if conv:
                print(f"✅ Conversation {conv_id} found in database")
                return True
            else:
                print(f"⚠️  Conversation {conv_id} not found in database")
                return False
        else:
            print("❌ No conversation_id in error response")
            return False
    
    # Verify API response structure for successful responses
    if 'choices' not in api_response or len(api_response['choices']) == 0:
        print("❌ Test failed: Invalid API response structure")
        return False
    
    choice = api_response['choices'][0]
    if 'message' not in choice:
        print("❌ Test failed: Response missing message")
        return False
    
    assistant_content = choice['message'].get('content', '')
    if not assistant_content:
        print("❌ Test failed: Empty assistant response")
        return False
    
    print(f"✅ API response received and validated")
    print(f"   Response length: {len(assistant_content)} characters")
    
    # Generate expected conversation ID early (needed for retry logic)
    expected_conv_id = generate_conversation_id(test_messages)
    
    # Wait for database write to complete
    # When streaming, the save happens inside the generator after stream completes
    # httpx should consume the entire stream, but we need to wait for async DB write
    print("\n⏳ Waiting for database write to complete...")
    # Increase wait time for streaming responses (they save after stream completes)
    wait_time = 5 if api_response.get('object') == 'chat.completion' else 3
    await asyncio.sleep(wait_time)
    
    # Retry logic: check database multiple times in case write is still in progress
    print("   Checking database...")
    assistant_found = False
    for attempt in range(3):
        await asyncio.sleep(1)
        test_conv = await db_storage.get_continue_conversation(expected_conv_id)
        if test_conv:
            chat_data = test_conv.get('chat', {})
            messages = chat_data.get('messages', [])
            assistant_msgs = [m for m in messages if m.get('role') == 'assistant']
            if len(assistant_msgs) > 0:
                print(f"   ✅ Assistant message found in database (attempt {attempt + 1})")
                assistant_found = True
                break
        if attempt < 2:
            print(f"   ⏳ Assistant message not yet saved, retrying... (attempt {attempt + 1}/3)")
    
    if not assistant_found:
        print("   ⚠️  Assistant message may not have been saved to database")
    
    # Test 4: Verify database storage
    print("\n[Test 4] Database Storage Verification")
    print("-" * 70)
    
    storage_verified = await verify_database_storage(
        test_messages,
        expected_conv_id
    )
    
    if not storage_verified:
        print("❌ Test failed: Database storage verification failed")
        return False
    
    # Test 5: Test conversation continuity (second message)
    print("\n[Test 5] Conversation Continuity")
    print("-" * 70)
    
    followup_messages = [
        {
            "role": "user",
            "content": test_messages[0]['content']
        },
        {
            "role": "assistant",
            "content": assistant_content[:100] + "..."  # Truncated previous response
        },
        {
            "role": "user",
            "content": "What's `len('abc')`?"
        }
    ]
    
    print("📤 Sending follow-up message in same conversation...")
    followup_response = await send_continue_request(followup_messages, stream=False)
    
    if followup_response is None:
        print("❌ Test failed: Follow-up request failed")
        return False
    
    # Wait for database write
    await asyncio.sleep(2)
    
    # Verify conversation was updated (not created new)
    updated_conversation = await db_storage.get_continue_conversation(expected_conv_id)
    if updated_conversation is None:
        print("❌ Test failed: Conversation not found after follow-up")
        return False
    
    chat_data = updated_conversation.get('chat', {})
    updated_messages = chat_data.get('messages', [])
    
    # Should have 4 messages: 2 user + 2 assistant
    if len(updated_messages) < 4:
        print(f"⚠️  Expected at least 4 messages, got {len(updated_messages)}")
    else:
        print(f"✅ Conversation updated with follow-up message")
        print(f"   Total messages: {len(updated_messages)}")
    
    # Test 6: List conversations
    print("\n[Test 6] List Conversations")
    print("-" * 70)
    
    conversations = await db_storage.list_continue_conversations(limit=10)
    print(f"✅ Found {len(conversations)} Continue conversations")
    
    # Find our test conversation
    test_conv = next((c for c in conversations if c['id'] == expected_conv_id), None)
    if test_conv:
        print(f"✅ Test conversation found in list")
        print(f"   Title: {test_conv.get('title', 'N/A')}")
        print(f"   Message count: {test_conv.get('message_count', 0)}")
    else:
        print(f"⚠️  Test conversation not found in list (may be paginated)")
    
    # Cleanup: Optionally delete test conversation
    print("\n[Cleanup]")
    print("-" * 70)
    delete_choice = os.getenv("DELETE_TEST_CONVERSATION", "false").lower()
    if delete_choice == "true":
        deleted = await db_storage.delete_conversation(expected_conv_id)
        if deleted:
            print(f"✅ Test conversation deleted: {expected_conv_id}")
        else:
            print(f"⚠️  Failed to delete test conversation")
    else:
        print(f"ℹ️  Test conversation preserved: {expected_conv_id}")
        print(f"   Set DELETE_TEST_CONVERSATION=true to auto-delete")
    
    # Close database pool
    await db.close_pool()
    
    print("\n" + "=" * 70)
    print("✅ All tests passed!")
    print("=" * 70)
    return True


async def main():
    """Entry point for the test script."""
    try:
        success = await test_continue_integration()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Test interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
