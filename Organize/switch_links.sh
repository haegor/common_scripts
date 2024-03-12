#!/bin/bash
#
# Скрипт исполняется на ссылке меняя её местами с файлом, на который она ссылается
# Предназначен для запуска через меню Caja
#
# 2024 (c) haegor
#
#DEBUG='true'

# Количество переданных параметров (файлов)
[ $# -eq 0 ] && exit 0

[ -n "$DEBUG" ] \
  && { rm="echo rm"; mv="echo mv"; ln="echo ln"; \
       tmp_file='/tmp/debug_caja_scripts'; } \
  || { rm="rm"; mv="mv"; ln="ln"; \
       tmp_file='/dev/null'; }

# Все переданные файлы разом
#D echo "@: $@" >> ${tmp_file}

# Временной штамп
#D echo "--- $(date "+%F %T") -----" >> ${tmp_file}

# Текущая директория
# echo "$(pwd)" >> ${tmp_file}

for i in $(seq 1 $#)
do
  if [ ! -L $1 ]
  then
    shift
    continue
  fi

  #Полный путь до текущего файла
  current_link="$(pwd)/$1"

  #адрес, куда он указывает
  target_file=$(realpath "$1")

  $rm "$current_link" &> ${tmp_file}
  $mv "$target_file" "$current_link" &> ${tmp_file}
  $ln -s "$current_link" "$target_file" &> ${tmp_file}

  shift
done
