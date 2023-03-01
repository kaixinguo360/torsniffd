#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

HASH="$1"

(
if [ -n "$(command -v rg)" ]; then
    rg \
        -I \
        -i \
        -e \
        "^${HASH}.*p$" ./log/debug*
else
    grep \
        -h \
        -i \
        -E \
        "^${HASH}.*p$" ./log/debug*
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
