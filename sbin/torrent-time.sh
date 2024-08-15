#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

HASH="$1"

(
if [ -n "$(command -v rg)" ]; then
    rg \
        -z \
        -I \
        -i \
        -e \
        "^${HASH}.*p$" $(ls -r ./log/debug*)
else
    zgrep \
        -h \
        -i \
        -E \
        "^${HASH}.*p$" $(ls -r ./log/debug*)
fi
) \
    | stdbuf -oL -eL \
        sed -E 's/\s+.$//g' \
    | xargs -i sh -c 'echo "$(
        echo "{}" | sed "s/\s.*$//g"
        ) $(
        echo "{}" | sed \
            -e "s/^.*\s//g" \
            -e "s/\..*$//g" \
            -e "s/^/@/g" \
            | xargs date +"%F %T" -d
        )"'

