#!/bin/bash
set -e

HOST_UID=${HOST_UID:-1000}
HOST_GID=${HOST_GID:-1000}

# Remap the developer user's UID/GID to match the host user so that files
# written to bind-mounted volumes have the correct ownership on the host.
if [ "$(id -u)" = "0" ]; then
    if [ "$HOST_GID" != "1000" ]; then
        # Check if the target GID already exists
        if ! getent group "$HOST_GID" >/dev/null 2>&1; then
            groupmod -g "$HOST_GID" developer
        else
            echo "Note: GID $HOST_GID already exists in container, using existing group" >&2
            # Delete the developer group and add developer user to the existing group
            groupdel developer 2>/dev/null || true
            usermod -g "$HOST_GID" developer
        fi
    fi
    if [ "$HOST_UID" != "1000" ]; then
        usermod -u "$HOST_UID" developer

        # Chown only files/dirs that exist in the image, not bind mounts
        # This avoids errors on read-only mounts like bin/, mounts, etc.
        chown "$HOST_UID:$HOST_GID" /home/developer 2>/dev/null || true

        for item in .bashrc .profile .bash_logout .bash_history .inputrc .config .cache .local .ssh .gnupg; do
            if [ -e "/home/developer/$item" ]; then
                chown -R "$HOST_UID:$HOST_GID" "/home/developer/$item" 2>/dev/null || true
            fi
        done
    fi
    exec gosu developer "$@"
else
    exec "$@"
fi
