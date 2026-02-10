"""Configuration for the Council."""

import os
import logging
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

# Backend mode: "ollama" or "openrouter"
BACKEND_MODE = os.getenv("BACKEND_MODE", "ollama")
logger.debug(f"config.py loaded, BACKEND_MODE = {BACKEND_MODE}")

# OpenRouter API key (only needed if BACKEND_MODE is "openrouter")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

# Ollama base URL (only needed if BACKEND_MODE is "ollama")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

# Council members - model identifiers
# Read from COUNCIL_MODELS environment variable (comma-separated list)
# For Ollama mode: use Ollama model names (e.g., "qwen2.5-coder:7b")
# For OpenRouter mode: use OpenRouter identifiers (e.g., "openai/gpt-5.1")
COUNCIL_MODELS = []
council_models_str = os.getenv("COUNCIL_MODELS")
if council_models_str:
    COUNCIL_MODELS = [m.strip() for m in council_models_str.split(",") if m.strip()]

logger.debug(f"COUNCIL_MODELS = {COUNCIL_MODELS}")

# Chairman model - synthesizes final response
# Read from CHAIRMAN_MODEL environment variable
CHAIRMAN_MODEL = os.getenv("CHAIRMAN_MODEL")

logger.debug(f"CHAIRMAN_MODEL = {CHAIRMAN_MODEL}")
logger.debug(f"OLLAMA_BASE_URL = {os.getenv('OLLAMA_BASE_URL', 'http://localhost:11434')}")

# OpenRouter API endpoint
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"

# Data directory for conversation storage
DATA_DIR = os.getenv("DATA_DIR", "data/conversations")

# Force streaming mode (if True, always return streaming responses even if client doesn't request it)
# This can be useful if clients like Continue plugin work better with streaming
FORCE_STREAMING = os.getenv("FORCE_STREAMING", "false").lower() == "true"
logger.debug(f"FORCE_STREAMING = {FORCE_STREAMING}")

# Enable markdown formatting (if True, formats responses for better rendering in Continue plugin)
# Formats bullet points, numbered lists, and ensures proper markdown structure
ENABLE_MARKDOWN_FORMATTING = os.getenv("ENABLE_MARKDOWN_FORMATTING", "true").lower() == "true"
logger.debug(f"ENABLE_MARKDOWN_FORMATTING = {ENABLE_MARKDOWN_FORMATTING}")

# PostgreSQL configuration for conversation storage
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "localhost")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_USER = os.getenv("POSTGRES_USER", "admin")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "")
POSTGRES_DATABASE = os.getenv("POSTGRES_DATABASE", "webui")

# Continue plugin database (separate from webui/Open WebUI database)
# This ensures continue conversations are stored in their own database
POSTGRES_CONTINUE_DATABASE = os.getenv("POSTGRES_CONTINUE_DATABASE", "continue")

# Enable database storage for Continue conversations
ENABLE_DB_STORAGE = os.getenv("ENABLE_DB_STORAGE", "true").lower() == "true"
logger.debug(f"ENABLE_DB_STORAGE = {ENABLE_DB_STORAGE}")
logger.debug(f"POSTGRES_HOST = {POSTGRES_HOST}, POSTGRES_DATABASE = {POSTGRES_DATABASE}")
logger.debug(f"POSTGRES_CONTINUE_DATABASE = {POSTGRES_CONTINUE_DATABASE}")

# Model query timeout (seconds) - reduced from 120s to 60s for faster responses
MODEL_TIMEOUT = float(os.getenv("MODEL_TIMEOUT", "60.0"))
logger.debug(f"MODEL_TIMEOUT = {MODEL_TIMEOUT}")
