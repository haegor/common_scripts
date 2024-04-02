#!/bin/bash
#
# Делает бэкап базы postgres
#
# 2023 (c) haegor
#

dt=$(date +%Y-%m-%d_%H-%M)

username="$1"
db_name="$2"
bkp_dir="$3"

bkp_file="${bkp_dir}/${db_name}_${dt}.dump.gz"
[ -f "$bkp_file" ] \
  && { echo "Останов. Такой файл бэкапа уже существует."; exit 0; }

sudo su ${username} -c "pg_dump --dbname=${db_name} | gzip > $bkp_file"
