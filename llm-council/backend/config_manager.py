"""Dynamic configuration manager for LLM Council."""

import os
import json
import asyncio
from typing import List, Dict, Any, Optional
from pathlib import Path
import httpx
from .config import BACKEND_MODE, OLLAMA_BASE_URL

# Configuration file path
CONFIG_FILE = Path(os.getenv("CONFIG_FILE", "/app/data/council_config.json"))

# In-memory configuration cache
_config_cache: Optional[Dict[str, Any]] = None
_config_lock = asyncio.Lock()


def _load_default_config() -> Dict[str, Any]:
    """Load default configuration from environment variables."""
    # Read council models from COUNCIL_MODELS environment variable (comma-separated list)
    council_models = []
    council_models_str = os.getenv("COUNCIL_MODELS")
    if council_models_str:
        council_models = [m.strip() for m in council_models_str.split(",") if m.strip()]
    
    # Read chairman model from CHAIRMAN_MODEL environment variable
    chairman_model = os.getenv("CHAIRMAN_MODEL")
    
    return {
        "council_models": council_models,
        "chairman_model": chairman_model,
        "backend_mode": BACKEND_MODE,
        "ollama_base_url": OLLAMA_BASE_URL,
    }


def _load_config_from_file() -> Optional[Dict[str, Any]]:
    """Load configuration from JSON file if it exists."""
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            print(f"WARNING: Failed to load config from file: {e}")
    return None


def _save_config_to_file(config: Dict[str, Any]) -> bool:
    """Save configuration to JSON file."""
    try:
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        return True
    except IOError as e:
        print(f"ERROR: Failed to save config to file: {e}")
        return False


async def get_config() -> Dict[str, Any]:
    """
    Get current configuration (thread-safe).
    Environment variables are the source of truth. File is only used if it matches
    environment (indicating it was updated via API). Otherwise, environment takes precedence.
    """
    global _config_cache
    
    async with _config_lock:
        if _config_cache is None:
            # Always load from environment first (source of truth)
            env_config = _load_default_config()
            
            # Check if file exists
            file_config = _load_config_from_file()
            if file_config:
                # Compare critical config values
                file_models = set(file_config.get("council_models", []))
                env_models = set(env_config.get("council_models", []))
                file_chairman = file_config.get("chairman_model", "")
                env_chairman = env_config.get("chairman_model", "")
                
                # If environment values differ from file, environment takes precedence
                if file_models != env_models or file_chairman != env_chairman:
                    print(f"DEBUG: Environment config differs from file config")
                    print(f"DEBUG:   File models: {file_config.get('council_models')}")
                    print(f"DEBUG:   Env models: {env_config.get('council_models')}")
                    print(f"DEBUG:   File chairman: {file_config.get('chairman_model')}")
                    print(f"DEBUG:   Env chairman: {env_config.get('chairman_model')}")
                    print(f"DEBUG: Using environment config (source of truth)")
                    _config_cache = env_config
                    # Update file to match environment
                    _save_config_to_file(_config_cache)
                else:
                    # File matches environment, use file (may have additional API-updated fields)
                    _config_cache = file_config
                    print(f"DEBUG: Loaded config from file (matches environment): {_config_cache}")
            else:
                # No file exists, use environment and save to file
                _config_cache = env_config
                print(f"DEBUG: Loaded config from environment: {_config_cache}")
                _save_config_to_file(_config_cache)
        
        return _config_cache.copy()


async def update_config(
    council_models: Optional[List[str]] = None,
    chairman_model: Optional[str] = None
) -> Dict[str, Any]:
    """
    Update configuration dynamically.
    
    Args:
        council_models: New list of council model names
        chairman_model: New chairman model name
        
    Returns:
        Updated configuration
    """
    global _config_cache
    
    async with _config_lock:
        current_config = await get_config()
        
        if council_models is not None:
            current_config["council_models"] = council_models
        
        if chairman_model is not None:
            current_config["chairman_model"] = chairman_model
        
        _config_cache = current_config
        _save_config_to_file(_config_cache)
        
        print(f"DEBUG: Updated config: {_config_cache}")
        return _config_cache.copy()


async def reload_config() -> Dict[str, Any]:
    """
    Reload configuration from file/environment.
    Forces a refresh of the cache.
    """
    global _config_cache
    
    async with _config_lock:
        _config_cache = None
        return await get_config()


async def validate_ollama_models(models: List[str]) -> Dict[str, bool]:
    """
    Validate that models exist in Ollama.
    
    Args:
        models: List of model names to validate
        
    Returns:
        Dictionary mapping model names to availability status
    """
    if BACKEND_MODE != "ollama":
        # For non-Ollama backends, assume models are valid
        return {model: True for model in models}
    
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            response.raise_for_status()
            data = response.json()
            
            available_models = {model["name"] for model in data.get("models", [])}
            
            # Check each requested model
            validation = {}
            for model in models:
                # Check exact match or if model name starts with any available model
                is_available = model in available_models or any(
                    available.startswith(model.split(":")[0]) 
                    for available in available_models
                )
                validation[model] = is_available
            
            return validation
    except Exception as e:
        print(f"WARNING: Failed to validate models with Ollama: {e}")
        # On error, assume models are valid (optimistic)
        return {model: True for model in models}


async def get_council_models() -> List[str]:
    """Get current council models."""
    config = await get_config()
    return config["council_models"]


async def get_chairman_model() -> str:
    """Get current chairman model."""
    config = await get_config()
    return config["chairman_model"]

