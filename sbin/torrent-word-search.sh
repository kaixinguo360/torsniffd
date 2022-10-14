#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

if [ -n "$(command -v rg)" ]; then
    WD='\\b'
fi
./sbin/torrent-raw-search.sh "$(
printf %s "$*" | sed \
    -e "s#^#${WD:-\\\\<}#g" \
    -e "s#\$#${WD:-\\\\>}#g" \
)"

