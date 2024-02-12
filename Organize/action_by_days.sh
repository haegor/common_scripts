#!/bin/bash
#
# TODO хорошо бы привести скрипт в надлежащий вид
#
# 2024 (c) haegor
#

case $1 in
'ln_by_create')			# Ссылки по дате создания
  action='ln -s'
  creteria='%w'
;;
'ln_by_mod')			# Ссылки по дате изменения
  action='ln -s'
  creteria='%y'
;;
'mv_by_create')			# Переместить по дате создания
  action='mv'
  creteria='%w'
;;
'mv_by_mod')			# Переместить по дате изменения
  action='mv'
  creteria='%y'
;;
*)
  echo "Нужно указать хотя бы 1 параметр"
  exit 0
esac

work_dir="$(pwd)"

while read LINE
do
  [ -d "${LINE}" ] && continue

  file_time=$(stat --printf=$creteria "${LINE}")
  file_date=${file_time:0:10}
  file_year=${file_time:0:4}
  file_month=${file_time:5:2}

  file_path="${file_year}/${file_month}/${file_date}"

  [ ! -d "./${file_path}" ] && mkdir -p "./${file_path}"

  [ ! -f "${work_dir}/${file_path}/${LINE}" ] \
          && $action "${work_dir}/${LINE}" "./${file_path}/" \
          || echo "Файл существует: ${work_dir}/${file_path}/${LINE}" >> /dev/null

done < <(ls -tA)
