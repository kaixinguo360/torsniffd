# Torsniffd

[Torsniff](https://github.com/fanpei91/torsniff/) is a interesting project, this project help you to run torsniff as a systemd deamon. It add a very simple postprocess pipe to remove duplicate torrent and convert the torrent files to searchable text store in a plain text file. In order to parse torrent file, python3 and `bencoder.pyx` pip package is required.

This project should be placed at the specific location: `/opt/torsniff`, if you want to use other, don't forget to change all path present in `systemd/` and `conf/` dir.

Detailed installation steps are recorded in [systemd/setup.sh](systemd/setup.sh) and can be execute directly.

Some simple util scripts store in `sbin/` dir, which can help you to search and view torrents easily. All scripts have the `torrent-` prefix, so you can add this dir to the `$PATH` safely.

### The runtime dir structure of this project

```
/opt/torsniff
├── bin                     # Scripts only for systemd use, shouldn't execute directly
│   ├── analyse.py
│   ├── requirements.txt
│   ├── run.sh
│   └── torsniff
├── conf
│   ├── 00-default.sh       # Deafult config, just for refernce, shouldn't edit
│   └── 10-user.sh          # User Config, manually create when necessary, editable
├── log
│   ├── log.txt             # All torrent data store in this file
│   ├── hash.txt            # Record all hash, each hash recorded only once, for de-duplication use
│   ├── debug.txt           # Record all hash, all received hash are recorded, for popularity statistics use
│   └── statis.txt          # Record the number of all torrent data
├── README.md
├── run                     # Runtime dir, auto create and delete
│   ├── filter.pid
│   ├── main.pid
│   ├── filtered.pipe
│   └── torrent.pipe
├── sbin                    # Scripts for search and view torrents
│   ├── torrent-count.sh
│   ├── torrent-format.sh
│   ├── torrent-info.sh
│   ├── torrent-log.sh
│   ├── torrent-preset-search.sh
│   ├── torrent-raw-search.sh
│   ├── torrent-search.sh
│   ├── torrent-top.sh
│   ├── torrent-viewer.sh
│   └── torrent-word-search.sh
└── systemd
    ├── cleanup.sh          # Uninstall Script
    ├── setup.sh            # Install Script
    ├── torsniff
    └── torsniff.service
```

