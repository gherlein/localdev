#!/bin/bash
set -e

echo "🛠️ Installing NATS Server and CLI tools..."

# NATS Server Installation
echo "📦 Installing NATS Server v2.10.5..."
if command -v nats-server >/dev/null 2>&1; then
    echo "✅ nats-server already installed: $(nats-server --version)"
else
    echo "⬇️ Downloading NATS Server..."
    NATS_VERSION="v2.10.5"
    ARCH="amd64"
    NATS_URL="https://github.com/nats-io/nats-server/releases/download/${NATS_VERSION}/nats-server-${NATS_VERSION}-linux-${ARCH}.tar.gz"

    # Create local bin directory
    mkdir -p ~/.local/bin

    # Download and extract
    curl -fsSL "${NATS_URL}" | tar -xz -C /tmp

    # Move binary to local bin
    mv "/tmp/nats-server-${NATS_VERSION}-linux-${ARCH}/nats-server" ~/.local/bin/

    # Make executable
    chmod +x ~/.local/bin/nats-server

    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi

    echo "✅ NATS Server installed to ~/.local/bin/nats-server"
fi

# NATS CLI Installation
echo "🖥️ Installing NATS CLI (latest)..."
if command -v nats >/dev/null 2>&1; then
    echo "✅ nats CLI already installed: $(nats --version 2>/dev/null || echo 'version unknown')"
else
    echo "⬇️ Installing NATS CLI via go install..."
    go install github.com/nats-io/natscli/nats@latest
    echo "✅ NATS CLI installed to $(go env GOPATH)/bin/nats"
fi

echo ""
echo "🎉 NATS installation complete!"
echo ""
echo "Available tools:"
echo "  • nats-server - Core NATS messaging server"
echo "  • nats        - Official command-line interface"
echo ""
echo "Quick start:"
echo "  nats-server                    # Start NATS server"
echo "  nats pub subject 'Hello NATS' # Publish a message"
echo "  nats sub subject               # Subscribe to messages"
echo ""