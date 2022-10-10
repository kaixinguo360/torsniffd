#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

grep -oE '^[^ ]{40}' ./log/debug.txt | sort | uniq -c | sort -n | tail -n "${1:-10}" \
    | sed -E -e 's/^\s*[^ ]+\s+//g' \
        -e '$ ! s/$/|/' \
    | perl -ne 'chomp;print' \
    | xargs ../sbin/torrent-search.sh

