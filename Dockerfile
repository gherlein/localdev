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
    gosu && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for Claude Code)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

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
RUN mkdir -p /home/developer/.npm-global && \
    mkdir -p /home/developer/go/{bin,src,pkg} && \
    chown -R 1000:1000 /home/developer

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Create shell alias for convenient dangerous Claude execution for all users
RUN echo 'alias clauded="claude --dangerously-skip-permissions"' >> /etc/bash.bashrc

# Set npm global directory for the developer user
ENV NPM_CONFIG_PREFIX=/home/developer/.npm-global
ENV PATH="/home/developer/.npm-global/bin:${PATH}"

WORKDIR /workspace

# Switch to developer user
USER developer

# Install zig
RUN curl -fsSL https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz -o zig.tar.xz && \
    tar -xf zig.tar.xz && \
    sudo mv zig-linux-x86_64-0.13.0 /usr/local/zig && \
    rm zig.tar.xz

# Add Zig to PATH
ENV PATH="/usr/local/zig:${PATH}"


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
