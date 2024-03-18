#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

tail -n "${2:-100000}" $(ls -r ./log/debug*) \
    | grep -oE '^.{40}' | sort | uniq -c | sort -n | tail -n "${1:-10}" \
    | grep -oE '.{40}$' | sed -E '$ ! s/$/|/' | perl -ne 'chomp;print' \
    | xargs -i ./sbin/torrent-raw-search.sh '^({})'

#grep -oE '^[^ ]{40}' $(ls -r ./log/debug*) | sort | uniq -c | sort -n | tail -n "${1:-10}" \
#    | sed -E -e 's/^\s*[^ ]+\s+//g' \
#        -e '$ ! s/$/|/' \
#    | perl -ne 'chomp;print' \
#    | xargs ./sbin/torrent-search.sh

