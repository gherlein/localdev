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
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Install Go (latest stable)
ARG GO_VERSION=1.23.4
RUN curl -fsSL https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/developer/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Install Node.js using n (Node version manager) directly - latest version
RUN curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o /usr/local/bin/n \
    && chmod +x /usr/local/bin/n \
    && N_PREFIX=/usr/local n latest

# Install pnpm and webpack tools globally
RUN npm install -g pnpm typescript ts-node webpack webpack-cli html-webpack-plugin

# Create non-root user for development
RUN useradd -m -s /bin/bash developer \
    && mkdir -p /home/developer/go/bin \
    && mkdir -p /home/developer/.npm-global \
    && chown -R developer:developer /home/developer

RUN apt-get update && \
    (apt-get install -y emacs-nox || apt-get install -y emacs) && \
    rm -rf /var/lib/apt/lists/*

# Set npm global directory for the developer user
ENV NPM_CONFIG_PREFIX=/home/developer/.npm-global
ENV PATH="/home/developer/.npm-global/bin:${PATH}"

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER developer

# Install Claude CLI as developer user
RUN npm install -g @anthropic-ai/claude-code

# Create shell alias for convenient dangerous Claude execution
RUN echo 'alias clauded="claude --dangerously-skip-permissions"' >> /home/developer/.bashrc

# Set default shell
CMD ["/bin/bash"]
