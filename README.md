# Torsniffd

[Torsniff](https://github.com/fanpei91/torsniff/) is a interesting project, this project help you to run torsniff as a systemd deamon. It add a very simple postprocess pipe to remove duplicate torrent and convert the torrent files to searchable text store in a plain text file. In order to parse torrent file, python3 and `bencoder.pyx` pip package is required.

This project should be placed at the specific location: `/opt/torsniff`, if you want to use other, don't forget to change all path present in `systemd/` and `conf/` dir.

Detailed installation steps are recorded in [systemd/setup.sh](systemd/setup.sh) and can be execute directly.

Some simple util scripts store in `sbin/` dir, which can help you to search and view torrents easily. All scripts have the `torrent-` prefix, so you can add this dir to the `$PATH` safely.

