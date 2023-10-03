#!/bin/bash
#
# Делает бэкап mysql базы
#

dt=$(date +%F)

username=$1
password=$2
database=$3
bkp_dir=$4

sudo mysqldump -h localhost -u ${username} -p "${password}" | gzip > "${bkp_dir}"/${dt}_${database}.sql.gz
