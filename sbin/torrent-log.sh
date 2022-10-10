#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

echo $(date +'%F %H:%M:%S') $(./sbin/torrent-count.sh) >> ./log/statis.txt

