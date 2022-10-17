#!/bin/sh

if [ -n "$RAW" -o -n "$raw" ]; then
    cat
else
    sed -E 's/^([^ ]+)\ts:([^ ]+)\tn:([^\t]*).*$/\1\/\2\/\3/g' \
        | column -t -s '/' \
        | (tee /dev/stderr | wc -l | sed 's/^/Total: /') 2>&1
fi

#    | sort | uniq -c | sort -n

