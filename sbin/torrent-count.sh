#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

(
if [ -n "$1" ]; then
    zgrep -oE "^$1" $(ls -r ./log/debug*)
else
    cat $(ls -r ./log/log*)
fi
) | wc -l | awk '{print $1}'
