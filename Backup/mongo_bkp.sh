#!/bin/bash
#
# Создаёт резервную копию БД mongo
#
# 2023 (c) haegor
#

dt=$(date +%Y-%m-%d_%H-%M)

db_name="$1"
bkp_dir="$2"

bkp_file="${bkp_dir}/${db_name}_${dt}.gz"

[ -f "$bkp_file" ] \
  && { echo "Останов. Такой файл бэкапа уже существует."; exit 0; }

/opt/mongodb/mongodump --db "${db_name}" --gzip --archive="$bkp_file"
#--out ${bkp_dir}/${db_name}_${dt}
