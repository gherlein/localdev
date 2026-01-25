# localdev - Lightweight development container (DEFAULT)
# Optimized for fast startup - no Java, no Atlassian CLI
# For full container with Java and Atlassian CLI, see Dockerfile.full
FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    git \
    unzip \
    build-essential \
    cmake \
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
    tree \
    mg \
    rsync \
    ca-certificates && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS only using nvm
ENV NVM_DIR=/usr/local/nvm

RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install --lts && \
    nvm alias default node && \
    nvm use default

# Add nvm to PATH - source nvm in subsequent RUN commands
ENV NODE_PATH="$NVM_DIR/versions/node"
SHELL ["/bin/bash", "-c"]

# Set PATH to include the default Node.js version installed by nvm
# Also create a symlink for consistent path across node version updates
RUN . $NVM_DIR/nvm.sh && \
    ln -s "$NVM_DIR/versions/node/$(nvm version default)" "$NVM_DIR/default" && \
    echo "export PATH=\"$NVM_DIR/default/bin:\$PATH\"" >> /etc/environment

# Add node to PATH at container level (required for scripts like clauded)
ENV PATH="$NVM_DIR/default/bin:${PATH}"

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
RUN (groupadd -g 1000 developer 2>/dev/null || groupmod -n developer $(getent group 1000 | cut -d: -f1)) && \
    (useradd -m -u 1000 -g 1000 -s /bin/bash developer 2>/dev/null || \
    usermod -l developer -d /home/developer -m $(getent passwd 1000 | cut -d: -f1) 2>/dev/null || true) && \
    echo 'developer ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Fix permissions for developer user
RUN mkdir -p /home/developer/go/{bin,src,pkg} && \
    chown -R 1000:1000 /home/developer

# Install essential npm tools only (Claude Code installed later as developer user)
RUN . $NVM_DIR/nvm.sh && \
    NODE_OPTIONS="--max-old-space-size=4096" npm install -g \
    typescript \
    ts-node \
    pnpm \
    eslint \
    prettier && \
    npm cache clean --force

# Setup lazy-load nvm in bash for all users (loads on first use)
RUN echo 'export NVM_DIR=/usr/local/nvm' >> /etc/bash.bashrc && \
    echo '# Lazy-load nvm for faster shell startup' >> /etc/bash.bashrc && \
    echo 'nvm() { unset -f nvm node npm npx; . "$NVM_DIR/nvm.sh"; nvm "$@"; }' >> /etc/bash.bashrc && \
    echo 'node() { unset -f nvm node npm npx; . "$NVM_DIR/nvm.sh"; node "$@"; }' >> /etc/bash.bashrc && \
    echo 'npm() { unset -f nvm node npm npx; . "$NVM_DIR/nvm.sh"; npm "$@"; }' >> /etc/bash.bashrc && \
    echo 'npx() { unset -f nvm node npm npx; . "$NVM_DIR/nvm.sh"; npx "$@"; }' >> /etc/bash.bashrc && \
    echo '# Add default node to PATH for non-interactive use' >> /etc/bash.bashrc && \
    echo 'export PATH="$NVM_DIR/versions/node/$(cat $NVM_DIR/alias/default 2>/dev/null || echo "v22")/bin:$PATH" 2>/dev/null || true' >> /etc/bash.bashrc && \
    echo '# Add user npm global binaries to PATH' >> /etc/bash.bashrc && \
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> /etc/bash.bashrc && \
    echo '# Alias emacs to mg' >> /etc/bash.bashrc && \
    echo 'alias emacs=mg' >> /etc/bash.bashrc

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

# Update PATH to include user-local npm binaries
ENV PATH="/home/developer/.npm-global/bin:${PATH}"

# Install Claude Code as developer user (enables auto-updates)
# Configure npm prefix and install in the same command to avoid nvm conflicts
RUN . $NVM_DIR/nvm.sh && \
    mkdir -p "$HOME/.npm-global" && \
    npm config set prefix "$HOME/.npm-global" && \
    npm install -g @anthropic-ai/claude-code

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
    mkdir -p "$HOME/.local/bin" && \
    echo '#!/bin/bash' > "$HOME/.local/bin/clauded" && \
    echo "exec ${CLAUDE_BIN}.real --dangerously-skip-permissions --add-dir /claude \"\$@\"" >> "$HOME/.local/bin/clauded" && \
    chmod +x "$HOME/.local/bin/clauded"

# install uv with retry logic
RUN for i in 1 2 3; do \
    curl -LsSf https://astral.sh/uv/install.sh | sh && break || \
    (echo "Attempt $i failed, retrying..." && sleep 5); \
    done

# Add uv to PATH
ENV PATH="/home/developer/.local/bin:${PATH}"

# Install essential Go tools only
RUN go install golang.org/x/tools/cmd/goimports@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
    go install github.com/go-delve/delve/cmd/dlv@latest

CMD ["/bin/bash"]
