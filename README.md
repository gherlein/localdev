# Isolated Development Container

A feature-rich containerized development environment for safely using Claude Code CLI and other AI assistants in "dangerous mode" for multi-language development.

## Purpose

This Podman/Docker container provides an isolated environment where Claude Code and other AI assistants can operate with elevated permissions (`--dangerously-skip-permissions`) without compromising your host system. The container includes a comprehensive development toolchain for modern software development.

## Features

### Core Environment
- **Base**: Eclipse Temurin 17 JDK
- **OS**: Ubuntu with essential development tools
- **Security**: Non-root user (developer) for best practices
- **Architecture Support**: AMD64 and ARM64

### Language Support

#### Go (v1.25.0)
- Full Go toolchain with proper GOPATH configuration
- Development tools: goimports, godoc, gofumpt, govulncheck
- Linters: golangci-lint, staticcheck
- Debugging: Delve (dlv)
- Code generation: wire, gomodifytags, impl, gotests
- Mock generation: mockgen

#### Node.js (Multiple Versions via NVM)
- Node.js 14.16.0
- Node.js 18.18.2
- Node.js LTS (default)
- Package managers: npm, pnpm
- TypeScript with ts-node
- Build tools: webpack, esbuild
- Testing: jest, vitest
- Code quality: eslint, prettier
- Development: nodemon, npm-check-updates

#### Python
- Python 3 with pip
- uv package manager
- md2pdf tool

#### Zig
- Zig 0.13.0 for systems programming

### AI Assistants
- **Claude Code CLI** (`@anthropic-ai/claude-code`)
  - Convenient alias: `clauded` (runs with `--dangerously-skip-permissions`)
  - Alternative alias: `copilotd` (runs with `--allow-all-tools`)
- **GitHub Copilot CLI** (`@github/copilot`)

### Development Tools
- **Version Control**: Git, GitHub CLI (gh)
- **Atlassian**: Atlassian CLI (acli)
- **Containerization**: Podman with rootless configuration
- **Documentation**: Marp CLI, mermaid-cli, md-to-pdf, pdf2md
- **Utilities**: jq, tree, curl, build-essential
- **Editors**: vim, nano
- **Search**: ripgrep
- **Multimedia**: ffmpeg, imagemagick, qpdf
- **Network**: libpcap-dev
- **Package Management**: Homebrew
- **Messaging**: NATS server and tools

## Prerequisites

This project uses Podman instead of Docker for license compatibility and rootless container support.

### Install Podman

```bash
# Ubuntu/Debian
sudo apt-get install podman

# Or use the Makefile
make pre
```

See [podman.io](https://podman.io/docs/installation) for other platforms.

## Building the Container

### Quick Build
```bash
make
```

This builds the container with:
- Tag: `localdev:latest`
- Memory limit: 16GB
- Automatic architecture detection (amd64/arm64)
- Pull latest base images

### Build from Scratch (No Cache)
```bash
make no-cache
```

### Manual Build
```bash
# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then TARGETARCH=amd64; else TARGETARCH=arm64; fi

# Build
podman build -t localdev:latest --memory=16g --build-arg TARGETARCH=$TARGETARCH --pull .
```

## Using the Container

### The `localdev` Script

The `localdev` script provides convenient access to the container with automatic directory mounting and support for read-only external directories.

#### Installation
```bash
# Copy to your bin directory
make install

# Or manually
cp localdev ~/bin/
chmod +x ~/bin/localdev
```

#### Basic Usage

```bash
# Run in current directory
./localdev

# Or if installed
localdev
```

This mounts your current working directory into the container at `/<directory-name>`.

#### Mounting External Directories

The script supports mounting additional directories as read-only inside the container at `/external/<directory-name>`.

##### Method 1: Command Line Arguments

```bash
# Mount single external directory
./localdev /path/to/external/repo

# Mount multiple external directories
./localdev /path/to/repo1 /path/to/repo2 /path/to/repo3
```

Example:
```bash
./localdev /home/user/reference-code /home/user/docs
```

This creates:
- `/myproject` → your current directory (read-write)
- `/external/reference-code` → `/home/user/reference-code` (read-only)
- `/external/docs` → `/home/user/docs` (read-only)

##### Method 2: Environment Variable

Set the `LOCALDEV_MOUNTS` environment variable with semicolon-separated paths:

```bash
# Single session
LOCALDEV_MOUNTS="/path/to/repo1;/path/to/repo2" ./localdev

# Persistent (add to ~/.bashrc or ~/.zshrc)
export LOCALDEV_MOUNTS="/home/user/reference-code;/home/user/docs"
./localdev
```

##### Combining Both Methods

You can use both command line arguments and the environment variable together:

```bash
export LOCALDEV_MOUNTS="/home/user/common-libs"
./localdev /home/user/project-specific-ref
```

##### Requirements for External Mounts
- Paths must be absolute (not relative)
- Directories must exist
- Invalid paths are skipped with warnings

### Manual Container Usage

#### Simple Run
```bash
# Using Makefile
make run

# Or manually
podman run --rm -it -v "$(pwd):/workspace" localdev:latest bash
```

#### Custom Mount Points
```bash
# Mount specific project directory
podman run --rm -it -v "/path/to/project:/workspace" localdev:latest bash

# Multiple mounts
podman run --rm -it \
  -v "$(pwd):/workspace" \
  -v "/path/to/libs:/libs:ro" \
  -v "$HOME/.config:/home/developer/.config:ro" \
  localdev:latest bash
```

## Inside the Container

### Using Claude Code

```bash
# With convenient alias (dangerous mode)
clauded

# Or full command
claude --dangerously-skip-permissions

# Alternative for copilot compatibility
copilotd
```

### Accessing External Mounts

If you mounted external directories using the `localdev` script:

```bash
# List external directories
ls -la /external/

# Access specific external directory
cd /external/reference-code
cat /external/docs/api-spec.md
```

### Node.js Version Management

```bash
# Switch Node.js versions
nvm use 14
nvm use 18
nvm use default  # LTS

# List installed versions
nvm list
```

### Development Workflow Example

```bash
# Start container with external reference code
./localdev /home/user/api-reference

# Inside container
cd /myproject

# Access external reference
cat /external/api-reference/examples/auth.go

# Use Claude to help with development
clauded

# Build and test
go build ./...
go test ./...
npm test
```

## Security Considerations

### Container Isolation
- **Filesystem**: Only mounted directories are accessible
- **Network**: Isolated container network
- **User**: Runs as non-root `developer` user (UID/GID 1000)
- **Cleanup**: Use `--rm` flag for automatic container removal

### Read-Only Mounts
External directories mounted by the `localdev` script are read-only, preventing accidental modifications to reference code or shared libraries.

### Host Protection
The container isolates AI assistants' file operations from your host system. Even in "dangerous mode," Claude can only affect files within mounted directories.

### Best Practices
1. Only mount directories you need
2. Use read-only mounts (`:ro`) for reference materials
3. Review changes before committing from host
4. Don't mount sensitive directories like `~/.ssh` unless necessary
5. Use version control for all work

## Architecture

### Directory Structure Inside Container

```
/
├── workspace/              # Default working directory
├── external/              # External read-only mounts (via localdev script)
│   ├── repo1/
│   ├── repo2/
│   └── ...
├── usr/local/go/          # Go installation
├── usr/local/nvm/         # Node.js version manager
├── usr/local/zig/         # Zig compiler
├── home/developer/        # Developer user home
│   ├── go/               # GOPATH
│   │   ├── bin/
│   │   ├── pkg/
│   │   └── src/
│   └── .local/bin/       # uv and tools
└── home/linuxbrew/        # Homebrew installation
```

### Environment Variables

The container sets up these key environment variables:

```bash
GOROOT=/usr/local/go
GOPATH=/home/developer/go
NVM_DIR=/usr/local/nvm
PATH includes:
  - /usr/local/go/bin
  - /home/developer/go/bin
  - /usr/local/nvm/versions/node/<version>/bin
  - /home/developer/.local/bin
  - /usr/local/zig
  - /home/linuxbrew/.linuxbrew/bin
```

## Troubleshooting

### Build Issues

**Out of Memory (OOM) errors during npm installs:**
- The Makefile sets `--memory=16g` to prevent this
- If you still encounter issues, increase available memory

**Architecture detection fails:**
- Manually set `TARGETARCH=amd64` or `TARGETARCH=arm64`

### Runtime Issues

**External mount not appearing:**
- Verify the path is absolute
- Check the directory exists on host
- Look for warning messages from the script

**Permission denied errors:**
- Ensure mounted directories have appropriate read permissions
- The container runs as UID/GID 1000

**Command not found inside container:**
- For npm packages: ensure nvm is loaded (`. $NVM_DIR/nvm.sh`)
- For Go tools: check `$GOPATH/bin` is in PATH
- The container's `.bashrc` should load these automatically

## Supported Use Cases

This container is ideal for:
- AI-assisted development with Claude Code or GitHub Copilot
- Multi-language projects (Go + TypeScript/Node.js)
- Safe experimentation with AI code generation
- Isolated build and test environments
- Documentation generation and processing
- Microservices development (with NATS support)
- Systems programming (Go, Zig)
- Cross-referencing multiple codebases safely

## License Considerations

This project uses Podman instead of Docker to avoid Docker Desktop licensing requirements for commercial use. Podman is fully open-source and compatible with Docker images and commands.

## Contributing

When modifying the container:
1. Test builds on both AMD64 and ARM64 if possible
2. Keep memory-intensive operations batched (see npm installs)
3. Update this README with new features
4. Maintain the security-first approach
