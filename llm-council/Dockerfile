# Council Dockerfile for AIXCL Platform
# Based on https://github.com/karpathy/llm-council
FROM python:3.11.14-slim

# Install system dependencies with pinned versions where possible
# Filter out harmless warnings (debconf frontend attempts and update-alternatives man pages)
# while preserving real errors
RUN bash -c 'apt-get update && \
    apt-get install -y \
        git \
        curl \
        build-essential \
    2>&1 | grep -vE "(debconf: (unable to initialize frontend|falling back to frontend)|update-alternatives: warning: skip creation)"; \
    exit ${PIPESTATUS[0]}' && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip to latest version and install uv (Python package manager) - pinned to specific version
# Note: Running pip as root during build is acceptable; we switch to non-root user at runtime
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --root-user-action=ignore uv==0.6.0

# Set working directory
WORKDIR /app

# Copy project files
COPY . /app

# Create a non-root user for runtime security
# Create home directory and cache directory for uv
# Do this before installing dependencies so venv is owned by appuser
RUN groupadd -r appuser && \
    useradd -r -g appuser -m -d /home/appuser appuser && \
    mkdir -p /home/appuser/.cache/uv && \
    chown -R appuser:appuser /app /home/appuser

# Install Python dependencies using uv as appuser
# This ensures .venv is created with correct ownership
USER appuser
RUN uv sync

# Expose API port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Switch to non-root user for runtime
USER appuser

# Start the FastAPI backend server
CMD ["uv", "run", "python", "-m", "backend.main"]

