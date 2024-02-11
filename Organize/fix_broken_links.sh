#!/bin/bash
#
# Скрипт для массового исправления битых ссылок, появляющихся при перемещении каталогов.
#
# 2023 (c) haegor
#

#rm='echo rm'
#ln='echo ln'
#mv='echo mv'
rm='rm'
ln='ln'
mv='mv'

# Проверяет достаточно ли аргументов.
# Функция сомнительной полезности. Планировалась под вывод хелпа.
function f_enought () {
  param_count=$1
  need_count=$2

  if [ ${param_count} -ne ${need_count} ]
  then
    echo
    echo "Недостаточно параметров"
    echo "Первый параметр - тип задачи."
    $0 -help
    exit 0
  fi
}

# Если в пути последний символ - слеш, то отрезает его.
function f_normalize_path () {
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
function f_find_and_fix () {
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
        $rm "${analyzed_dir}/${filename}"
        $ln -s "${founded}" "${analyzed_dir}/"
      fi
    fi
  done
}

# Просто выводит битые ссылки в указанном каталоге
function f_find_and_report () {
  analyzed_dir=$1

  find -H "${analyzed_dir}" -type l -print | while read LINE
  do
    if [ -h "${LINE}" ] && [ ! -r "${LINE}" ]
    then
      echo "-------------"
      echo "Битая ссылка: ${LINE}"
      echo "Ссылается на: $(realpath ${LINE})"
    fi
  done
}

function f_truncate_link_name () {
  local LINE="$1"

  if [ -L "${LINE}" ] &&  [[ "${LINE}" =~ 'Ссылка на ' ]]
  then
    local base_name=$(basename "${LINE}")
    local dir_name=$(dirname "${LINE}")
    local trunc_name=${base_name:10}
    local new_name="${dir_name}/${trunc_name}"
    $mv "${LINE}" "${new_name}"
  fi
}

# Убирает приписку "Ссылка на " из имён ссылок.
function f_remove_link_to () {
  analyzed_dir=$1
  
  # В случае если нам указали на конкретный файл. Для запуска из скрипта
  LINE="${analyzed_dir}"
  f_truncate_link_name "${LINE}"

  # Это на случай когда указана директория.
  find -H "${analyzed_dir}" -type l -print | while read LINE
  do
    # && [ -r "${LINE}" ]
    f_truncate_link_name "${LINE}"
  done
}

######################### MAIN #########################
case $1 in
'fix')                    # Найти битые ссылки в папке1 и заменить их на похожие имена в папке2
  f_enought $# 3
  f_find_and_fix "$2" "$3"
;;
'find')                   # Поиск битых ссылок в указанной папке
  f_enought $# 2
  f_find_and_report "$2"
;;
'remove_link_to')  # убрать фразу "Ссылка на" у всех ссылок в директории
  f_enought $# 2
  f_remove_link_to "$2"
;;
'test') #                 # excluder
  f_normalize_path "$2"
;;
'fix_links_script')       # не помню что и зачем.
  find . -type l | while read LINK
  do
    result=$(realpath "${LINK}" &>/dev/null && echo 0 || echo 1)
    if [ ${result} ]
    then
        echo "BROKEN ${LINK}"
        ls -la "${LINK}"
    fi
  done
;;
'about')				# О Скрипте
  comment_brace=0

  while read LINE
  do
    if [[ "$LINE" == "#" ]] && [ $comment_brace -eq 0 ]      # Начало коммента
    then
      comment_brace=1
      echo -e "\n  О скрипте\n"
    elif [ "${LINE:11:17}" != 'haegor' ] && [ $comment_brace -eq 1 ]    # Текст коммента
    then
      echo "  ${LINE:2}"
    elif [ "${LINE:11:17}" == 'haegor' ] && [ $comment_brace -eq 1 ]    # Закрытие
    then
      echo -e "  ${LINE:2}\n"
      exit 0
    fi
  done < <(cat "$0")
;;
'help'|'--help'|'-help'|'-h'|''|*)	# Автопомощь. Мы тут.
  echo
  echo "Перечень доступных опций:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac

