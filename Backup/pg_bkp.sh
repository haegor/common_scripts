#!/bin/bash
#
# Делает бэкап базы postgres
#

dt=`date +%Y-%m-%d_%k-%M`

username=;1
db_name=$2
bkp_dir=$3

sudo su ${username} -c "pg_dump --dbname=${db_name} | gzip > "${bkp_dir}/${db_name}_${dt}.dump.gz"

