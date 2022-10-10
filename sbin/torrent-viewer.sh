#!/bin/sh

if [ -z "$*" ]; then
    printf 'Usage: %s \\\n\tTORRENT_HASH\t\t\t# View Torrent file only \\\n\t[FILE_INDEX_TO_DOWNLOAD]\t# Download specific file to tmp directory \\\n\t[FILE_PATH_TO_SAVE]\t\t# Download specific file to target location\n' "$0"
    printf 'View or download the file from torrent(TORRENT_HASH)\n'
    return 0
fi

HASH="${1?Help: $0 <hash_of_torrent_to_view> [index_of_file_to_download] [target_location_to_save_file]}"
URI="magnet:?xt=urn:btih:$HASH"
DL_DIR="/tmp/aria2/$HASH"
TORRENT="$DL_DIR/$HASH.torrent"
FILE_INDEX="$2"
FILE_PATH="$3"
PORT="6881"

start_service() {
    if systemctl is-active --quiet torsniff.service; then
        echo "Service is running"
    else
        if [ -n "$(lsof -i udp:6881 | tail -n +2)" ]; then
            echo "Another download process is running, skip restart service"
        else
            printf 'Starting service... ' \
                && sudo service torsniff start \
                && echo done.
        fi
    fi
}

stop_service() {
    if systemctl is-active --quiet torsniff.service; then
        printf 'Stopping service... ' \
            && sudo service torsniff stop \
            && echo done.
    else
        if [ -n "$(lsof -i udp:6881 | tail -n +2)" ]; then
            echo "Another download process is running, change port to 6881-6999"
            PORT="6881-6999"
        else
            echo "Service is closed"
        fi
    fi
}

trap start_service 2 3 15

mkdir -p "$DL_DIR"

if [ ! -e "$TORRENT" ]; then # Download torrent file to tmp directory
    stop_service
    aria2c \
        --dht-listen-port="$PORT" \
        --listen-port="$PORT" \
        --dir "$DL_DIR" \
        --bt-metadata-only=true \
        --bt-save-metadata=true \
        --follow-torrent=false \
        "$URI"
fi

if [ "$FILE_INDEX" = 'all' ]; then # Download all files to tmp directory
    stop_service
    aria2c \
        --dht-listen-port="$PORT" \
        --listen-port="$PORT" \
        --dir "$DL_DIR" \
        --seed-time=0 \
        --seed-ratio=0.001 \
        --bt-load-saved-metadata=true \
        "$DL_DIR/$HASH.torrent"
elif [ -n "$FILE_PATH" ]; then # Download specific file to target location
    if [ -e "$FILE_PATH" ]; then
        echo "Target file exists, skip download"
    else
        stop_service
        mkdir -p "$DL_DIR/tmpfile-$FILE_INDEX" \
        && aria2c \
            --dht-listen-port="$PORT" \
            --listen-port="$PORT" \
            --dir "$DL_DIR/tmpfile-$FILE_INDEX" \
            --seed-time=0 \
            --seed-ratio=0.001 \
            --allow-overwrite=true \
            --bt-load-saved-metadata=true \
            --select-file="$FILE_INDEX" \
            --index-out="$FILE_INDEX"="tmpfile" \
            "$DL_DIR/$HASH.torrent" \
        && mkdir -p "$(dirname "$FILE_PATH")" \
        && mv "$DL_DIR/tmpfile-$FILE_INDEX/tmpfile" "$FILE_PATH" \
        && rm -rf "$DL_DIR/tmpfile-$FILE_INDEX" \
        && file "$FILE_PATH"
    fi
elif [ -n "$FILE_INDEX" ]; then # Download specific file to tmp directory
    stop_service
    aria2c \
        --dht-listen-port="$PORT" \
        --listen-port="$PORT" \
        --dir "$DL_DIR" \
        --seed-time=0 \
        --seed-ratio=0.001 \
        --bt-load-saved-metadata=true \
        --select-file="$FILE_INDEX" \
        "$DL_DIR/$HASH.torrent" \
    && tree "$DL_DIR"
else
    aria2c -S "$DL_DIR/$HASH.torrent"
fi

start_service

