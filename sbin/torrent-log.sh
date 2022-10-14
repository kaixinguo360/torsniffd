#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

printf '%s\n' "$(date +'%F %H:%M:%S') $(./sbin/torrent-count.sh)" >> ./log/statis.txt

