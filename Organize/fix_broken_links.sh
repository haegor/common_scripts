#!/bin/bash
#
# Скрипт для массового исправления битых ссылок, появляющихся при перемещении каталогов.
#
# 2023 (c) haegor
#

# Проверяет достаточно ли аргументов.
# Функция сомнительной полезности. Планировалась под вывод хелпа.
function enought () {
  param_count=$1
  need_count=$2

  if [ ${param_count} -ne ${need_count} ]
  then
    $0 -help
    exit 0
  fi
}

# Если в пути последний символ - слеш, то отрезает его.
function normalize_path () {
	first=$1
	first_len=${#1}

	#D echo "path of ${first}, начиная с $first_len: ${first:${first_len}-1}"

	if [ "${first:${first_len}-1}" == '/' ]
	then
		echo ${first:0:${first_len}-1}
	else
		echo ${first}
	fi
}

# Ищет ссылки, проверяет на битость и если найден всего 1 вариант - делает автозамену
function find_and_fix () {
  analyzed_dir=$(normalize_path "$1")
  analyzed_dir_len=${#analyzed_dir}
  storage_dir=$(normalize_path "$2")

  find -H "${analyzed_dir}" -maxdepth 1 -type l -print | while read LINE
  do
    if [ -h "${LINE}" ] && [ ! -r "${LINE}" ]
    then
      echo "-----------------------------------"
      echo "Битая ссылка на ${LINE}"

      filename=${LINE:${analyzed_dir_len}+1}
      echo "Имя файла: ${filename}"
		
      founded=$(find "${storage_dir}" -not -path "${analyzed_dir}/*" -type f -name "${filename}" -print -quit )
      if [ "${founded}" == '' ]
      then 
	     echo "Вариантов не найдено"
	     continue
      else
             echo "Нaйден: ${founded}"
      fi

      # TODO: проверить на поведение при нескольких найденных вариантах и вариантах с пробелами
      if [ $(echo ${founded} | wc -l) -eq 1 ]
      # && [ ! "${founded}" == '' ] - пустые варианты мы убрали на стадии отображения предварительных результатов
      then
        echo rm "${analyzed_dir}/${filename}"
        echo ln -s "${founded}" "${analyzed_dir}/"
      fi
    fi
  done
}

# Просто выводит битые ссылки в указанном каталоге
function find_and_report () {
  analyzed_dir=$1

  find -H "${analyzed_dir}" -type l -print | while read LINE
  do
    if [ -h "${LINE}" ] && [ ! -r "${LINE}" ]
    then
      echo "Битая ссылка на ${LINE}"
    fi
  done
}

# Убирает приписку "Ссылка на " из имён ссылок.
function remove_link_to () {
  analyzed_dir=$1

  find -H "${analyzed_dir}" -type l -print | while read LINE
  do
    # && [ -r "${LINE}" ]
    if [ -h "${LINE}" ] && [[ "${LINE}" =~ 'Ссылка на ' ]]
    then
      base_name=$(basename "${LINE}")
      dir_name=$(dirname "${LINE}")
      trunc_name=${base_name:10}
      new_name="${dir_name}/${trunc_name}"
      mv "${LINE}" "${new_name}"
    fi
  done
}

######################### MAIN #########################
case $1 in
'fix') # Найти битые ссылки в папке1 и заменить их на похожие имена в папке2
  enought $# 3
  find_and_fix "$2" "$3"
;;
'find') # Поиск битых ссылок в папке
  enought $# 2
  find_and_report "$2"
;;
'remove_link_to') #
  enought $# 2
  remove_link_to "$2"
;;
'test') #
  normalize_path "$2"
;;
'fix_links_script') #
  find . -type l | while read LINK
  do
    #result=$(realpath "${LINK}" 1>/dev/null 2>/dev/null && echo 0 || echo 1)
    result=$(realpath "${LINK}" &>/dev/null && echo 0 || echo 1)
    if [ ${result} ]
    then
        echo "BROKEN ${LINK}"
        ls -la "${LINK}"
    fi
  done
;;
'--help'|'-help'|'help'|'-h'|'*'|'') # Помощь. Мы тут.
  echo
  echo "Недостаточно параметров"
  echo "Первый параметр - тип задачи: fix, find, help"
  echo
  echo "Перечень доступных опций:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac
