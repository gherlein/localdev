# Exposing the `.claude/` Directory in the Container

## Overview

The `localdev` container system makes your global Claude configuration available inside isolated containers through a two-part mechanism: volume mounting and command wrapping.

## Current Execution Context

**Note**: This documentation was written while running directly on the host macOS system at `/Users/gherlein`, not inside the container. The container system described below is what runs when you execute the `localdev` or `localfull` scripts.

## How It Works

### 1. Volume Mount in the Launch Script

The `localdev` script (`localdev:117-128`) contains explicit logic to mount your home `.claude/` directory:

```bash
# Handle .claude directory mount
CLAUDE_MOUNT=()
if [[ -d "$HOME/.claude" ]]; then
  if [[ -r "$HOME/.claude" ]]; then
    CLAUDE_MOUNT=("-v" "$HOME/.claude:/claude:rw")
    echo "Mounting: $HOME/.claude -> /claude (read-write)" >&2
  else
    echo "Warning: $HOME/.claude exists but is not readable, skipping mount" >&2
  fi
else
  echo "Info: $HOME/.claude does not exist, skipping mount" >&2
fi
```

This creates a Podman volume mount mapping:
- **Host path**: `$HOME/.claude` (typically `/Users/gherlein/.claude`)
- **Container path**: `/claude`
- **Permissions**: Read-write (`rw`)

### 2. Automatic Integration with Claude CLI

The Dockerfile (`Dockerfile:168-175`) wraps the `claude` command to automatically include the global configuration directory:

```bash
CLAUDE_BIN=$(which claude)
mv "$CLAUDE_BIN" "${CLAUDE_BIN}.real"
echo '#!/bin/bash' > "$CLAUDE_BIN"
echo "exec ${CLAUDE_BIN}.real --add-dir /claude \"\$@\"" >> "$CLAUDE_BIN"
chmod +x "$CLAUDE_BIN"
```

**What this does**:
1. Renames the actual `claude` binary to `claude.real`
2. Creates a wrapper script at the original `claude` location
3. The wrapper automatically adds `--add-dir /claude` to every invocation
4. Passes through all other arguments unchanged

### 3. Additional Convenience Aliases

The Dockerfile also creates a `clauded` alias (`Dockerfile:173-175`):

```bash
echo '#!/bin/bash' > "$HOME/.local/bin/clauded"
echo "exec ${CLAUDE_BIN}.real --dangerously-skip-permissions --add-dir /claude \"\$@\"" >> "$HOME/.local/bin/clauded"
chmod +x "$HOME/.local/bin/clauded"
```

This provides:
- `claude` → includes `--add-dir /claude` (safe mode)
- `clauded` → includes `--dangerously-skip-permissions --add-dir /claude` (dangerous mode)

## Container Filesystem Layout

When running inside the container, the structure looks like:

```
/
├── <project-name>/         # Your current directory (read-write)
│                          # Example: /localdev if launched from localdev directory
├── /claude/                # Host ~/.claude directory (read-write)
│   ├── CLAUDE.md          # Global Claude instructions
│   ├── settings.json      # Claude settings
│   ├── instructions/      # Your instruction files
│   │   ├── code-analysis.md
│   │   ├── code-style.md
│   │   ├── tests.md
│   │   ├── conversation.md
│   │   ├── git-commits.md
│   │   └── full-stack-guide.md
│   └── commands/          # Custom slash commands (if any)
└── /external/             # Additional read-only mounts
    ├── repo1/
    ├── repo2/
    └── ...
```

## Bidirectional Synchronization

Because the mount uses `rw` (read-write) permissions:
- Changes made to `/claude` inside the container persist to `~/.claude` on the host
- Changes made to `~/.claude` on the host are immediately visible at `/claude` in the container
- This enables maintaining a single source of truth for global Claude configuration

## Permission Handling

The script performs safety checks before mounting:

1. **Existence check**: Verifies `$HOME/.claude` directory exists
2. **Readability check**: Ensures the directory has read permissions
3. **Graceful degradation**: Skips the mount with an info message if directory doesn't exist
4. **Error reporting**: Warns if directory exists but lacks read permissions

## Usage Examples

### Inside the Container

```bash
# Standard invocation (automatically includes --add-dir /claude)
claude

# Dangerous mode alias (includes --dangerously-skip-permissions --add-dir /claude)
clauded

# Your global CLAUDE.md is available
cat /claude/CLAUDE.md
cat /claude/instructions/code-style.md

# Any changes to /claude persist to the host
echo "New instruction" >> /claude/CLAUDE.md
```

### On the Host

```bash
# Launch container (automatically mounts ~/.claude to /claude)
./localdev

# View mount confirmation message
# Output: "Mounting: /Users/gherlein/.claude -> /claude (read-write)"
```

## Key Benefits

1. **Single configuration source**: Maintain one set of Claude instructions for all projects
2. **Automatic availability**: No manual flags needed when invoking Claude
3. **Persistence**: Configuration changes survive container restarts
4. **Isolation**: Project-specific configuration can still live in project directories
5. **Security**: Container isolation protects host system while allowing controlled access

## Error Scenarios

| Scenario | Behavior |
|----------|----------|
| `~/.claude` doesn't exist | Mount skipped, info message displayed |
| `~/.claude` exists but not readable | Mount skipped, warning displayed |
| `/claude` accessed but not mounted | Error - directory won't exist in container |
| Permission denied on mount | Warning displayed, mount count incremented |

## Implementation Details

The mount is added to the Podman run command (`localdev:161-173`):

```bash
podman run -it --rm \
  --userns=keep-id \
  "${USB_DEVICE_FLAG[@]}" \
  "${DEVICE_MOUNTS[@]}" \
  "${GROUP_ADD_FLAG[@]}" \
  -v "$(pwd):/${DIR_NAME}" \
  "${CLAUDE_MOUNT[@]}" \              # ← Global .claude mount
  "${VOLUME_MOUNTS[@]}" \
  -e HOST_UID=$(id -u) \
  -e HOST_GID=$(id -g) \
  -w "/${DIR_NAME}" \
  localdev:latest \
  bash
```

The `${CLAUDE_MOUNT[@]}` array expansion inserts the volume mount flag if the directory exists and is readable.

## Related Documentation

- See `README.md` for general container usage
- See `localdev` script for complete mounting logic
- See `Dockerfile` for Claude CLI wrapper implementation
