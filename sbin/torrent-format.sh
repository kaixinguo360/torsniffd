#!/bin/sh

sed -E 's/^([^ ]+)\ts:([^ ]+)\tn:([^\t]*).*$/\1\/\2\/\3/g' \
    | column -t -s '/' \
    | (tee /dev/stderr | wc -l | sed 's/^/Total: /') 2>&1 \

#    | sort | uniq -c | sort -n

