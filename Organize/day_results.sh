#!/bin/bash
#
# Скрипт для составления "сводки" изменений за прошедшие сутки.
# Нужен когда ищешь что-нить, что на ночь глядя редактировал.
#
# 2023 (c) haegor
#

#list=$(sudo find ./ -mmin -1000 -iname "*" | grep -v '/.git/')
list=$(sudo find ./ -mtime -1 -iname "*" | grep -v '/.git/')

while read LINE
do
  if [ -L ${LINE} ]
  then
    echo "LINK - $LINE"
    continue
  fi

  if [ -d ${LINE} ]
  then
    echo "DIR  - $LINE"
    continue
  fi

  if [ -f ${LINE} ]
  then
    echo "FILE - $LINE"
#    grep -rn "dirname" "${LINE}"
  fi
done < <(echo "$list")
