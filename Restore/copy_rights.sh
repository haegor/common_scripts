#!/bin/bash
# author: haegor
# date: 2020-07-07
# DESCRIPTION:
# Скрипт предназначен для копирования прав и владельцев файлов
# с целью переноса на другую систему или бэкапа.
# TODO когда указываешь restore, то нужно вводить лишний параметр - место восстановления. Надо чёт с этим сделать. Да и вообще красоту навести в управлении скриптом

if [ -n "$1" ]; then
        mode=$1
else
        echo "Not selected script mode. Please, choose one: save, restore."
        echo "Common way to use utility is:"
        echo "copy_rights (restore|save) [path] [filename]"
        exit 0
fi


if [ -n "$2" ]; then
        chosen_path=$2
else
        echo "Inseficcient paramaters"
        echo "Common way to use utility is:"
        echo "copy_rights (restore|save) [path] [filename]"
        exit 0
fi


if [ -n "$3" ]; then
        chosen_file=$3
else
        echo "Inseficcient paramaters"
        echo "Common way to use utility is:"
        echo "copy_rights (restore|save) [path] [filename]"
        exit 0
fi


if [ "$1" = 'save' ]; then
        find ${chosen_path} -exec ls -lad --full-time '{}' \; |  grep -v "^l" | while read record
        do
           owner=$(echo ${record} | cut -f3 -d' ')
           group=$(echo ${record} | cut -f4 -d' ')
           file=$(echo ${record} | cut -f9- -d' ')
           rights=$(stat --printf=%a "${file}" 2>/dev/null)
           echo ${rights} ${owner} ${group} ${file} >> ${chosen_file}
        done
fi

if [ "$1" = 'restore' ]; then
        cat ${chosen_file} | while read record
        do
           rights=$(echo ${record} | cut -f1 -d' ')
           owner=$(echo ${record} | cut -f2 -d' ')
           group=$(echo ${record} | cut -f3 -d' ')
           file=$(echo ${record} | cut -f4- -d' ')

           chown ${owner}:${group} "${file}"
           chmod ${rights} "${file}"
        done
fi
