#!/bin/bash
#
# Скрипт для переименований ссылок.
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
    return 1
  fi

  return 0
}

function f_truncate_link_name () {
  local link_path="$1"
  local link_base_name=$(basename "${link_path}")

  if [ -L "${link_path}" ] &&  [[ "${link_base_name}" =~ ^Ссылка\ на\  ]]
  then
    local dir_name=$(dirname "${link_path}")
    local trunc_base_name=${link_base_name:10}
    local new_path_name="${dir_name}/${trunc_base_name}"
    [ -e "${new_name}" ] \
      && { echo "Новое имя уже занято. Останов."; return 1; } \
      || $mv "${link_path}" "${new_path_name}"
  fi

  return 0
}

# Убирает приписку "Ссылка на " из имён ссылок.
function f_remove_link_to () {
  local removable="$1"

  # Если нам указали не на папку c файлами для обработки, а на конкретный линк,
  # то "лечим" его. В случае, когда скрипт был вызван через вспомогательный
  # скрипт для Caja, то перебор аргументов ведётся за его счёт.
  [ -L "$removable" ] && {
    f_truncate_link_name "${removable}"
    return 0
  }

  [ ! -d "$removable" ] && {
    echo "Переданный аргумент не является ни ссылкой, ни директорией. Останов."
    return 1
  }

  # TODO: почему не -exec? Из-за -print?
  find -H "${removable}" -type l -print | while read LINK
  do
    f_truncate_link_name "${LINK}"
  done

  return 0
}

######################### MAIN #########################
case $1 in
'remove_link_to')			# убрать фразу "Ссылка на" у всех ссылок в указанной директории
  f_enought $# 2 || exit 1
  f_remove_link_to "$2"
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
