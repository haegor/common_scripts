#!/bin/bash
#
# Создаёт резервную копию БД mongo
#

dt=`date +%Y-%m-%d_%k-%M`

db_name=$1
bkp_dir=$2

/opt/mongodb/mongodump --db "${db_name}" --gzip --archive=${bkp_dir}/${db_name}_${dt}.gz
#--out ${bkp_dir}/${db_name}_${dt}
