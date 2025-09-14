#!/bin/bash

# Run container with proper user mapping
docker run -it --rm \
  -v "$(pwd):/workspace" \
  -e HOST_UID=$(id -u) \
  -e HOST_GID=$(id -g) \
  -w /workspace \
  localdev:latest \
  bash