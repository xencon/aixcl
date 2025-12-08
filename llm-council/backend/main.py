"""FastAPI backend for LLM Council."""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Dict, Any
import uuid
import json
import asyncio
import os
import time
import sys
import re

from . import storage
from .council import run_full_council, generate_conversation_title, stage1_collect_responses, stage2_collect_rankings, stage3_synthesize_final, calculate_aggregate_rankings
from .config import BACKEND_MODE, COUNCIL_MODELS, CHAIRMAN_MODEL, OLLAMA_BASE_URL, FORCE_STREAMING, ENABLE_MARKDOWN_FORMATTING


def format_markdown_response(content: str) -> str:
    """
    Format response content to ensure proper markdown rendering in Continue plugin.
    Fixes bullet points, numbered lists, and other markdown formatting issues.
    """
    if not content:
        return content
    
    lines = content.split('\n')
    formatted_lines = []
    in_list = False
    list_type = None  # 'bullet' or 'numbered'
    list_counter = 1  # For numbered lists
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        original_line = line
        
        # Check if this is a bullet point (various formats: -, *, •)
        bullet_match = re.match(r'^[-*•]\s+(.+)$', stripped)
        # Check if this is a numbered list item (1. or 1) format)
        numbered_match = re.match(r'^(\d+)[.)]\s+(.+)$', stripped)
        
        if bullet_match:
            # Normalize bullet points to use '- ' (standard markdown)
            content_text = bullet_match.group(1)
            if not in_list or list_type != 'bullet':
                # Start new list, ensure blank line before
                if formatted_lines and formatted_lines[-1].strip() and not formatted_lines[-1].startswith('-'):
                    formatted_lines.append('')
                in_list = True
                list_type = 'bullet'
                list_counter = 1
            formatted_lines.append(f'- {content_text}')
        elif numbered_match:
            # Normalize numbered lists - preserve the number for better compatibility
            number = int(numbered_match.group(1))
            content_text = numbered_match.group(2)
            if not in_list or list_type != 'numbered':
                # Start new list, ensure blank line before
                if formatted_lines and formatted_lines[-1].strip() and not re.match(r'^\d+[.)]', formatted_lines[-1].strip()):
                    formatted_lines.append('')
                in_list = True
                list_type = 'numbered'
                list_counter = number
            # Use the actual number (markdown will render it correctly)
            formatted_lines.append(f'{list_counter}. {content_text}')
            list_counter += 1
        else:
            # Regular line
            if in_list and stripped:
                # End list if we hit a non-empty non-list line
                # But check if it's a continuation (indented line after list item)
                leading_spaces = len(original_line) - len(original_line.lstrip())
                if leading_spaces < 2:  # Not significantly indented
                    in_list = False
                    list_type = None
                    list_counter = 1
                    # Add blank line after list for proper markdown rendering
                    if formatted_lines and formatted_lines[-1].strip():
                        formatted_lines.append('')
            
            # Preserve original line
            if not stripped:
                # Empty line - preserve it but limit consecutive empty lines
                if formatted_lines and formatted_lines[-1].strip():
                    formatted_lines.append('')
            else:
                # Check if line is in a code block
                if stripped.startswith('```'):
                    # Code block marker - preserve exactly
                    formatted_lines.append(original_line)
                elif original_line.startswith('    ') or original_line.startswith('\t'):
                    # Indented line (code or nested content) - preserve indentation
                    formatted_lines.append(original_line)
                else:
                    # Regular line - preserve as-is
                    formatted_lines.append(original_line)
    
    # Join lines back together
    formatted_content = '\n'.join(formatted_lines)
    
    # Fix common markdown issues:
    # 1. Ensure proper spacing around headers (but not inside code blocks)
    # Split by code blocks, fix headers, then rejoin
    parts = re.split(r'(```[^\n]*\n.*?```)', formatted_content, flags=re.DOTALL)
    fixed_parts = []
    for part in parts:
        if part.startswith('```'):
            # Code block - don't modify
            fixed_parts.append(part)
        else:
            # Regular content - fix headers
            fixed = re.sub(r'\n(#{1,6}\s+.+)\n([^\n#\s])', r'\n\1\n\n\2', part)
            fixed_parts.append(fixed)
    formatted_content = ''.join(fixed_parts)
    
    # 2. Fix multiple consecutive blank lines (max 2, but preserve in code blocks)
    # This is tricky with code blocks, so we'll be conservative
    formatted_content = re.sub(r'\n{4,}', '\n\n\n', formatted_content)
    
    # 3. Ensure lists have proper spacing
    # Lists should have a blank line before them (if not already)
    formatted_content = re.sub(r'([^\n])\n([-*]|\d+[.)])', r'\1\n\n\2', formatted_content)
    
    return formatted_content

app = FastAPI(title="LLM Council API")

# Print startup configuration
print("=" * 60)
print("DEBUG: LLM Council API starting up")
print(f"DEBUG: BACKEND_MODE = {BACKEND_MODE}")
print(f"DEBUG: COUNCIL_MODELS = {COUNCIL_MODELS}")
print(f"DEBUG: CHAIRMAN_MODEL = {CHAIRMAN_MODEL}")
print(f"DEBUG: OLLAMA_BASE_URL = {OLLAMA_BASE_URL}")
print("=" * 60)

# Enable CORS for local development
# Continue plugin may run from various origins, so allow all localhost ports
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for Continue plugin compatibility
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class CreateConversationRequest(BaseModel):
    """Request to create a new conversation."""
    pass


class SendMessageRequest(BaseModel):
    """Request to send a message in a conversation."""
    content: str


class ConversationMetadata(BaseModel):
    """Conversation metadata for list view."""
    id: str
    created_at: str
    title: str
    message_count: int


class Conversation(BaseModel):
    """Full conversation with all messages."""
    id: str
    created_at: str
    title: str
    messages: List[Dict[str, Any]]


# OpenAI-compatible request/response models
class ChatMessage(BaseModel):
    """OpenAI-compatible chat message."""
    role: str
    content: str


class ChatCompletionRequest(BaseModel):
    """OpenAI-compatible chat completion request."""
    model: str = "council"
    messages: List[ChatMessage]
    temperature: float = 0.7
    stream: bool = False


class ChatCompletionChoice(BaseModel):
    """OpenAI-compatible choice."""
    index: int
    message: ChatMessage
    finish_reason: str = "stop"


class ChatCompletionResponse(BaseModel):
    """OpenAI-compatible chat completion response."""
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[ChatCompletionChoice]
    usage: Dict[str, Any]


@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "ok", "service": "LLM Council API"}


@app.get("/health")
async def health():
    """Health check endpoint for Docker."""
    return {"status": "healthy", "service": "LLM Council API"}


@app.get("/v1/models")
async def list_models():
    """
    OpenAI-compatible models list endpoint for Continue plugin integration.
    """
    return {
        "object": "list",
        "data": [
            {
                "id": "council",
                "object": "model",
                "created": int(time.time()),
                "owned_by": "llm-council"
            }
        ]
    }


@app.get("/api/conversations", response_model=List[ConversationMetadata])
async def list_conversations():
    """List all conversations (metadata only)."""
    return storage.list_conversations()


@app.post("/api/conversations", response_model=Conversation)
async def create_conversation(request: CreateConversationRequest):
    """Create a new conversation."""
    conversation_id = str(uuid.uuid4())
    conversation = storage.create_conversation(conversation_id)
    return conversation


@app.get("/api/conversations/{conversation_id}", response_model=Conversation)
async def get_conversation(conversation_id: str):
    """Get a specific conversation with all its messages."""
    conversation = storage.get_conversation(conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return conversation


@app.post("/api/conversations/{conversation_id}/message")
async def send_message(conversation_id: str, request: SendMessageRequest):
    """
    Send a message and run the 3-stage council process.
    Returns the complete response with all stages.
    """
    # Check if conversation exists
    conversation = storage.get_conversation(conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")

    # Check if this is the first message
    is_first_message = len(conversation["messages"]) == 0

    # Add user message
    storage.add_user_message(conversation_id, request.content)

    # If this is the first message, generate a title
    if is_first_message:
        title = await generate_conversation_title(request.content)
        storage.update_conversation_title(conversation_id, title)

    # Run the 3-stage council process
    stage1_results, stage2_results, stage3_result, metadata = await run_full_council(
        request.content
    )

    # Add assistant message with all stages
    storage.add_assistant_message(
        conversation_id,
        stage1_results,
        stage2_results,
        stage3_result
    )

    # Return the complete response with metadata
    return {
        "stage1": stage1_results,
        "stage2": stage2_results,
        "stage3": stage3_result,
        "metadata": metadata
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: ChatCompletionRequest):
    """
    OpenAI-compatible chat completions endpoint for Continue plugin integration.
    """
    print("DEBUG: chat_completions called", flush=True)
    print(f"DEBUG: request.stream = {request.stream}", flush=True)
    print(f"DEBUG: request.model = {request.model}", flush=True)
    sys.stdout.flush()
    try:
        # Log all messages to see what Continue is sending
        print(f"DEBUG: received {len(request.messages)} messages", flush=True)
        for i, msg in enumerate(request.messages):
            print(f"DEBUG: message[{i}] role={msg.role}, content_length={len(msg.content)}", flush=True)
            if len(msg.content) > 500:
                print(f"DEBUG: message[{i}] content preview: {msg.content[:500]}...", flush=True)
            else:
                print(f"DEBUG: message[{i}] content: {msg.content}", flush=True)
        
        # Build the full context from all messages
        # Continue sends file context in system messages and conversation in user/assistant messages
        context_parts = []
        user_queries = []
        
        for msg in request.messages:
            if msg.role == "system":
                # System messages often contain file context or instructions
                context_parts.append(msg.content)
            elif msg.role == "user":
                # Collect all user messages (the last one is usually the actual query)
                user_queries.append(msg.content)
            elif msg.role == "assistant":
                # Previous assistant responses for conversation context
                context_parts.append(f"Previous response: {msg.content}")
        
        # The last user message is the actual query
        if not user_queries:
            raise HTTPException(status_code=400, detail="No user message found")
        
        user_query = user_queries[-1]
        
        # If there's context (file contents, previous messages), prepend it
        if context_parts:
            context_text = "\n\n".join(context_parts)
            # Build a comprehensive prompt that includes context
            user_query = f"""Context and file contents:
{context_text}

User's question or request:
{user_query}

Please provide a helpful response based on the context provided above."""
        
        print(f"DEBUG: final user_query length = {len(user_query)}", flush=True)
        print(f"DEBUG: user_query preview = {user_query[:500]}...", flush=True)
        
        # Run the 3-stage council process
        print("DEBUG: about to call run_full_council", flush=True)
        stage1_results, stage2_results, stage3_result, metadata = await run_full_council(
            user_query
        )
        print(f"DEBUG: run_full_council returned")
        print(f"DEBUG: stage1_results count = {len(stage1_results)}")
        print(f"DEBUG: stage2_results count = {len(stage2_results)}")
        print(f"DEBUG: stage3_result = {stage3_result}")
        
        # Extract the final response from stage 3
        # Note: stage3_result uses 'response' key, not 'content'
        final_content = stage3_result.get('response', stage3_result.get('content', ''))
        print(f"DEBUG: final_content length (before formatting) = {len(final_content)}", flush=True)
        print(f"DEBUG: final_content preview (before formatting) = {final_content[:200]}", flush=True)
        
        # If content is empty, log the full stage3_result for debugging
        if not final_content:
            print(f"DEBUG: WARNING - final_content is empty!", flush=True)
            print(f"DEBUG: stage3_result keys = {list(stage3_result.keys())}", flush=True)
            print(f"DEBUG: stage3_result full = {stage3_result}", flush=True)
            sys.stdout.flush()
        else:
            # Format the content to ensure proper markdown rendering in Continue plugin
            if ENABLE_MARKDOWN_FORMATTING:
                original_length = len(final_content)
                final_content = format_markdown_response(final_content)
                print(f"DEBUG: Markdown formatting applied (length: {original_length} -> {len(final_content)})", flush=True)
                print(f"DEBUG: final_content preview (after formatting) = {final_content[:200]}", flush=True)
            else:
                print(f"DEBUG: Markdown formatting disabled, using original content", flush=True)
        
        # Handle streaming if requested or forced
        should_stream = request.stream or FORCE_STREAMING
        if should_stream:
            if FORCE_STREAMING and not request.stream:
                print("DEBUG: FORCE_STREAMING enabled, converting to streaming response", flush=True)
            print("DEBUG: Streaming response requested", flush=True)
            async def generate_stream():
                response_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
                created_time = int(time.time())
                
                # OpenAI streaming format: first send role, then content chunks
                # Send initial chunk with role (OpenAI does this)
                initial_chunk = {
                    "id": response_id,
                    "object": "chat.completion.chunk",
                    "created": created_time,
                    "model": request.model,
                    "choices": [{
                        "index": 0,
                        "delta": {"role": "assistant"},
                        "finish_reason": None
                    }]
                }
                yield f"data: {json.dumps(initial_chunk)}\n\n"
                
                # Stream content in character-based chunks for smoother display
                # Use smaller chunks (50-100 chars) for better real-time feel
                chunk_size = 50
                content_length = len(final_content)
                
                for i in range(0, content_length, chunk_size):
                    chunk = final_content[i:i+chunk_size]
                    
                    chunk_data = {
                        "id": response_id,
                        "object": "chat.completion.chunk",
                        "created": created_time,
                        "model": request.model,
                        "choices": [{
                            "index": 0,
                            "delta": {"content": chunk},
                            "finish_reason": None
                        }]
                    }
                    yield f"data: {json.dumps(chunk_data)}\n\n"
                    # Small delay to simulate real-time generation (optional, can remove)
                    await asyncio.sleep(0.01)
                
                # Send final chunk with finish_reason
                final_chunk = {
                    "id": response_id,
                    "object": "chat.completion.chunk",
                    "created": created_time,
                    "model": request.model,
                    "choices": [{
                        "index": 0,
                        "delta": {},
                        "finish_reason": "stop"
                    }]
                }
                yield f"data: {json.dumps(final_chunk)}\n\n"
                yield "data: [DONE]\n\n"
            
            return StreamingResponse(
                generate_stream(),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no",  # Disable buffering for nginx
                }
            )
        
        # Non-streaming response
        response_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
        created_time = int(time.time())
        
        # Create OpenAI-compatible response
        response = ChatCompletionResponse(
            id=response_id,
            created=created_time,
            model=request.model,
            choices=[
                ChatCompletionChoice(
                    index=0,
                    message=ChatMessage(
                        role="assistant",
                        content=final_content
                    ),
                    finish_reason="stop"
                )
            ],
            usage={
                "prompt_tokens": len(user_query.split()),  # Rough estimate
                "completion_tokens": len(final_content.split()),  # Rough estimate
                "total_tokens": len(user_query.split()) + len(final_content.split())
            }
        )
        
        print("DEBUG: returning non-streaming response", flush=True)
        response_dict = response.model_dump()
        print(f"DEBUG: response dict keys = {list(response_dict.keys())}", flush=True)
        print(f"DEBUG: response choices count = {len(response_dict.get('choices', []))}", flush=True)
        if response_dict.get('choices'):
            choice = response_dict['choices'][0]
            print(f"DEBUG: choice keys = {list(choice.keys())}", flush=True)
            print(f"DEBUG: message keys = {list(choice.get('message', {}).keys())}", flush=True)
            content = choice.get('message', {}).get('content', '')
            print(f"DEBUG: message content length = {len(content)}", flush=True)
            print(f"DEBUG: message content first 100 chars = {content[:100]}", flush=True)
            print(f"DEBUG: message content last 100 chars = {content[-100:]}", flush=True)
        sys.stdout.flush()
        
        # Return the response dict (FastAPI will serialize to JSON automatically)
        # Using model_dump() ensures proper serialization with all fields
        # FastAPI will set Content-Type: application/json automatically
        # Use model_dump(mode='json') to ensure proper JSON serialization
        return response.model_dump(mode='json')
    
    except Exception as e:
        print(f"DEBUG: Exception in chat_completions: {type(e).__name__}: {e}")
        import traceback
        print(f"DEBUG: Traceback:\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/conversations/{conversation_id}/message/stream")
async def send_message_stream(conversation_id: str, request: SendMessageRequest):
    """
    Send a message and stream the 3-stage council process.
    Returns Server-Sent Events as each stage completes.
    """
    # Check if conversation exists
    conversation = storage.get_conversation(conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")

    # Check if this is the first message
    is_first_message = len(conversation["messages"]) == 0

    async def event_generator():
        try:
            # Add user message
            storage.add_user_message(conversation_id, request.content)

            # Start title generation in parallel (don't await yet)
            title_task = None
            if is_first_message:
                title_task = asyncio.create_task(generate_conversation_title(request.content))

            # Stage 1: Collect responses
            yield f"data: {json.dumps({'type': 'stage1_start'})}\n\n"
            stage1_results = await stage1_collect_responses(request.content)
            yield f"data: {json.dumps({'type': 'stage1_complete', 'data': stage1_results})}\n\n"

            # Stage 2: Collect rankings
            yield f"data: {json.dumps({'type': 'stage2_start'})}\n\n"
            stage2_results, label_to_model = await stage2_collect_rankings(request.content, stage1_results)
            aggregate_rankings = calculate_aggregate_rankings(stage2_results, label_to_model)
            yield f"data: {json.dumps({'type': 'stage2_complete', 'data': stage2_results, 'metadata': {'label_to_model': label_to_model, 'aggregate_rankings': aggregate_rankings}})}\n\n"

            # Stage 3: Synthesize final answer
            yield f"data: {json.dumps({'type': 'stage3_start'})}\n\n"
            stage3_result = await stage3_synthesize_final(request.content, stage1_results, stage2_results)
            yield f"data: {json.dumps({'type': 'stage3_complete', 'data': stage3_result})}\n\n"

            # Wait for title generation if it was started
            if title_task:
                title = await title_task
                storage.update_conversation_title(conversation_id, title)
                yield f"data: {json.dumps({'type': 'title_complete', 'data': {'title': title}})}\n\n"

            # Save complete assistant message
            storage.add_assistant_message(
                conversation_id,
                stage1_results,
                stage2_results,
                stage3_result
            )

            # Send completion event
            yield f"data: {json.dumps({'type': 'complete'})}\n\n"

        except Exception as e:
            # Send error event
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
