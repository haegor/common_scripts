#!/bin/bash
#
# Делает бэкап списка баз в postgres, завёрнутый в контейнер
#

dt=`date +%F`
bkp_dir=$1

bases=$(cat << EOF
base1
base2
base3
EOF
)

pg_container=$1

for BASE in $bases
do
  docker exec -it ${pg_container} /usr/bin/pg_dump ${BASE} -U ${username} --create --file="${bkp_dir}/${dt}_${BASE}.sql"
done



