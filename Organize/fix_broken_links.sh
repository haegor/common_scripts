#!/bin/bash
#
# Скрипт для массового исправления битых ссылок, появляющихся при перемещении каталогов.
#
# 2023-2024 (c) haegor
#

debug='false'
[ $debug == 'true' ] \
  && { set -x; rm='echo rm'; ln='echo ln'; mv='echo mv'; } \
  || { set -; rm='rm'; ln='ln'; mv='mv'; }

# Проверяет достаточно ли аргументов.
# Функция сомнительной полезности. Планировалась под вывод хелпа.
function f_enought () {
  local param_count="$1"
  local need_count="$2"

  if [ ${param_count} -ne ${need_count} ]
  then
    echo
    echo "Недостаточно параметров"
    echo "Первый параметр - тип задачи."
    $0 -help
    exit 0
  fi

  return 0
}

# Если в пути последний символ - слеш, то отрезает его.
function f_normalize_path () {
  local path_name="$1"
  local path_name_len=${#1}

  #D echo "path of ${path_name}, начиная с $path_name_len: ${path_name:${path_name_len}-1}"

  [ "${path_name:${path_name_len}-1}" == '/' ] \
    && echo ${path_name:0:${path_name_len}-1} \
    || echo ${path_name}

  return 0
}

# Ищет ссылки, проверяет на битость и если найден всего 1 вариант - делает автозамену
function f_find_and_fix () {
  local analyzed_dir=$(f_normalize_path "$1")
  local analyzed_dir_len=${#analyzed_dir}
  local storage_dir=$(f_normalize_path "$2")

  find -H "${analyzed_dir}" -maxdepth 1 -type l -print | while read LINK
  do
    if [ -h "${LINK}" ] && [ ! -r "${LINK}" ]
    then
      echo "-----------------------------------"
      echo "Битая ссылка на ${LINK}"

      filename=${LINK:${analyzed_dir_len}+1}
      echo "Имя файла: ${filename}"

      founded=$(find "${storage_dir}" -not -path "${analyzed_dir}/*" -type f -name "${filename}" -print -quit )
      [ -z "${founded}" ] && {
         echo "Вариантов не найдено"
         continue
      }

      # TODO: проверить на поведение при нескольких найденных вариантах и вариантах с пробелами
      founded_count=$(echo "${founded}" | wc -l)
      if [ $founded_count -eq 1 ]
      then
        echo "Нaйден: ${founded}"
        $rm "${analyzed_dir}/${filename}"
        $ln -s "${founded}" "${analyzed_dir}/"
      else
        # Пустые и единичные варианты уже отсеяли, значит может быть только >1
        echo "Слишком много вариантов. Не знаю что выбрать из:"
        for i in "${founded}"
        do
          echo "${i}"
        done

        return 1
      fi
    fi
  done

  return 0
}

# Просто выводит битые ссылки в указанном каталоге
function f_find_and_report () {
  local analyzed_dir="$1"

  find -H "${analyzed_dir}" -type l -print | while read LINK
  do
    if [ -h "${LINK}" ] && [ ! -r "${LINK}" ]
    then
      echo "-------------"
      echo "Битая ссылка: ${LINK}"
      local link_to=$(readlink "${LINK}" || echo 'а никуда она не ссылается...')
      echo "Ссылается на: $link_to"
    fi
  done

  return 0
}

######################### MAIN #########################
case $1 in
'fix')					# Найти битые ссылки в папке1 и заменить их на похожие имена в папке2
  f_enought $# 3 || exit 1
  [ ! -d "$2" ] \
    && { echo "Указанный аргумент($2) не является папкой. Останов."; exit 1; }
  [ ! -d "$3" ] \
    && { echo "Указанный аргумент($3) не является папкой. Останов."; exit 1; }

  f_find_and_fix "$2" "$3"
;;
'find')					# Поиск битых ссылок в указанной папке
  f_enought $# 2 || exit 1
  [ ! -d "$2" ] \
    && { echo "Указанный аргумент не является папкой. Останов."; exit 1; }

  f_find_and_report "$2"
;;
'test')					# excluder
  f_normalize_path "$2"
;;
'about')				# О Скрипте
  start=0;

# Никогда так не пишите.
  while read LINE; do
  ( [[ "$LINE" == "#" ]] && [ $start -eq 0 ] ) && { start=1; echo -e "\n  О скрипте\n"; } \
  || { ( [ "${LINE:16:22}" != 'haegor' ] && [ $start -eq 1 ] ) && echo "  ${LINE:2}" \
  || { ( [ "${LINE:16:22}" == 'haegor' ] && [ $start -eq 1 ] ) && { echo -e "  ${LINE:2}\n"; exit 0; } } }
  done < <(cat "$0")
;;
'--help'|'-help'|'help'|'-h'|*|'')	# Автопомощь. Мы тут.
  echo
  echo "Перечень доступных опций:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac
