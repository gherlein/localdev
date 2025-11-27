FROM docker.io/eclipse-temurin:17-jdk

# Install dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    git \
    unzip \
    build-essential \
    squashfs-tools \
    zip \
    file \
    xxd \
    ffmpeg \
    qpdf \
    imagemagick \
    libpcap-dev \
    jq \
    gosu \
    python3 \
    python3-pip \
    tree && rm -rf /var/lib/apt/lists/*

# Install Node.js using nvm to support multiple versions
ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION_14=14.16.0
ENV NODE_VERSION_18=18.18.2
ENV NODE_VERSION_LTS=lts/*

RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION_14 && \
    nvm install $NODE_VERSION_18 && \
    nvm install $NODE_VERSION_LTS && \
    nvm alias default $NODE_VERSION_LTS && \
    nvm use default

# Add nvm to PATH - source nvm in subsequent RUN commands
ENV NODE_PATH="$NVM_DIR/versions/node"
SHELL ["/bin/bash", "-c"]

# Set PATH to include the default Node.js version installed by nvm
RUN . $NVM_DIR/nvm.sh && \
    echo "export PATH=\"$NVM_DIR/versions/node/$(nvm version default)/bin:\$PATH\"" >> /etc/environment

# Install Podman
RUN apt-get update && apt-get install -y \
    podman \
    uidmap \
    fuse-overlayfs \
    slirp4netns && \
    rm -rf /var/lib/apt/lists/*

# Configure Podman for rootless operation
RUN mkdir -p /etc/containers && \
    echo '[containers]' > /etc/containers/containers.conf && \
    echo 'netns="host"' >> /etc/containers/containers.conf && \
    echo 'userns="host"' >> /etc/containers/containers.conf && \
    echo 'ipcns="host"' >> /etc/containers/containers.conf && \
    echo 'utsns="host"' >> /etc/containers/containers.conf && \
    echo 'cgroupns="host"' >> /etc/containers/containers.conf && \
    echo 'cgroups="disabled"' >> /etc/containers/containers.conf && \
    echo 'devices="/dev/null"' >> /etc/containers/containers.conf && \
    echo '[engine]' >> /etc/containers/containers.conf && \
    echo 'cgroup_manager="cgroupfs"' >> /etc/containers/containers.conf && \
    echo 'events_logger="file"' >> /etc/containers/containers.conf && \
    echo 'runtime="crun"' >> /etc/containers/containers.conf

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install Atlassian CLI using the official APT repository
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://acli.atlassian.com/gpg/public-key.asc | gpg --dearmor -o /etc/apt/keyrings/acli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/acli-archive-keyring.gpg] https://acli.atlassian.com/linux/deb stable main" | tee /etc/apt/sources.list.d/acli.list > /dev/null && \
    apt-get update && \
    apt-get install -y acli && \
    rm -rf /var/lib/apt/lists/*

# Install Go
ARG GO_VERSION=1.25.0
ARG TARGETARCH
RUN echo "TARGETARCH: ${TARGETARCH}"
RUN case "${TARGETARCH}" in \
    "amd64") GOARCH=amd64 ;; \
    "arm64") GOARCH=arm64 ;; \
    *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL https://dl.google.com/go/go${GO_VERSION}.linux-${GOARCH}.tar.gz | tar --no-same-permissions --no-same-owner -xzC /usr/local

# Set Go environment variables
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/developer/go
ENV PATH="${GOROOT}/bin:${GOPATH}/bin:${PATH}"

# Create a new user with UID/GID 1000 to match host user
# Handle case where GID 1000 already exists
RUN (groupadd -g 1000 developer 2>/dev/null || groupmod -n developer $(getent group 1000 | cut -d: -f1)) && \
    (useradd -m -u 1000 -g 1000 -s /bin/bash developer 2>/dev/null || \
    usermod -l developer -d /home/developer -m $(getent passwd 1000 | cut -d: -f1) 2>/dev/null || true) && \
    echo 'developer ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Fix permissions for developer user
# Note: npm global packages are managed by nvm, not in .npm-global
RUN mkdir -p /home/developer/go/{bin,src,pkg} && \
    chown -R 1000:1000 /home/developer

# Install npm tools in small batches to avoid OOM (exit 137)
# Batch 1: Essential tools
RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=8192" npm install -g \
    @anthropic-ai/claude-code \
    typescript \
    ts-node && \
    npm cache clean --force

# Batch 2: Build tools
RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=8192" npm install -g \
    webpack \
    webpack-cli \
    webpack-dev-server \
    esbuild && \
    npm cache clean --force

# Batch 3: Development tools
RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=8192" npm install -g \
    nodemon \
    npm-check-updates \
    pnpm && \
    npm cache clean --force

# Batch 4: Code quality tools
RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=8192" npm install -g \
    eslint \
    prettier && \
    npm cache clean --force

# Batch 5: Testing tools (split to avoid OOM)
RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=4096" npm install -g \
    jest && \
    npm cache clean --force

RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=4096" npm install -g \
    vitest && \
    npm cache clean --force

# Batch 6: PDF and other tools
RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=8192" npm install -g \
    md-to-pdf \
    pdf2md \
    @github/copilot && \
    npm cache clean --force

# Install Homebrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

# install Marp CLI
RUN brew install marp-cli

# Install memory-heavy mermaid-cli separately with increased memory limit
# and retry logic in case of OOM
RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=4096" npm install -g @mermaid-js/mermaid-cli || \
    (echo "First attempt failed, cleaning cache and retrying..." && \
    npm cache clean --force && \
    NODE_OPTIONS="--max-old-space-size=4096" npm install -g @mermaid-js/mermaid-cli) || \
    echo "Warning: Failed to install mermaid-cli (requires more memory)"

# Setup nvm in bash for all users
RUN echo 'export NVM_DIR=/usr/local/nvm' >> /etc/bash.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /etc/bash.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"' >> /etc/bash.bashrc

# Create wrapper scripts for claude commands that automatically add /claude directory
RUN . $NVM_DIR/nvm.sh && \
    CLAUDE_BIN=$(which claude) && \
    mv "$CLAUDE_BIN" "${CLAUDE_BIN}.real" && \
    echo '#!/bin/bash' > "$CLAUDE_BIN" && \
    echo "exec ${CLAUDE_BIN}.real --add-dir /claude \"\$@\"" >> "$CLAUDE_BIN" && \
    chmod +x "$CLAUDE_BIN"

# Create clauded wrapper that includes both --dangerously-skip-permissions and --add-dir /claude
RUN . $NVM_DIR/nvm.sh && \
    CLAUDE_BIN=$(which claude) && \
    echo '#!/bin/bash' > /usr/local/bin/clauded && \
    echo "exec ${CLAUDE_BIN}.real --dangerously-skip-permissions --add-dir /claude \"\$@\"" >> /usr/local/bin/clauded && \
    chmod +x /usr/local/bin/clauded

# Repeat for copilot
RUN echo 'alias copilotd="claude --allow-all-tools"' >> /etc/bash.bashrc

# Note: NPM_CONFIG_PREFIX is NOT set because we use nvm to manage npm
# nvm already configures PATH correctly for npm global packages
# Global npm packages installed via nvm are in: $NVM_DIR/versions/node/<version>/bin

WORKDIR /workspace

# Install udev and USB libraries for device access
RUN apt-get update && apt-get install -y \
    udev \
    libusb-1.0-0 \
    libusb-1.0-0-dev \
    usbutils \
    && rm -rf /var/lib/apt/lists/*

# Switch to developer user
USER developer

# install uv with retry logic
RUN for i in 1 2 3; do \
    curl -LsSf https://astral.sh/uv/install.sh | sh && break || \
    (echo "Attempt $i failed, retrying..." && sleep 5); \
    done

# Add uv to PATH
ENV PATH="/home/developer/.local/bin:${PATH}"

# Install md2pdf
RUN /home/developer/.local/bin/uv tool install md2pdf

# Install Go development tools and linters (split into groups for better reliability)
RUN go install golang.org/x/tools/cmd/goimports@latest && \
    go install golang.org/x/tools/cmd/godoc@latest && \
    go install mvdan.cc/gofumpt@latest && \
    go install golang.org/x/vuln/cmd/govulncheck@latest

RUN go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
    go install honnef.co/go/tools/cmd/staticcheck@latest && \
    go install github.com/go-delve/delve/cmd/dlv@latest

RUN go install github.com/fatih/gomodifytags@latest && \
    go install github.com/josharian/impl@latest && \
    go install github.com/cweill/gotests/gotests@latest && \
    go install github.com/google/wire/cmd/wire@latest

# Install remaining tools (skip problematic ones if they fail)
RUN go install github.com/segmentio/golines@latest || echo "Warning: Failed to install golines" && \
    go install github.com/golang/mock/mockgen@latest || echo "Warning: Failed to install mockgen"

CMD ["/bin/bash"]
