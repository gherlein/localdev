#!/bin/bash

# Get host user's UID and GID from environment variables
HOST_UID=${HOST_UID:-1000}
HOST_GID=${HOST_GID:-1000}

# If running as root, adjust ubuntu user's UID/GID to match host
if [ "$(id -u)" = "0" ]; then
    # Update ubuntu user's UID and GID
    usermod -u $HOST_UID ubuntu 2>/dev/null || true
    groupmod -g $HOST_GID ubuntu 2>/dev/null || true
    
    # Fix ownership of ubuntu's home directory
    chown -R $HOST_UID:$HOST_GID /home/ubuntu
    
    # Switch to ubuntu user with matching UID/GID
    exec gosu ubuntu "$@"
else
    # Already running as non-root, just execute command
    exec "$@"
fi