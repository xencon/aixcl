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
# Read from individual environment variables: COUNCILLOR-01, COUNCILLOR-02, etc.
# For Ollama mode: use Ollama model names (e.g., "qwen2.5-coder:7b")
# For OpenRouter mode: use OpenRouter identifiers (e.g., "openai/gpt-5.1")
COUNCIL_MODELS = []
# Support up to 4 council members (COUNCILLOR-01 through COUNCILLOR-04) for a total of 5 models (1 chairman + 4 councillors)
for i in range(1, 5):
    councillor_var = f"COUNCILLOR-{i:02d}"
    model = os.getenv(councillor_var)
    if model and model.strip():
        COUNCIL_MODELS.append(model.strip())

# Fallback to legacy COUNCIL_MODELS format for backward compatibility
if not COUNCIL_MODELS:
    council_models_str = os.getenv("COUNCIL_MODELS")
    if council_models_str:
        COUNCIL_MODELS = [m.strip() for m in council_models_str.split(",") if m.strip()]

print(f"DEBUG: COUNCIL_MODELS = {COUNCIL_MODELS}")

# Chairman model - synthesizes final response
# Read from CHAIRMAN environment variable
CHAIRMAN_MODEL = os.getenv("CHAIRMAN")

# Fallback to legacy CHAIRMAN_MODEL for backward compatibility
if not CHAIRMAN_MODEL:
    CHAIRMAN_MODEL = os.getenv("CHAIRMAN_MODEL")

print(f"DEBUG: CHAIRMAN_MODEL = {CHAIRMAN_MODEL}")
print(f"DEBUG: OLLAMA_BASE_URL = {os.getenv('OLLAMA_BASE_URL', 'http://localhost:11434')}")

# OpenRouter API endpoint
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"

# Data directory for conversation storage
DATA_DIR = os.getenv("DATA_DIR", "data/conversations")

# Force streaming mode (if True, always return streaming responses even if client doesn't request it)
# This can be useful if clients like Continue plugin work better with streaming
FORCE_STREAMING = os.getenv("FORCE_STREAMING", "false").lower() == "true"
print(f"DEBUG: FORCE_STREAMING = {FORCE_STREAMING}")

# Enable markdown formatting (if True, formats responses for better rendering in Continue plugin)
# Formats bullet points, numbered lists, and ensures proper markdown structure
ENABLE_MARKDOWN_FORMATTING = os.getenv("ENABLE_MARKDOWN_FORMATTING", "true").lower() == "true"
print(f"DEBUG: ENABLE_MARKDOWN_FORMATTING = {ENABLE_MARKDOWN_FORMATTING}")

# PostgreSQL configuration for conversation storage
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "localhost")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_USER = os.getenv("POSTGRES_USER", "admin")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "")
POSTGRES_DATABASE = os.getenv("POSTGRES_DATABASE", "admin")

# Continue plugin database (separate from admin/Open WebUI database)
# This ensures continue conversations are stored in their own database
POSTGRES_CONTINUE_DATABASE = os.getenv("POSTGRES_CONTINUE_DATABASE", "continue")

# Enable database storage for Continue conversations
ENABLE_DB_STORAGE = os.getenv("ENABLE_DB_STORAGE", "true").lower() == "true"
print(f"DEBUG: ENABLE_DB_STORAGE = {ENABLE_DB_STORAGE}")
print(f"DEBUG: POSTGRES_HOST = {POSTGRES_HOST}, POSTGRES_DATABASE = {POSTGRES_DATABASE}")
print(f"DEBUG: POSTGRES_CONTINUE_DATABASE = {POSTGRES_CONTINUE_DATABASE}")
