#!/bin/sh

cd "$(dirname $(realpath "$0"))/.."

wc -l ./log/log.txt | awk '{print $1}'

