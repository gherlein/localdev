# Isolated Development Container

A containerized development environment for safely using Claude Code CLI in "dangerous mode" for Go and TypeScript/Node.js development.

## Purpose

This Docker container provides an isolated environment where Claude Code can operate with elevated permissions (`--dangerously-skip-permissions`) without compromising your host system. It's designed for:

- Go development (v1.21.5)
- TypeScript/Node.js development (Node.js 20.x)
- Safe execution of Claude's file system operations
- Development workflows requiring broader file access

## Features

- **Ubuntu 22.04** base with essential development tools
- **Go 1.21.5** with proper GOPATH configuration
- **Node.js 20.x** with pnpm and TypeScript support
- **Claude CLI** pre-installed with convenient alias
- **Development tools**: git, ripgrep, jq, vim, nano, tree
- **Non-root user** for security best practices

## Usage

### Build the Container
```bash
docker build -t claude-dangerous-dev .
```

You can also 'make build' instead.

### Run with Local Project Mount
```bash
# Mount your current project directory
docker run -it --rm -v $(pwd):/workspace localdev bash

# Or mount a specific project directory
docker run -it --rm -v /path/to/your/project:/workspace localdev bash
```

### Using Claude in Dangerous Mode
Once inside the container:
```bash
# Use the convenient alias
clauded

# Or run directly
claude --dangerously-skip-permissions
```

## Security Considerations

- **Isolation**: The container isolates Claude's operations from your host system
- **Limited Scope**: Only your mounted project directory is accessible
- **Non-root**: Development happens as the `developer` user
- **Temporary**: Use `--rm` flag to automatically clean up containers

## Development Workflow

1. Mount your Go or TypeScript project into `/workspace`
2. Use `clauded` to start Claude with dangerous permissions
3. Claude can freely read/write within the mounted project directory
4. Exit and remove container when done

## Supported Languages

- **Go**: Full toolchain with modules support
- **TypeScript/JavaScript**: Node.js runtime with pnpm package manager
- **General**: Git, build tools, and common utilities

This approach enables powerful Claude Code assistance while maintaining security through containerization.
