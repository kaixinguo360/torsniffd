#!/bin/bash

cd $(dirname $0)

[ -z "$(command -v aria2c)" ] && sudo apt install aria2 -y
python3 -m pip show bencoder.pyx >/dev/null 2>&1 || sudo python3 -m pip install bencoder.pyx

sudo ln -s `pwd`/torsniff /etc/init.d/torsniff
sudo ln -s `pwd`/torsniff.service /etc/systemd/system/torsniff.service

sudo systemctl daemon-reload
sudo systemctl enable torsniff.service > /dev/null 2>&1

sudo service torsniff start

