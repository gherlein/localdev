# Exposing the `.claude/` Directory in the Container

## Overview

The `localdev` container system makes your global Claude configuration available inside isolated containers by mounting the host's `~/.claude` directory to the container's native `~/.claude` path (`/home/developer/.claude`). Claude Code reads from `~/.claude` by default, so no special flags or wrappers are needed.

## How It Works

### 1. Auto-Create and Volume Mount in the Launch Script

The `localdev` script contains logic to ensure the directory exists and mount it:

```bash
# Handle .claude directory mount (native location for Claude Code global config)
mkdir -p "$HOME/.claude" 2>/dev/null || true
CLAUDE_MOUNT=()
if [[ -d "$HOME/.claude" ]]; then
  if [[ -r "$HOME/.claude" ]]; then
    CLAUDE_MOUNT=("-v" "$HOME/.claude:/home/developer/.claude:rw")
    echo "Mounting: $HOME/.claude -> /home/developer/.claude (read-write)" >&2
  else
    echo "Warning: $HOME/.claude exists but is not readable, skipping mount" >&2
  fi
else
  echo "Info: $HOME/.claude could not be created, skipping mount" >&2
fi
```

Key behaviors:
- **Auto-create**: `mkdir -p` ensures the directory exists on the host, even for first-time users
- **Host path**: `$HOME/.claude` (e.g. `/Users/gherlein/.claude` or `/home/user/.claude`)
- **Container path**: `/home/developer/.claude` (which is `~/.claude` for the `developer` user)
- **Permissions**: Read-write (`rw`)

### 2. Native Discovery by Claude Code

Claude Code natively reads its global configuration from `~/.claude`. Since the mount places the host directory at the container's `~/.claude` path, Claude Code finds it automatically — no `--add-dir` flags or wrapper scripts are needed.

The Dockerfile creates simple pass-through wrappers:

```bash
# claude wrapper
exec npx -y @anthropic-ai/claude-code@latest "$@"

# clauded wrapper (dangerous mode)
exec npx -y @anthropic-ai/claude-code@latest --dangerously-skip-permissions "$@"
```

### 3. Convenience Aliases

The container provides these commands:
- `claude` → Standard Claude Code invocation
- `clauded` → Runs with `--dangerously-skip-permissions`
- `copilotd` → Runs with `--allow-all-tools`

## Container Filesystem Layout

When running inside the container, the structure looks like:

```
/
├── <project-name>/              # Your current directory (read-write)
│                                # Example: /localdev if launched from localdev directory
├── home/developer/
│   └── .claude/                 # Host ~/.claude directory (read-write, native path)
│       ├── CLAUDE.md            # Global Claude instructions
│       ├── settings.json        # Claude settings
│       ├── instructions/        # Your instruction files
│       │   ├── code-analysis.md
│       │   ├── code-style.md
│       │   └── ...
│       └── commands/            # Custom slash commands (if any)
└── /external/                   # Additional read-only mounts
    ├── repo1/
    ├── repo2/
    └── ...
```

## Bidirectional Synchronization

Because the mount uses `rw` (read-write) permissions:
- Changes made to `~/.claude` inside the container persist to `~/.claude` on the host
- Changes made to `~/.claude` on the host are immediately visible at `~/.claude` in the container
- This enables maintaining a single source of truth for global Claude configuration

## Permission Handling

The script performs safety checks before mounting:

1. **Auto-create**: Creates `~/.claude` on the host if it doesn't exist
2. **Existence check**: Verifies the directory was created/exists
3. **Readability check**: Ensures the directory has read permissions
4. **Graceful degradation**: Skips the mount with a message if directory can't be created
5. **Error reporting**: Warns if directory exists but lacks read permissions

## Usage Examples

### Inside the Container

```bash
# Standard invocation (finds ~/.claude config natively)
claude

# Dangerous mode alias
clauded

# Your global CLAUDE.md is available at the native path
cat ~/.claude/CLAUDE.md
cat ~/.claude/instructions/code-style.md

# Any changes to ~/.claude persist to the host
echo "New instruction" >> ~/.claude/CLAUDE.md
```

### On the Host

```bash
# Launch container (automatically mounts ~/.claude to native path)
./localdev

# View mount confirmation message
# Output: "Mounting: /Users/gherlein/.claude -> /home/developer/.claude (read-write)"
```

## Key Benefits

1. **Native path**: Claude Code finds its config at `~/.claude` without any special flags
2. **Single configuration source**: Maintain one set of Claude instructions for all projects
3. **Zero configuration**: No `--add-dir` flags or wrapper complexity needed
4. **Auto-create**: First-time users get the directory created automatically
5. **Persistence**: Configuration changes survive container restarts
6. **Isolation**: Container isolation protects host system while allowing controlled access

## Error Scenarios

| Scenario | Behavior |
|----------|----------|
| `~/.claude` doesn't exist on host | Auto-created by launcher script |
| `~/.claude` can't be created | Mount skipped, info message displayed |
| `~/.claude` exists but not readable | Mount skipped, warning displayed |
| `~/.claude` not mounted | Claude Code runs without global config (uses project-local config only) |

## Implementation Details

The mount is added to the Podman run command:

```bash
podman run -it --rm \
  --userns=keep-id \
  "${USB_DEVICE_FLAG[@]}" \
  "${DEVICE_MOUNTS[@]}" \
  "${GROUP_ADD_FLAG[@]}" \
  -v "$(pwd):/${DIR_NAME}" \
  "${CLAUDE_MOUNT[@]}" \              # ← Global .claude mount (native path)
  "${NPM_CACHE_MOUNT[@]}" \
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
