#!/bin/bash
#
# Разные операции по поиску файлов и отделения их в отдельную папочку.
# Используется для наведения порядка в хранилищах. К примеру документации.
#
# 2023 (c) haegor
#
# TODO: Плохо переносит имена, содержащие символ ->`<-. tr?
# TODO: Перепроверить перемещение при условии совпадении имён файлов
# TODO: Перепроверить обработку параметров.
#

FNM_EXTMATCH=true

case $1 in
'match'|'find'|'move'|'md5-sum'|'md5-file')		# excluder
    [ -z "$2" ] && { echo; \
      echo "Недостаточно параметров!"; \
      $0 --help ; \
      exit 0; }

    # TODO: такой шаблон имеет недостаток - файл не может начинаться с $2
    [ -n "$2" ] && pattern="*$2*"
#      pattern="*?(._-)$2?(._-)*"
;;
esac

case $1 in
'match'|'find')				# Посмотреть потенциально отделяемые файлы
    find . -iname "${pattern}" -exec bash -c 'BN=$(basename "{}"); echo "$BN - {}" ' \; | sort
;;
'move')					# Отделить файлы в отдельную папку
    [ -n "$3" ] && to_dir="$3" || to_dir="./_found"

    # Для исполнения команд через exec find-а мы запускаем сабшелл, поэтому нужен export
    export to_dir

    # по умолчанию mv перезаписывает файлы без спроса, т.е. активирован force-режим. Это можно изменить запросив интерактив: -i
    # Но так сортировка затянется, поэтому я автоматом переименовываю файлы. -i нужен сугубо для отладки.
    # TODO
    find . -iname "${pattern}" -type f -exec \
      bash -c 'BN=$(basename "{}"); if [ -f "${to_dir}/${BN}" ]; then mv -i "{}" "${to_dir}/${BN}_+1"; else mv -i "{}" "${to_dir}/"; fi' \;
;;
'md5-sum')				# Вычислить md5, сортировать по md5
    find . -iname "${pattern}" -exec \
      bash -c 'BN=$(basename "{}"); md5=$(md5sum "{}" | cut -f1 -d" "); echo "$md5 - $BN - {}"' \; | sort
;;
'md5-file')				# Вычислить md5, сортировать по именам файлов
    find . -iname "${pattern}" -exec \
      bash -c 'BN=$(basename "{}"); md5=$(md5sum "{}" | cut -f1 -d" "); echo "$BN - $md5 - {}"' \; | sort
;;
'about')				# О Скрипте
  start=0;

# Никогда так не пишите.
   while read LINE; do
  ( [[ "$LINE" == "#" ]] && [ $start -eq 0 ] ) && { start=1; echo -e "\n  О скрипте\n"; } \
  || { ( [ "${LINE:11:17}" != 'haegor' ] && [ $start -eq 1 ] ) && echo "  ${LINE:2}" \
  || { ( [ "${LINE:11:17}" == 'haegor' ] && [ $start -eq 1 ] ) && { echo -e "  ${LINE:2}\n"; exit 0; } } }
  done < <(cat "$0")
;;
'--help'|'-help'|'help'|'-h'|*|'')	# Автопомощь. Мы тут.
  echo
  echo "Недостаточно параметров или они неверно указаны."
  echo
  echo "Первый параметр - тип задачи: find, move, md5, help"
  echo "Второй параметр - шаблон имени файла, который следует искать"
  echo "[Третий параметр] - целевая папка, куда следует складывать файлы"
  echo "                    по умолчанию ../_find"
  echo
  echo "Перечень доступных опций:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac
