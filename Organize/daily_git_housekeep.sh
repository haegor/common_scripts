#!/bin/bash
#
# Предназначен для помощи в создании историй изменений файлов через git.
# Подразумевается что он запускается ежедневно чтобы сохранять "забытые"
# изменения. Эдакий etckeeper для произвольных файлов.
# Попутно изменяет владельца файлов, что подразумевает права на sudo.
#
# 2023 (c) haegor

msg_params () {
        echo
        echo "Использование: $0 <user> <path>, где:"
        echo "  <user>   - имя владельца файлов"
        echo "Через двоеточие (:) можно указать группу"
        echo "  <path>   - путь, в котором следует сделать add и commit"
        echo "Рекомендация: используйте двойные ковычки."
        echo
        return 0
}

if [ $# -lt 2 ]
then
        echo
        echo "Недостаточно параметров. Нужно два!"
        msg_params
        exit 0
elif [ $# -gt 2 ]
then
        echo
        echo "Слишком много параметров. Нужно два!"
        msg_params
        exit 0
fi

if [ ! $(echo "$1" | grep ':') == '' ]
then
  username=$(echo $1 | cut -f1 -d:)
  usergroup=$(echo $1 | cut -f2 -d:)
else
  username=$1
  usergroup=$1
fi

target_path=$2

sudo chown -R ${username}:${usergroup} "${target_path}"
cd "${target_path}"

if [ -d ".git" ]
then
  git add .
  git commit -m 'daily autocommit'
else
  git init
  git add .
  git commit -m 'initial'
fi
