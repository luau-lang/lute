#!/bin/sh
set -e

# If the first argument starts with `-` or is not a system command, prepend
# `lute` so users can run e.g. `docker run lute run script.luau` directly.
if [ "$1" != "${1#-}" ] || [ -z "$(command -v "${1}")" ]; then
    set -- lute "$@"
fi

exec "$@"
