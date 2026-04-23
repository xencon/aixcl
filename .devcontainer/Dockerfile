FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    bash-completion \
    git \
    jq \
    vim \
    nano \
    htop \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Install Docker (for Docker-in-Docker support)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install NVIDIA Container Toolkit prerequisites
RUN distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
    && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
    && apt-get update \
    && apt-get install -y nvidia-container-toolkit \
    && rm -rf /var/lib/apt/lists/*

# Install Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install huggingface-hub CLI for model downloads
RUN pip3 install --no-cache-dir huggingface-hub[cli]

# Install shellcheck for script linting
RUN apt-get update && apt-get install -y shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Install nvidia-smi wrapper for GPU monitoring
RUN echo '#!/bin/bash\nif [ -x /usr/bin/nvidia-smi ]; then\n    /usr/bin/nvidia-smi "$@"\nelse\n    echo "NVIDIA tools not available in this environment"\n    exit 1\nfi' > /usr/local/bin/nvidia-smi-check \
    && chmod +x /usr/local/bin/nvidia-smi-check

# Create vscode user directories
RUN mkdir -p /home/vscode/.ollama /home/vscode/.cache/huggingface /models \
    && chown -R vscode:vscode /home/vscode/.ollama /home/vscode/.cache /models

# Set up environment variables
ENV PATH="/usr/local/bin:${PATH}"
ENV OLLAMA_HOST=127.0.0.1:11434
ENV HUGGINGFACE_HUB_CACHE=/home/vscode/.cache/huggingface

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

# Set working directory
WORKDIR /workspace

# Use the non-root user
USER vscode

# Pre-configure git
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase false

# Install Oh My Zsh plugins (optional but useful)
RUN if [ -d "$HOME/.oh-my-zsh" ]; then \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true; \
    fi

# Switch back to root for entrypoint
USER root

# Custom entrypoint to ensure docker daemon is available
COPY .devcontainer/scripts/entrypoint.sh /usr/local/bin/devcontainer-entrypoint
RUN chmod +x /usr/local/bin/devcontainer-entrypoint

ENTRYPOINT ["/usr/local/bin/devcontainer-entrypoint"]
CMD ["sleep", "infinity"]
