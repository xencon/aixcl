# LLM-Council Dockerfile for AIXCL Platform
# Based on https://github.com/karpathy/llm-council
FROM python:3.11.14-slim

# Set environment variables to suppress warnings during package installation
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=dumb

# Install system dependencies with pinned versions where possible
# Suppress harmless update-alternatives man page warnings while preserving real errors
RUN bash -c 'apt-get update && \
    apt-get install -y \
        git \
        curl \
        build-essential \
    2>&1 | grep -v "update-alternatives: warning: skip creation"; \
    exit ${PIPESTATUS[0]}' && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip to latest version and install uv (Python package manager) - pinned to specific version
# Suppress root user warning with --root-user-action=ignore
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --root-user-action=ignore uv==0.6.0

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

