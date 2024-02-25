#!/bin/bash
#
# Исполняет sql-скрипт применительно к базе в mysql
# Подразумевается использование в целях автоматического восстановления базы
#
# 2023 (c) haegor
#

username="$1"
password="$2"
db_name="$3"
db_sql="$4"

mysql -u ${username} --database=${db_name} -p"${password}" < "${db_sql}"
