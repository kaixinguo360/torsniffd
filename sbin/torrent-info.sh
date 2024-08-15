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
        "^$HASH" $(ls -r ./log/log*)
else
    zgrep \
        -h \
        -i \
        -E \
        "^$HASH" $(ls -r ./log/log*)
fi
) \
    | sort -u \
    | sed -E -e 's#^([^ ]+)\ts:([^ ]+)\tn:([^\t]+)\t?(.*)$#----------------\nHash: \1\nURI : magnet:?xt=urn:btih:\1\nSize: \2\nName: \3\n----------------\n\4#g' -e 's#\t#\n#g' \
    | less
