#!/bin/bash

# Script to run Claude Code in Docker with browser support

echo "Building Claude Code Docker image..."
docker-compose build

echo ""
echo "Starting Claude Code container..."
echo "Note: Browser commands will be network-restricted"
echo ""

# Create workspace directory if it doesn't exist
mkdir -p workspace

# Run the container
docker-compose run --rm claude-dev