#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

(
if [ -n "$1" ]; then
    grep -oE "^$1" ./log/debug*
else
    cat ./log/log*
fi
) | wc -l | awk '{print $1}'
