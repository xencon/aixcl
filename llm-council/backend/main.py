"""FastAPI backend for LLM Council."""

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import uuid
import json
import asyncio
import os
import time
import sys
import re
import logging

from . import storage
from . import db
from . import db_storage
from .conversation_tracker import generate_conversation_id
from .council import run_full_council, generate_conversation_title, stage1_collect_responses, stage2_collect_rankings, stage3_synthesize_final, calculate_aggregate_rankings
from .config import BACKEND_MODE, OLLAMA_BASE_URL, FORCE_STREAMING, ENABLE_MARKDOWN_FORMATTING, ENABLE_DB_STORAGE
from .config_manager import get_config, update_config, reload_config, validate_ollama_models

# Constants for list types used in markdown formatting
LIST_TYPE_BULLET = "bullet"
LIST_TYPE_NUMBERED = "numbered"


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
    # None, LIST_TYPE_BULLET, or LIST_TYPE_NUMBERED
    list_type = None
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
            if not in_list or list_type != LIST_TYPE_BULLET:
                # Start new list, ensure blank line before
                if formatted_lines and formatted_lines[-1].strip() and not formatted_lines[-1].startswith('-'):
                    formatted_lines.append('')
                in_list = True
                list_type = LIST_TYPE_BULLET
                list_counter = 1
            formatted_lines.append(f'- {content_text}')
        elif numbered_match:
            # Normalize numbered lists - preserve the number for better compatibility
            number = int(numbered_match.group(1))
            content_text = numbered_match.group(2)
            if not in_list or list_type != LIST_TYPE_NUMBERED:
                # Start new list, ensure blank line before
                if formatted_lines and formatted_lines[-1].strip() and not re.match(r'^\d+[.)]', formatted_lines[-1].strip()):
                    formatted_lines.append('')
                in_list = True
                list_type = LIST_TYPE_NUMBERED
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
print(f"DEBUG: OLLAMA_BASE_URL = {OLLAMA_BASE_URL}")
print(f"DEBUG: ENABLE_DB_STORAGE = {ENABLE_DB_STORAGE}")
print("DEBUG: Configuration will be loaded dynamically on startup")
print("=" * 60)

# Configure allowed CORS origins from environment or use safe defaults for local development
_allowed_origins_env = os.getenv("ALLOWED_ORIGINS", "").strip()
if _allowed_origins_env:
    ALLOWED_ORIGINS = [origin.strip() for origin in _allowed_origins_env.split(",") if origin.strip()]
else:
    # Default to common localhost origins (including common ports for VS Code/Continue plugin)
    # Adjust via ALLOWED_ORIGINS env var for production
    ALLOWED_ORIGINS = [
        "http://localhost",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
    ]
print(f"DEBUG: CORS ALLOWED_ORIGINS = {ALLOWED_ORIGINS}")

# Initialize database connection pool on startup
@app.on_event("startup")
async def startup_event():
    """Initialize database connection and config on startup."""
    if ENABLE_DB_STORAGE:
        await db.get_pool()
        print("DEBUG: Database connection pool initialized")
    
    # Initialize config manager (loads config from file or environment)
    config = await get_config()
    print(f"DEBUG: Configuration loaded: council_models={config['council_models']}, chairman={config['chairman_model']}")
    
    # Preload models to keep them warm in GPU memory
    if BACKEND_MODE == "ollama":
        from .ollama_adapter import preload_council_models
        await preload_council_models(config)

@app.on_event("shutdown")
async def shutdown_event():
    """Close database connection pool on shutdown."""
    await db.close_pool()
    print("DEBUG: Database connection pool closed")

# Enable CORS for local development
# Continue plugin may run from various origins; configure allowed origins via ALLOWED_ORIGINS
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global exception handler to catch all unhandled exceptions
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch all unhandled exceptions and return proper JSON response."""
    # Log full exception details server-side for debugging (includes stack trace)
    logging.error(f"Global exception handler caught: {type(exc).__name__}", exc_info=True)
    
    # If it's an HTTPException, let FastAPI handle it normally
    if isinstance(exc, HTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": {
                    "message": exc.detail,
                    "type": "http_exception",
                    "code": f"http_{exc.status_code}"
                }
            }
        )
    
    # For validation errors, return proper format
    if isinstance(exc, RequestValidationError):
        # Log validation error details server-side
        logging.warning("Request validation failed", exc_info=True)
        return JSONResponse(
            status_code=422,
            content={
                "error": {
                    "message": "Request validation failed",
                    "type": "validation_error",
                    "code": "invalid_request"
                }
            }
        )
    
    # For all other exceptions, return 500 with generic error message
    # Full error details are logged server-side above
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "message": "An internal error occurred",
                "type": "internal_error",
                "code": "server_error"
            }
        }
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


@app.get("/api/config")
async def get_council_config():
    """
    Get current council configuration.
    """
    config = await get_config()
    return {
        "council_models": config["council_models"],
        "chairman_model": config["chairman_model"],
        "backend_mode": config["backend_mode"],
        "ollama_base_url": config.get("ollama_base_url", OLLAMA_BASE_URL),
    }


class UpdateConfigRequest(BaseModel):
    """Request to update council configuration."""
    council_models: Optional[List[str]] = None
    chairman_model: Optional[str] = None


@app.put("/api/config")
async def update_council_config(request: UpdateConfigRequest):
    """
    Update council configuration dynamically.
    Changes take effect immediately for new requests.
    """
    try:
        # Validate models if provided
        if request.council_models:
            validation = await validate_ollama_models(request.council_models)
            unavailable = [model for model, available in validation.items() if not available]
            if unavailable:
                raise HTTPException(
                    status_code=400,
                    detail=f"Models not available in Ollama: {unavailable}"
                )
        
        if request.chairman_model:
            validation = await validate_ollama_models([request.chairman_model])
            if not validation.get(request.chairman_model, False):
                raise HTTPException(
                    status_code=400,
                    detail=f"Chairman model not available in Ollama: {request.chairman_model}"
                )
        
        # Update configuration
        updated_config = await update_config(
            council_models=request.council_models,
            chairman_model=request.chairman_model
        )
        
        return {
            "status": "success",
            "message": "Configuration updated successfully",
            "config": {
                "council_models": updated_config["council_models"],
                "chairman_model": updated_config["chairman_model"],
                "backend_mode": updated_config["backend_mode"],
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        # Log full exception details server-side for debugging
        logging.error("Failed to update configuration", exc_info=True)
        # Return generic error message to client
        raise HTTPException(status_code=500, detail="Failed to update configuration")


@app.post("/api/config/reload")
async def reload_council_config():
    """
    Reload configuration from file/environment.
    Useful after manual file edits or environment changes.
    """
    try:
        config = await reload_config()
        return {
            "status": "success",
            "message": "Configuration reloaded successfully",
            "config": {
                "council_models": config["council_models"],
                "chairman_model": config["chairman_model"],
                "backend_mode": config["backend_mode"],
            }
        }
    except Exception as e:
        # Log full exception details server-side for debugging
        logging.error("Failed to reload configuration", exc_info=True)
        # Return generic error message to client
        raise HTTPException(status_code=500, detail="Failed to reload configuration")


@app.get("/api/config/validate")
async def validate_models_endpoint(models: str):
    """
    Validate that models exist in Ollama.
    
    Query parameter: models (comma-separated list)
    """
    model_list = [m.strip() for m in models.split(",") if m.strip()]
    validation = await validate_ollama_models(model_list)
    return {
        "validation": validation,
        "all_available": all(validation.values())
    }


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
    Saves conversations to PostgreSQL if ENABLE_DB_STORAGE is enabled.
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
        
        # Convert messages to dict format for processing
        messages_dict = [{"role": msg.role, "content": msg.content} for msg in request.messages]
        
        # Handle conversation tracking and database storage
        conversation_id = None
        
        if ENABLE_DB_STORAGE:
            # Generate or find conversation ID
            conversation_id = generate_conversation_id(messages_dict)
            
            # Try to find existing conversation
            existing_conv = await db_storage.get_continue_conversation(conversation_id)
            
            if existing_conv is None:
                # Create new conversation
                first_user_msg = None
                for msg in messages_dict:
                    if msg.get("role") == "user":
                        first_user_msg = msg.get("content", "")
                        break
                
                if first_user_msg:
                    # Generate title from first message
                    title = first_user_msg[:50] + "..." if len(first_user_msg) > 50 else first_user_msg
                    created_conv = await db_storage.create_continue_conversation(conversation_id, first_user_msg, title)
                    if created_conv:
                        print(f"DEBUG: Created new conversation {conversation_id}", flush=True)
                    else:
                        logging.warning(f"Failed to create conversation {conversation_id} in database")
                        print(f"DEBUG: Failed to create conversation {conversation_id} in database", flush=True)
                else:
                    print(f"DEBUG: No user message found, skipping conversation creation", flush=True)
            else:
                print(f"DEBUG: Found existing conversation {conversation_id}", flush=True)
        
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
        
        # Save user message to database if enabled
        if ENABLE_DB_STORAGE and conversation_id:
            await db_storage.add_message_to_conversation(conversation_id, "user", user_query)
            print(f"DEBUG: Saved user message to conversation {conversation_id}", flush=True)
        
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
        start_time = time.time()
        stage1_results, stage2_results, stage3_result, metadata = await run_full_council(
            user_query
        )
        elapsed_time = time.time() - start_time
        print(f"DEBUG: run_full_council returned")
        print(f"DEBUG: stage1_results count = {len(stage1_results)}")
        print(f"DEBUG: stage2_results count = {len(stage2_results)}")
        print(f"DEBUG: stage3_result = {stage3_result}")
        print(f"DEBUG: Response time: {elapsed_time:.2f}s", flush=True)
        
        # Check if stage3_result is an error result
        if stage3_result.get('model') == 'error':
            error_message = stage3_result.get('response', 'An error occurred while processing your request.')
            print(f"DEBUG: Council returned error: {error_message}", flush=True)
            # Return OpenAI-compatible error response with both id and conversation_id
            response_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
            created_time = int(time.time())
            error_response = {
                "id": response_id,
                "created": created_time,
                "model": request.model,
                "error": {
                    "message": error_message,
                    "type": "internal_error",
                    "code": "council_error"
                }
            }
            # Include conversation_id in error response if available (for Continue plugin compatibility)
            if conversation_id:
                error_response["conversation_id"] = conversation_id
            return JSONResponse(
                status_code=500,
                content=error_response
            )
        
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
            # Return OpenAI-compatible error response for empty content
            return JSONResponse(
                status_code=500,
                content={
                    "error": {
                        "message": "The model returned an empty response. Please try again.",
                        "type": "invalid_response_error",
                        "code": "empty_response"
                    }
                }
            )
        else:
            # Format the content to ensure proper markdown rendering in Continue plugin
            if ENABLE_MARKDOWN_FORMATTING:
                original_length = len(final_content)
                final_content = format_markdown_response(final_content)
                print(f"DEBUG: Markdown formatting applied (length: {original_length} -> {len(final_content)})", flush=True)
                print(f"DEBUG: final_content preview (after formatting) = {final_content[:200]}", flush=True)
            else:
                print(f"DEBUG: Markdown formatting disabled, using original content", flush=True)
            
            # Remove any existing metadata lines added by chairman (they're in # format)
            # We'll replace them with italics format at the bottom
            lines = final_content.split('\n')
            cleaned_lines = []
            for line in lines:
                stripped = line.strip()
                # Skip lines that look like metadata comments from chairman
                if stripped.startswith('# Primary source:') or stripped.startswith('# Confidence:'):
                    continue
                cleaned_lines.append(line)
            
            final_content = '\n'.join(cleaned_lines).rstrip()
            
            # Add all metadata at the bottom in italics format
            primary_source = stage3_result.get('primary_source')
            top_ranked = stage3_result.get('top_ranked_model')
            model_name = primary_source or top_ranked or stage3_result.get('model', 'Unknown')
            confidence = stage3_result.get('confidence')
            
            metadata_parts = []
            metadata_parts.append(f"*Model: {model_name}*")
            metadata_parts.append(f"*Response time: {elapsed_time:.2f}s*")
            if confidence is not None:
                metadata_parts.append(f"*Confidence: {confidence}%*")
            
            metadata_footer = "\n\n" + " | ".join(metadata_parts)
            final_content = final_content + metadata_footer
        
        # Save assistant response to database BEFORE deciding on streaming
        # This ensures it's saved regardless of streaming mode
        if ENABLE_DB_STORAGE and conversation_id:
            try:
                print(f"DEBUG: [SAVE] About to save assistant message to conversation {conversation_id}", flush=True)
                print(f"DEBUG: [SAVE] ENABLE_DB_STORAGE={ENABLE_DB_STORAGE}, conversation_id={conversation_id}", flush=True)
                print(f"DEBUG: [SAVE] final_content length={len(final_content)}", flush=True)
                stage_data = {
                    "stage1": stage1_results,
                    "stage2": stage2_results,
                    "stage3": stage3_result,
                }
                save_result = await db_storage.add_message_to_conversation(
                    conversation_id,
                    "assistant",
                    final_content,
                    stage_data
                )
                if save_result:
                    print(f"DEBUG: [SAVE] ✅ Successfully saved assistant message to conversation {conversation_id}", flush=True)
                else:
                    print(f"DEBUG: [SAVE] ❌ add_message_to_conversation returned False for conversation {conversation_id}", flush=True)
            except Exception as save_error:
                # Log full exception details server-side (includes stack trace)
                logging.error(f"[SAVE] Exception saving assistant message: {save_error}", exc_info=True)
        else:
            print(f"DEBUG: [SAVE] ⚠️ Skipping save - ENABLE_DB_STORAGE={ENABLE_DB_STORAGE}, conversation_id={conversation_id}", flush=True)
        
        # Handle streaming if requested or forced
        should_stream = request.stream or FORCE_STREAMING
        if should_stream:
            if FORCE_STREAMING and not request.stream:
                print("DEBUG: FORCE_STREAMING enabled, converting to streaming response", flush=True)
            print("DEBUG: Streaming response requested", flush=True)
            
            async def generate_stream():
                response_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
                created_time = int(time.time())
                try:
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
                except Exception as stream_error:
                    # Log full error details server-side, including stack trace
                    logging.error("Error in streaming response", exc_info=True)
                    # Send sanitized error in OpenAI streaming format (no internal details)
                    error_chunk = {
                        "id": response_id,
                        "object": "chat.completion.chunk",
                        "created": created_time,
                        "model": request.model,
                        "choices": [{
                            "index": 0,
                            "delta": {},
                            "finish_reason": None
                        }],
                        "error": {
                            "message": "An internal streaming error occurred.",
                            "type": "internal_error",
                            "code": "stream_error"
                        }
                    }
                    yield f"data: {json.dumps(error_chunk)}\n\n"
                    yield "data: [DONE]\n\n"
                    print("DEBUG: Error in stream (details logged server-side)", flush=True)
            
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
        
        # Save assistant response to database if enabled
        if ENABLE_DB_STORAGE and conversation_id:
            stage_data = {
                "stage1": stage1_results,
                "stage2": stage2_results,
                "stage3": stage3_result,
            }
            await db_storage.add_message_to_conversation(
                conversation_id,
                "assistant",
                final_content,
                stage_data
            )
            print(f"DEBUG: Saved assistant message to conversation {conversation_id}", flush=True)
        
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
    
    except HTTPException:
        # Re-raise HTTPExceptions as-is (they're already properly formatted)
        raise
    except Exception as e:
        # Log full exception details server-side for debugging (includes stack trace)
        logging.error(f"Exception in chat_completions: {type(e).__name__}: {e}", exc_info=True)
        # Return OpenAI-compatible error response with sanitized message
        # Full error details are logged server-side above
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "message": "An error occurred while processing your request",
                    "type": "internal_error",
                    "code": "server_error"
                }
            }
        )


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
            # Log the exception with traceback
            logging.exception("Exception in send_message_stream.event_generator")
            # Send generic error event to user
            yield f"data: {json.dumps({'type': 'error', 'message': 'An internal error has occurred.'})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )


@app.delete("/v1/chat/completions/{conversation_id}")
async def delete_conversation(conversation_id: str):
    """
    Delete a Continue conversation from PostgreSQL.
    
    Args:
        conversation_id: Conversation identifier
        
    Returns:
        Success message or error
    """
    if not ENABLE_DB_STORAGE:
        raise HTTPException(status_code=503, detail="Database storage is disabled")
    
    # Verify conversation exists and belongs to Continue
    conversation = await db_storage.get_continue_conversation(conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    # Delete conversation
    success = await db_storage.delete_conversation(conversation_id)
    
    if success:
        return {"status": "success", "message": f"Conversation {conversation_id} deleted"}
    else:
        raise HTTPException(status_code=500, detail="Failed to delete conversation")


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
