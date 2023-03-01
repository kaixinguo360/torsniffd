#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

TEXT="$*"
printf 'Regex: %s\n' "$TEXT" >&2

(
if [ -n "$(command -v rg)" ]; then
    rg \
        -I \
        -i \
        -e \
        "$TEXT" ./log/log*
else
    grep \
        -h \
        -i \
        -E \
        "$TEXT" ./log/log*
fi
) | ./sbin/torrent-format.sh "$TEXT"
