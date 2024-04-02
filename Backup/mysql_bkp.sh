#!/bin/bash
#
# Делает бэкап mysql базы
#
# 2023 (c) haegor
#

dt=$(date +%Y-%m-%d_%H-%M)

username="$1"
password="$2"
database="$3"
bkp_dir="$4"

bkp_file="${bkp_dir}/${dt}_${database}.sql.gz"
[ -f "$bkp_file" ] \
  && { echo "Останов. Такой файл бэкапа уже существует."; exit 0; }

sudo mysqldump -h localhost -u ${username} -p "${password}" | gzip > "$bkp_file"
