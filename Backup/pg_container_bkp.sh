#!/bin/bash
#
# Делает бэкап списка баз из postgres, завёрнутого в контейнер
#
# 2023 (c) haegor
#

dt=$(date +%Y-%m-%d_%H-%M)

bkp_dir="$1"

bases=$(cat << EOF
base1
base2
base3
EOF
)

pg_container=$1

for BASE in $bases
do
  bkp_file="${bkp_dir}/${BASE}_${dt}.sql"
  [ -f "$bkp_file" ] \
    && { echo "Бэкап файл $bkp_file уже существует."; continue; }

  docker exec -it ${pg_container} /usr/bin/pg_dump ${BASE} -U ${username} --create --file="${bkp_file}"
done
