FROM eclipse-temurin:17-jdk

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    build-essential \
    libpcap-dev && rm -rf /var/lib/apt/lists/*

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
ARG GO_VERSION=1.22.5
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
    "amd64") GOARCH=amd64 ;; \
    "arm64") GOARCH=arm64 ;; \
    *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL https://dl.google.com/go/go${GO_VERSION}.linux-${GOARCH}.tar.gz | tar -xzC /usr/local

# Set Go environment variables
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/developer/go
ENV PATH="${GOROOT}/bin:${GOPATH}/bin:${PATH}"

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user for development
RUN useradd -m -s /bin/bash developer && \
    mkdir -p /home/developer/.npm-global && \
    mkdir -p /home/developer/go/{bin,src,pkg} && \
    chown -R developer:developer /home/developer

# Create shell alias for convenient dangerous Claude execution for all users
RUN echo 'alias clauded="claude --dangerously-skip-permissions"' >> /etc/bash.bashrc && \
    echo 'alias clauded="claude --dangerously-skip-permissions"' >> /home/developer/.bashrc

# Set npm global directory for the developer user
ENV NPM_CONFIG_PREFIX=/home/developer/.npm-global
ENV PATH="/home/developer/.npm-global/bin:${PATH}"

WORKDIR /workspace

# Switch to non-root user
USER developer

# Install Go development tools and linters
RUN go install golang.org/x/tools/cmd/goimports@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
    go install honnef.co/go/tools/cmd/staticcheck@latest && \
    go install github.com/go-delve/delve/cmd/dlv@latest && \
    go install golang.org/x/tools/cmd/godoc@latest && \
    go install github.com/fatih/gomodifytags@latest && \
    go install github.com/josharian/impl@latest && \
    go install github.com/cweill/gotests/gotests@latest && \
    go install mvdan.cc/gofumpt@latest && \
    go install github.com/segmentio/golines@latest && \
    go install github.com/google/wire/cmd/wire@latest && \
    go install github.com/golang/mock/mockgen@latest && \
    go install golang.org/x/vuln/cmd/govulncheck@latest

CMD ["/bin/bash"]
