"""Ollama API adapter for LLM Council to work with local Ollama instances."""

import httpx
from typing import List, Dict, Any, Optional
import os

# Get OLLAMA_BASE_URL from environment (set by docker-compose or .env)
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

print(f"DEBUG: ollama_adapter loaded, OLLAMA_BASE_URL = {OLLAMA_BASE_URL}")


async def query_model(
    model: str,
    messages: List[Dict[str, str]],
    timeout: float = 120.0
) -> Optional[Dict[str, Any]]:
    """
    Query a single model via Ollama API.

    Args:
        model: Ollama model name (e.g., "qwen2.5-coder:7b")
        messages: List of message dicts with 'role' and 'content'
        timeout: Request timeout in seconds

    Returns:
        Response dict with 'content', or None if failed
    """
    print(f"DEBUG: query_model called for model={model}, OLLAMA_BASE_URL={OLLAMA_BASE_URL}", flush=True)
    print(f"DEBUG: messages count = {len(messages)}", flush=True)
    
    # Ollama uses OpenAI-compatible chat completions API
    payload = {
        "model": model,
        "messages": messages,
        "stream": False
    }
    print(f"DEBUG: payload = {payload}")

    try:
        url = f"{OLLAMA_BASE_URL}/api/chat"
        print(f"DEBUG: POST {url}")
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                url,
                json=payload
            )
            print(f"DEBUG: response status = {response.status_code}")
            response.raise_for_status()

            data = response.json()
            print(f"DEBUG: response data keys = {list(data.keys())}")
            print(f"DEBUG: response data message keys = {list(data.get('message', {}).keys())}")
            
            content = data.get('message', {}).get('content', '')
            print(f"DEBUG: extracted content length = {len(content)}")
            print(f"DEBUG: content preview = {content[:200]}")
            
            return {
                'content': content,
                'reasoning_details': None
            }

    except Exception as e:
        print(f"DEBUG: Error querying Ollama model {model}: {type(e).__name__}: {e}")
        import traceback
        print(f"DEBUG: Traceback:\n{traceback.format_exc()}")
        return None


async def query_models_parallel(
    models: List[str],
    messages: List[Dict[str, str]]
) -> Dict[str, Optional[Dict[str, Any]]]:
    """
    Query multiple Ollama models in parallel.

    Args:
        models: List of Ollama model names
        messages: List of message dicts to send to each model

    Returns:
        Dict mapping model name to response dict (or None if failed)
    """
    import asyncio

    # Create tasks for all models
    tasks = [query_model(model, messages) for model in models]

    # Wait for all to complete
    responses = await asyncio.gather(*tasks)

    # Map models to their responses
    return {model: response for model, response in zip(models, responses)}

