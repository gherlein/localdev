FROM ubuntu:22.04

# Prevent interactive prompts during installation
ARG DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    software-properties-common \
    nano \
    vim \
    tree \
    jq \
    ripgrep \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Go (latest stable)
ARG GO_VERSION=1.21.5
RUN curl -fsSL https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/developer/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install pnpm globally
RUN npm install -g pnpm typescript ts-node

# Create non-root user for development
RUN useradd -m -s /bin/bash developer \
    && mkdir -p /home/developer/go/bin \
    && chown -R developer:developer /home/developer

# Install Claude CLI
RUN curl -fsSL https://claude.ai/install.sh | bash

# Set working directory
WORKDIR /workspace
USER developer

# Create shell alias for convenient dangerous Claude execution
RUN echo 'alias clauded="claude --dangerously-skip-permissions"' >> /home/developer/.bashrc

# Set default shell
CMD ["/bin/bash"]