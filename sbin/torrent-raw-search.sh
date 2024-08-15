#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

TEXT="$*"
printf 'Regex: %s\n' "$TEXT" >&2

(
if [ -n "$(command -v rg)" ]; then
    rg \
        -z \
        -I \
        -i \
        -e \
        "$TEXT" $(ls -r ./log/log*)
else
    zgrep \
        -h \
        -i \
        -E \
        "$TEXT" $(ls -r ./log/log*)
fi
) | stdbuf -oL -eL ./sbin/torrent-format.sh "$TEXT"
