#!/bin/bash
#
# Скрипт выполняет указанное действие для всех файлов внутри папки из которой
# был запущен.
#
# 2024 (c) haegor
#

# В отличии от большинства остальных скриптов главное действие выполняется
# после case.
case $1 in
'ln_by_create')		# Создать ссылки, создавая папки под них по дате создания
  action='ln -s'
  creteria='%w'
;;
'ln_by_mod')		# Ссылки ссылки, создавая папки под них по дате изменения
  action='ln -s'
  creteria='%y'
;;
'mv_by_create')		# Переместить файлы, создавая папки под них по дате создания
  action='mv'
  creteria='%w'
;;
'mv_by_mod')		# Переместить файлы, создавая папки под них по дате изменения
  action='mv'
  creteria='%y'
;;
'about')		# О Скрипте
  start=0;

# Никогда так не пишите.
  while read LINE; do
  ( [[ "$LINE" == "#" ]] && [ $start -eq 0 ] ) && { start=1; echo -e "\n  О скрипте\n"; } \
  || { ( [ "${LINE:11:16}" != 'haegor' ] && [ $start -eq 1 ] ) && echo "  ${LINE:2}" \
  || { ( [ "${LINE:11:16}" == 'haegor' ] && [ $start -eq 1 ] ) && { echo -e "  ${LINE:2}\n"; exit 0; } } }
  done < <(cat "$0")
  exit 0
;;
'--help'|'-help'|'help'|'-h'|*|'')	# Автопомощь. Мы тут.
  echo
  echo "Нужно указать хотя бы 1 параметр"
  echo
  echo "Перечень доступных опций:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac

[ -z "$creteria" ] && exit 1 # Просто для страховки

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
    || echo "Файл существует: ${work_dir}/${file_path}/${LINE}"
# >> /dev/null

done < <(ls -tA)
