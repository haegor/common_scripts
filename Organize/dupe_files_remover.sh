#!/bin/bash
#
# Скрипт вычисляет хеш-суммы файлов в текущей папке и сравнивает их, вычисляя
# дубликаты.
#
# 2024 (c) haegor
#

# Если убрать echo, то станет удалять дубликаты.
rm='echo rm'

all_files=$(ls)

# Вычисляем хэши для всех файлов в папке
files_with_md5=''
while read LINE
do
  files_with_md5+="$(md5sum "$LINE")\n"
done < <(echo "$all_files")

# Вычисляем дубликаты и удаляем ненужное
PREV=''
while read CURRENT
do
  [ -z "$CURRENT" ] && continue

  echo "PREV: $PREV"
  echo "CURR: $CURRENT"
  echo "-----"

  if [ "${CURRENT:0:32}" == "${PREV:0:32}" ]
  then
    echo "||||| Удаляем: ${CURRENT:34}"
    $rm "${CURRENT:34}"
    echo "====="
  else
    PREV=$CURRENT
  fi
 
done < <(echo -e "$files_with_md5" | sort)

