"""Ollama API adapter for LLM Council to work with local Ollama instances."""

import httpx
from typing import List, Dict, Any, Optional
import os
from .config import MODEL_TIMEOUT

# Get OLLAMA_BASE_URL from environment (set by docker-compose or .env)
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

print(f"DEBUG: ollama_adapter loaded, OLLAMA_BASE_URL = {OLLAMA_BASE_URL}")


async def query_model(
    model: str,
    messages: List[Dict[str, str]],
    timeout: Optional[float] = None
) -> Optional[Dict[str, Any]]:
    if timeout is None:
        timeout = MODEL_TIMEOUT
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
    import time

    print(f"DEBUG: query_models_parallel called with {len(models)} models: {models}", flush=True)
    start_time = time.time()

    # Create tasks for all models (truly parallel execution)
    tasks = [query_model(model, messages) for model in models]
    print(f"DEBUG: Created {len(tasks)} parallel tasks", flush=True)

    # Wait for all to complete (parallel execution)
    responses = await asyncio.gather(*tasks)
    
    elapsed = time.time() - start_time
    print(f"DEBUG: Parallel queries completed in {elapsed:.2f}s for {len(models)} models", flush=True)

    # Map models to their responses
    return {model: response for model, response in zip(models, responses)}


async def preload_model(model: str, timeout: Optional[float] = 30.0) -> bool:
    """
    Preload a model by sending a minimal query to keep it warm in GPU memory.
    
    Args:
        model: Ollama model name
        timeout: Request timeout in seconds
        
    Returns:
        True if preload successful, False otherwise
    """
    print(f"DEBUG: Preloading model: {model}", flush=True)
    
    try:
        # Send a minimal query to load the model
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": "OK"}],
            "stream": False
        }
        
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                f"{OLLAMA_BASE_URL}/api/chat",
                json=payload
            )
            response.raise_for_status()
            print(f"DEBUG: Successfully preloaded model: {model}", flush=True)
            return True
    except Exception as e:
        print(f"DEBUG: Failed to preload model {model}: {type(e).__name__}: {e}", flush=True)
        return False


async def preload_council_models(config: Dict[str, Any]) -> None:
    """
    Preload all council models and chairman to keep them warm in GPU memory.
    
    Args:
        config: Configuration dict with council_models and chairman_model
    """
    from .config import BACKEND_MODE
    
    if BACKEND_MODE != "ollama":
        return
    
    council_models = config.get('council_models', [])
    chairman_model = config.get('chairman_model')
    
    all_models = council_models.copy()
    if chairman_model:
        all_models.append(chairman_model)
    
    if not all_models:
        print("DEBUG: No models to preload", flush=True)
        return
    
    print(f"DEBUG: Preloading {len(all_models)} models: {all_models}", flush=True)
    
    # Preload all models in parallel
    import asyncio
    tasks = [preload_model(model) for model in all_models]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    successful = sum(1 for r in results if r is True)
    print(f"DEBUG: Preloaded {successful}/{len(all_models)} models successfully", flush=True)

