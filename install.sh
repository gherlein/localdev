#!/bin/bash
# Quick installer for localdev launcher scripts
# Usage: curl -fsSL https://raw.githubusercontent.com/gherlein/localdev/main/install.sh | bash

set -e

REPO_URL="https://raw.githubusercontent.com/gherlein/localdev/main"
INSTALL_DIR="${HOME}/bin"
SCRIPTS=("localdev" "localdevnet" "localfull")

echo "Installing localdev launcher scripts to ${INSTALL_DIR}..."

# Create install directory if it doesn't exist
mkdir -p "${INSTALL_DIR}"

# Download each script
for script in "${SCRIPTS[@]}"; do
    echo "Downloading ${script}..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${REPO_URL}/${script}" -o "${INSTALL_DIR}/${script}"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "${REPO_URL}/${script}" -O "${INSTALL_DIR}/${script}"
    else
        echo "Error: Neither curl nor wget found. Please install one and try again."
        exit 1
    fi
    chmod +x "${INSTALL_DIR}/${script}"
    echo "  ✓ Installed ${INSTALL_DIR}/${script}"
done

echo ""
echo "Installation complete!"
echo ""
echo "Launcher scripts installed to ${INSTALL_DIR}/"
echo ""

# Check if ~/bin is in PATH
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo "⚠️  Note: ${INSTALL_DIR} is not in your PATH"
    echo ""
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\${HOME}/bin:\${PATH}\""
    echo ""
fi

echo "Pull the container images:"
echo "  podman pull ghcr.io/gherlein/localdev:latest"
echo "  podman pull ghcr.io/gherlein/localfull:latest  # optional"
echo ""
echo "Then run:"
echo "  localdev"
echo ""
