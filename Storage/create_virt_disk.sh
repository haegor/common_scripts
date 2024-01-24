#!/bin/bash
#
# Нужен чтобы не вспоминать как это делается.
#
# 2023 (c) haegor
#

./virtual_volume.sh create
sudo mkfs.ext4 /dev/loop1
sudo mount /dev/loop1 /mnt/dev


