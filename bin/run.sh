#!/bin/sh

cd $(realpath $(dirname $0)/..)

# Load Config
[ -d ./conf ] && for config in $(ls ./conf/*.sh); do . "$config"; done

MAX_FRIENDS="${MAX_FRIENDS:-500}"
echo "MAX_FRIENDS=$MAX_FRIENDS"

MAX_PEERS="${MAX_PEERS:-400}"
echo "MAX_PEERS=$MAX_PEERS"

TORRENT_HOME="${TORRENT_HOME:-/tmp/torrents}"
echo "TORRENT_HOME=$TORRENT_HOME"

RUN_DIR="${RUN_DIR:-$(realpath ./run)}"
echo "RUN_DIR=$RUN_DIR"

rm_torrent() {
    local _TORRENT="$1"
    rm -r "$_TORRENT" 2>/dev/null
    _TORRENT="$(dirname "$_TORRENT")"
    [ -z "$(ls -A "$_TORRENT" 2>&1)" -a "$_TORRENT" != / ] && rm -r "$_TORRENT" 2>/dev/null
    _TORRENT="$(dirname "$_TORRENT")"
    [ -z "$(ls -A "$_TORRENT" 2>&1)" -a "$_TORRENT" != / ] && rm -r "$_TORRENT" 2>/dev/null
}

before_exit() {

    [ -n "$MAIN_PID" ] && pkill -P "$MAIN_PID"
    [ -n "$FILTER_PID" ] && pkill -P "$FILTER_PID"

    printf 'cleaning torrent dir... '
    rm -f $TORRENT_HOME/*/*/*
    rm -f -d $TORRENT_HOME/*/*
    rm -f -d $TORRENT_HOME/*
    echo done.

    printf 'cleaning run dir... '
    rm -f "$RUN_DIR/main.pid"
    rm -f "$RUN_DIR/torrent.pipe"
    rm -f "$RUN_DIR/filter.pid"
    rm -f "$RUN_DIR/filtered.pipe"
    [ -z "$(ls -A "$RUN_DIR" 2>&1)" ] && rm -r "$RUN_DIR"
    echo done.

    echo exited
    exit
}

trap before_exit 2 3 15

# Create Log Dir
mkdir -p ./log

# Create Run Dir
mkdir -p "$RUN_DIR"

# Create Torrent Pipe
[ ! -e "$RUN_DIR/torrent.pipe" ] && mkfifo "$RUN_DIR/torrent.pipe"

# Main Thread
[ -e "$RUN_DIR/main.pid" ] && { pkill -P "$(cat "$RUN_DIR/main.pid")"; rm "$RUN_DIR/main.pid"; }
mkdir -p "$TORRENT_HOME"
touch "$TORRENT_HOME/TORRENT_HOME"
(
./bin/torsniff \
    --dir "${TORRENT_HOME}" \
    --friends "$MAX_FRIENDS" \
    --peers "$MAX_PEERS" \
    | sed -E \
        -e '/^(name|size|file|running)|^$/d' \
        -e 's/^link: magnet:\?xt=urn:btih:([a-z0-9]+)$/\1/g' \
        -e "s#^([a-z0-9]{2})([a-z0-9]+)([a-z0-9]{2})\$#${TORRENT_HOME}/\\1/\\3/\\1\\2\\3.torrent#g" \
    >> "$RUN_DIR/torrent.pipe"
) &
MAIN_PID="$!"
echo "$MAIN_PID" > "$RUN_DIR/main.pid"
echo "MIAN_PID=$MAIN_PID"

# De-duplication Filter Thread
[ ! -e "$RUN_DIR/filtered.pipe" ] && mkfifo "$RUN_DIR/filtered.pipe"
(
while read TORRENT
do
    Hash="$(basename -s .torrent "$TORRENT")"
    #printf '%s\n' "$Hash $(date +'%F %T.%3N')" >> ./log/debug.txt
    #[ -n "$(sed -n "/^$Hash/{=;s/$/./}" ./log/hash.txt)" ] && {
    #    sed -i "/^$Hash/ s/$/./" ./log/hash.txt
    grep -q "^$Hash" ./log/hash.txt && {
        printf '%s\n' "$Hash $(date +'%s.%3N') f" >> ./log/debug.txt
        rm_torrent "$TORRENT"
        continue
    }
    printf '%s\n' "$Hash $(date +'%s.%3N') p" >> ./log/debug.txt
    printf '%s\n' "$Hash" >> ./log/hash.txt
    printf '%s\n' "$TORRENT" >> "$RUN_DIR/filtered.pipe"
done < "$RUN_DIR/torrent.pipe"
) &

FILTER_PID="$!"
echo "$FILTER_PID" > "$RUN_DIR/filter.pid"
echo "FILTER_PID=$FILTER_PID"

# Python Post-Process Thread
./bin/analyse.py "$RUN_DIR/filtered.pipe" >> ./log/log.txt

pkill -P "$MAIN_PID"
rm -f "$RUN_DIR/main.pid" "$RUN_DIR/torrent.pipe"
[ -z "$(ls -A "$RUN_DIR" 2>&1)" ] && rm -r "$RUN_DIR"

exit 0

# Aria2 Post-Process Thread (Deprecated, too slow, too simple)

FILTER_MAX_SIZE="${FILTER_MAX_SIZE:-$((500 * 1024))}"
echo "FILTER_MAX_SIZE=$FILTER_MAX_SIZE"

while read TORRENT
do

    Hash="$(basename -s .torrent "$TORRENT")"

    if [ "$(stat --printf="%s" "$TORRENT")" -gt "$FILTER_MAX_SIZE" ]; then
        Name="dropped (too big)"
    else
        Name="$(
            aria2c -S "$TORRENT" \
                | sed -nE 's/^Name: (.*)$/\1/p' \
                | tr '\n' ' '
        )"
    fi

    rm_torrent "$TORRENT"

    printf '%s %s\n' "$Hash" "$Name"

done < "$RUN_DIR/torrent.pipe"

