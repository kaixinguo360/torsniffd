#!/bin/sh

REGEX="${REGEX:-$1}"
if [ -n "$FILE" -o -n "$file" ]; then
    if [ -n "$RAW" -o -n "$raw" ]; then
        cat
    elif [ -n "$FULL" -o -n "$full" ]; then
        cat \
            | sed -E 's/\t([fdn]):/\n\1:/g' \
            | grep -iE "	s:|^n:|${REGEX}" \
            | sed -E \
                -e 's/^([fdns]:.*)$/\t\1/g' \
                -e '/^[^\t]{40}/{s/$/     /;h;d}; /^\t/G; s/\t(.*)\n(.{40})\ts:(.{8})/\2  \3  \1/g' \
                -e 's/^(.{52})([^n].*)$/\1 + \2/g' \
                -e 's/^(.{52})n:(.*)$/\1\2/g' \
            | grep -iE --color "$REGEX|$"
    else
        cat \
            | sed -E 's/\t([fdn]):/\n\1:/g' \
            | grep -iE "	s:|^n:|${REGEX}" \
            | sed -E \
                -e 's/^([fdns]:.*)$/\t\1/g' \
                -e '/^[^\t]{40}/{s/$/     /;h;d}; /^\t/G; s/\t(.*)\n(.{8}).{32}\ts:(.{8})/\2  \3  \1/g' \
                -e 's/^(.{20})([^n].*)$/\1 + \2/g' \
                -e 's/^(.{20})n:(.*)$/\1\2/g' \
            | grep -iE --color "$REGEX|$"
    fi
else
    if [ -n "$RAW" -o -n "$raw" ]; then
        cat
    elif [ -n "$FULL" -o -n "$full" ]; then
        sed -E \
            -e 's/^([^ ]+)\ts:([^ ]+)\tn:([^\t]*).*$/\1\t\2    \t\3/g' \
            -e 's/^(.*)\t(.{8}).*\t(.*)$/\1  \2  \3/g' \
            | (tee /dev/stderr | wc -l | sed 's/^/Total: /') 3>&2 2>&1 1>&3 \
            | grep -iE --color "$REGEX|$"
    else
        sed -E \
            -e 's/^(.{8}).{32}\ts:([^ ]+)\tn:([^\t]*).*$/\1\t\2    \t\3/g' \
            -e 's/^(.*)\t(.{8}).*\t(.*)$/\1  \2  \3/g' \
            | (tee /dev/stderr | wc -l | sed 's/^/Total: /') 3>&2 2>&1 1>&3 \
            | grep -iE --color "$REGEX|$"
    fi
fi

