#!/bin/bash
set -e

HOST_UID=${HOST_UID:-1000}
HOST_GID=${HOST_GID:-1000}

# Remap the developer user's UID/GID to match the host user so that files
# written to bind-mounted volumes have the correct ownership on the host.
if [ "$(id -u)" = "0" ]; then
    if [ "$HOST_GID" != "1000" ]; then
        groupmod -g "$HOST_GID" developer
    fi
    if [ "$HOST_UID" != "1000" ]; then
        usermod -u "$HOST_UID" developer
        chown -R "$HOST_UID:$HOST_GID" /home/developer
    fi
    exec gosu developer "$@"
else
    exec "$@"
fi
