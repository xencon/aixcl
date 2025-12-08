"""Configuration for the LLM Council."""

import os
from dotenv import load_dotenv

load_dotenv()

# Backend mode: "ollama" or "openrouter"
BACKEND_MODE = os.getenv("BACKEND_MODE", "ollama")
print(f"DEBUG: config.py loaded, BACKEND_MODE = {BACKEND_MODE}")

# OpenRouter API key (only needed if BACKEND_MODE is "openrouter")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

# Ollama base URL (only needed if BACKEND_MODE is "ollama")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

# Council members - model identifiers
# For Ollama mode: use Ollama model names (e.g., "qwen2.5-coder:7b")
# For OpenRouter mode: use OpenRouter identifiers (e.g., "openai/gpt-5.1")
if BACKEND_MODE == "ollama":
    council_models_str = os.getenv("COUNCIL_MODELS", "qwen2.5-coder:7b,granite-code:3b")
    COUNCIL_MODELS = [m.strip() for m in council_models_str.split(",") if m.strip()]
else:
    COUNCIL_MODELS = [
        "openai/gpt-5.1",
        "google/gemini-3-pro-preview",
        "anthropic/claude-sonnet-4.5",
        "x-ai/grok-4",
    ]

print(f"DEBUG: COUNCIL_MODELS = {COUNCIL_MODELS}")

# Chairman model - synthesizes final response
CHAIRMAN_MODEL = os.getenv("CHAIRMAN_MODEL", "gemma3:4b" if BACKEND_MODE == "ollama" else "google/gemini-3-pro-preview")
print(f"DEBUG: CHAIRMAN_MODEL = {CHAIRMAN_MODEL}")
print(f"DEBUG: OLLAMA_BASE_URL = {os.getenv('OLLAMA_BASE_URL', 'http://localhost:11434')}")

# OpenRouter API endpoint
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"

# Data directory for conversation storage
DATA_DIR = os.getenv("DATA_DIR", "data/conversations")
