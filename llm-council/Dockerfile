# LLM-Council Dockerfile for AIXCL Platform
# Based on https://github.com/karpathy/llm-council
FROM python:3.11.14-slim

# Install system dependencies with pinned versions where possible
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Python package manager) - pinned to specific version
RUN pip install --no-cache-dir uv==0.6.0

# Set working directory
WORKDIR /app

# Copy project files
COPY . /app

# Install Python dependencies using uv
RUN uv sync

# Expose API port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start the FastAPI backend server
CMD ["uv", "run", "python", "-m", "backend.main"]

