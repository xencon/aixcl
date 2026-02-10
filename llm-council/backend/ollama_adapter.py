"""Ollama API adapter for Council to work with local Ollama instances."""

import httpx
from typing import List, Dict, Any, Optional
import os
import logging
from .config import MODEL_TIMEOUT

logger = logging.getLogger(__name__)

# Get OLLAMA_BASE_URL from environment (set by docker-compose or .env)
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

logger.debug(f"ollama_adapter loaded, OLLAMA_BASE_URL = {OLLAMA_BASE_URL}")


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
    logger.debug("query_model called for model=%s, OLLAMA_BASE_URL=%s", model, OLLAMA_BASE_URL)
    logger.debug("messages count = %d", len(messages))
    
    # Ollama uses OpenAI-compatible chat completions API
    payload = {
        "model": model,
        "messages": messages,
        "stream": False
    }

    try:
        url = f"{OLLAMA_BASE_URL}/api/chat"
        logger.debug("POST %s", url)
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                url,
                json=payload
            )
            logger.debug("response status = %d", response.status_code)
            response.raise_for_status()

            data = response.json()
            
            content = data.get('message', {}).get('content', '')
            prompt_eval_count = data.get('prompt_eval_count', 0)
            eval_count = data.get('eval_count', 0)
            logger.debug("extracted content length = %d, prompt_tokens = %d, completion_tokens = %d",
                         len(content), prompt_eval_count, eval_count)
            
            return {
                'content': content,
                'reasoning_details': None,
                'prompt_tokens': prompt_eval_count,
                'completion_tokens': eval_count,
            }

    except Exception as e:
        logger.error("Error querying Ollama model %s: %s", model, e, exc_info=True)
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

    logger.debug("query_models_parallel called with %d models: %s", len(models), models)
    start_time = time.time()

    # Create tasks for all models (truly parallel execution)
    tasks = [query_model(model, messages) for model in models]
    logger.debug("Created %d parallel tasks", len(tasks))

    # Wait for all to complete (parallel execution)
    responses = await asyncio.gather(*tasks)
    
    elapsed = time.time() - start_time
    logger.debug("Parallel queries completed in %.2fs for %d models", elapsed, len(models))

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
    logger.debug("Preloading model: %s", model)
    
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
            logger.info("Successfully preloaded model: %s", model)
            return True
    except Exception as e:
        logger.warning("Failed to preload model %s: %s", model, e)
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
        logger.debug("No models to preload")
        return
    
    logger.info("Preloading %d models: %s", len(all_models), all_models)
    
    # Preload all models in parallel
    import asyncio
    tasks = [preload_model(model) for model in all_models]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    successful = sum(1 for r in results if r is True)
    logger.info("Preloaded %d/%d models successfully", successful, len(all_models))

