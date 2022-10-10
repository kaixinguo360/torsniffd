#!/bin/bash

cd $(dirname $0)

sudo service torsniff stop
sudo systemctl disable torsniff.service > /dev/null 2>&1

sudo rm /etc/init.d/torsniff
sudo rm /etc/systemd/system/torsniff.service

sudo systemctl daemon-reload

