#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

./sbin/torrent-raw-search.sh "$(
printf %s "$*" | sed \
    -e 's#\$#(\t|$)#g' \
    -e 's#\^#(\t|^)#' \
    -e 's#\.#[^\t]#g' \
)"

