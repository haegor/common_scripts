#!/bin/bash

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
      echo "Нaйденный: ${founded}"

      #if [ $(echo ${founded} | wc -l) -lt 1 ]
#	then
  	  echo rm "${analyzed_dir}/${filename}"
	    echo ln -s "${founded}" "${analyzed_dir}/"
#	fi
      fi
  done
}

function find_and_report () {
  analyzed_dir=$1

  find -H "${analyzed_dir}" -type l -print |  while read LINE
  do
    if [ -h "${LINE}" ] && [ ! -r "${LINE}" ]
    then
      echo "Битая ссылка на ${LINE}"
    fi
  done
}

function remove_link_to () {
  analyzed_dir=$1

  find -H "${analyzed_dir}" -type l -print |  while read LINE
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


case $1 in
'fix') # Найти битые ссылки в папке1 и заменить их на похожие имена в папке2
  enought $# 3
  find_and_fix "$2" "$3"
;;
'find') # Поиск битых ссылок в папке
  enought $# 2
  find_and_report "$2"
;;
'remove_link_to')
  enought $# 2
  remove_link_to "$2"
;;
'test')
  normalize_path $2
;;
'fix_links_script')
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
  echo "Недостаточно параметров"
  echo "Первый параметр - тип задачи: fix, find, help"
  echo
  echo "Перечень доступных опций:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0
  exit 0
;;
esac
