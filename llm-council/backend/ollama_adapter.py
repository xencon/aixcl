"""Ollama API adapter for LLM Council to work with local Ollama instances."""

import httpx
from typing import List, Dict, Any, Optional
import os


OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")


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
    # Ollama uses OpenAI-compatible chat completions API
    payload = {
        "model": model,
        "messages": messages,
        "stream": False
    }

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                f"{OLLAMA_BASE_URL}/api/chat",
                json=payload
            )
            response.raise_for_status()

            data = response.json()
            
            return {
                'content': data.get('message', {}).get('content', ''),
                'reasoning_details': None
            }

    except Exception as e:
        print(f"Error querying Ollama model {model}: {e}")
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

