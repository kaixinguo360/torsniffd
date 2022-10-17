#!/bin/sh

INPUT_FILE="$(realpath "${1?}")"
SEPARATOR="[ -_.]*"

cd "$(dirname $(realpath "$0"))/.."

./sbin/torrent-raw-search.sh "$(
sed -E \
    -e "s/ +/$SEPARATOR/g" \
    -e 's/^\^/(^|\t)/g' \
    -e 's/\$$/($|\t)/g' \
    -e '$ ! s/$/|/' \
    "$INPUT_FILE" \
    | perl -ne 'chomp;print' \
    | {
        if [ -n "$(command -v rg)" ]; then
            sed -E 's/\\[<>]/\\b/g'
        else
            cat
        fi
    }
)"

#printf '%s\n' "Regex: $REGEX"
#grep -E "$REGEX" ./log/log* \
#    | sed -E 's/^([^ ]+)\ts:([^ ]+)\tn:([^\t]*).*$/\1\/\2\/\3/g' \
#    | column -t -s '/' \
#    | (tee /dev/stderr | wc -l | sed 's/^/Total: /') 2>&1 \
##    | sort | uniq -c | sort -n

