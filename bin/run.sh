#!/bin/sh

ROOT_PATH="$(realpath $(dirname $0)/..)"

# Load Config
[ -d "$ROOT_PATH/conf" ] && for config in $(ls "$ROOT_PATH"/conf/*.sh); do . "$config"; done

LISTEN_PORT="${LISTEN_PORT:-6881}"
MAX_FRIENDS="${MAX_FRIENDS:-500}"
MAX_PEERS="${MAX_PEERS:-400}"
TORRENT_HOME="${TORRENT_HOME:-/tmp/torrents}"
RUN_DIR="${RUN_DIR:-$(realpath ./run)}"
echo "LISTEN_PORT=$LISTEN_PORT"
echo "MAX_FRIENDS=$MAX_FRIENDS"
echo "MAX_PEERS=$MAX_PEERS"
echo "TORRENT_HOME=$TORRENT_HOME"
echo "RUN_DIR=$RUN_DIR"

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_EXPIRE="${REDIS_EXPIRE:-86400}"
export REDIS_ENABLED
export REDIS_HOST
export REDIS_PORT
export REDIS_EXPIRE
echo "REDIS_ENABLED=$REDIS_ENABLED"
echo "REDIS_HOST=$REDIS_HOST"
echo "REDIS_PORT=$REDIS_PORT"
echo "REDIS_EXPIRE=$REDIS_EXPIRE"

MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-torrent}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-1234567}"
MYSQL_DB="${MYSQL_DB:-torrent}"
export MYSQL_ENABLED
export MYSQL_HOST
export MYSQL_PORT
export MYSQL_USER
export MYSQL_PASSWORD
export MYSQL_DB
echo "MYSQL_ENABLED=$MYSQL_ENABLED"
echo "MYSQL_HOST=$MYSQL_HOST"
echo "MYSQL_PORT=$MYSQL_PORT"
echo "MYSQL_USER=$MYSQL_USER"
echo "MYSQL_PASSWORD=$MYSQL_PASSWORD"
echo "MYSQL_DB=$MYSQL_DB"

# Entrypoint for other scripts #

if [ -n "$*" ]; then
    sh -c "$*"
    exit
fi

# Entrypoint for main script #

cd "$ROOT_PATH" || exit

before_exit() {

    [ -n "$MAIN_PID" ] && pkill -P "$MAIN_PID"
    [ -n "$FILTER_PID" ] && pkill -P "$FILTER_PID"

    printf 'cleaning torrent dir... '
    rm -f $TORRENT_HOME/*/*/*
    rm -f -d $TORRENT_HOME/*/*
    rm -f -d $TORRENT_HOME/*
    echo done.

    printf 'cleaning run dir... '
    [ -z "$(ls -A "$RUN_DIR" 2>&1)" ] && rm -r "$RUN_DIR"
    echo done.

    echo exited
    exit
}

trap before_exit 2 3 15

# Create Log Dir
mkdir -p ./log
touch ./log/hash.txt
touch ./log/debug.txt
touch ./log/log.txt

# Create Run Dir
mkdir -p "$RUN_DIR"

# Main Thread
mkdir -p "$TORRENT_HOME"
touch "$TORRENT_HOME/TORRENT_HOME"
./bin/torsniff \
    --port "${LISTEN_PORT}" \
    --dir "${TORRENT_HOME}" \
    --friends "$MAX_FRIENDS" \
    --peers "$MAX_PEERS" \
    | stdbuf -oL -eL sed -E \
        -e '/^(name|size|file|running)|^$/d' \
        -e 's/^link: magnet:\?xt=urn:btih:([a-z0-9]+)$/\1/g' \
        -e "s#^([a-z0-9]{2})([a-z0-9]+)([a-z0-9]{2})\$#${TORRENT_HOME}/\\1/\\3/\\1\\2\\3.torrent#g" \
    | ./bin/analyse.py /dev/stdin >> ./log/log.txt
# stdbuf -oL -eL

[ -z "$(ls -A "$RUN_DIR" 2>&1)" ] && rm -r "$RUN_DIR"

exit 0




# De-duplication Filter Thread (Deprecated, too slow, too simple)

rm_torrent() {
    local _TORRENT="$1"
    rm -r "$_TORRENT" 2>/dev/null
    _TORRENT="$(dirname "$_TORRENT")"
    [ -z "$(ls -A "$_TORRENT" 2>&1)" -a "$_TORRENT" != / ] && rm -r "$_TORRENT" 2>/dev/null
    _TORRENT="$(dirname "$_TORRENT")"
    [ -z "$(ls -A "$_TORRENT" 2>&1)" -a "$_TORRENT" != / ] && rm -r "$_TORRENT" 2>/dev/null
}

[ ! -e "$RUN_DIR/filtered.pipe" ] && mkfifo "$RUN_DIR/filtered.pipe"
(
while read TORRENT
do
    Hash="$(basename -s .torrent "$TORRENT")"
    grep -q "^$Hash" ./log/hash* && {
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

