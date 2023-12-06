#!/bin/bash
#
# Скрипт предназначен для создания свода владельцев файлов и их прав на файлы
# с целью применения этих настроек по месту требования.
#
# Когда указываешь restore, то нужно вводить "лишний" параметр, который вовсе
# не лишний. Он используется в случаях, когда используется chroot, lxc или 
# удалённая ФС, смонтированная через sshfs/smb/nfs.
#
# 2020-2023 (c) haegor
#

f_save_settings () {
  chosen_path="$1"
  chosen_file="$2"

  find "${chosen_path}" -exec ls -lad --full-time '{}' \; |  grep -v "^l" | while read record
  do
     owner=$(echo ${record} | cut -f3 -d' ')
     group=$(echo ${record} | cut -f4 -d' ')
     file=$(echo ${record} | cut -f9- -d' ')
     rights=$(stat --printf=%a "${file}" 2>/dev/null)

     echo "{rights} ${owner} ${group} ${file}" >> "${chosen_file}"
  done
}

f_restore_settings () {
  chosen_path="$1"
  chosen_file="$2"

  cat "${chosen_file}" | while read record
  do
     rights=$(echo ${record} | cut -f1 -d' ')
     owner=$(echo ${record} | cut -f2 -d' ')
     group=$(echo ${record} | cut -f3 -d' ')
     file=$(echo ${record} | cut -f4- -d' ')

     chown ${owner}:${group} "${chosen_path}"/"${file}"
     chmod ${rights} "${chosen_path}"/"${file}"

# TODO: Вот над этим следует серьёзно подумать.
#
#     if [ "$chosen_path" == '/' ]
#     then    
#       chown ${owner}:${group} "${file}"
#       chmod ${rights} "${file}"
#     elif [ "$chosen_path" == './' ]
#     then 
#       chown ${owner}:${group} ".${file}"
#       chmod ${rights} ".${file}"
#     else
#       chown ${owner}:${group} "${chosen_path}"/"${file}"
#       chmod ${rights} "${chosen_path}"/"${file}"
#     fi
  done
}


if [ "$1" ] 
then
    mode="$1"
else 
    reason[${#reason[@]}]="Недостаточно параметров. Не указан режим работы скрипта."
    reason[${#reason[@]}]="Выберите из: save, restore."
    reason[${#reason[@]}]=''
    mode="help"
fi

if [ "$2" ] 
then 
    chosen_path="$2"
else
    reason[${#reason[@]}]="Недостаточно параметров."
    reason[${#reason[@]}]="Укажите папку для обработки."
    reason[${#reason[@]}]=''
    mode="help"
fi

if [ "$3" ]
then
    chosen_file="$3"
else
    reason[${#reason[@]}]="Недостаточно параметров."
    reason[${#reason[@]}]="Укажите файл для сохранения/восстановления настроек."
    reason[${#reason[@]}]=''
    mode="help"
fi

case $mode in
'save')				# Сохранение сведений о файлах
  f_save_settings "${chosen_path}" "${chosen_file}"
  echo "Операция сохранения завершена."

;;
'restore')			# Восстановление сведений о файлах
  f_restore_settings "${chosen_path}" "${chosen_file}"
  echo "Операция восстановления завершена."
;;
''|*|'--help'|'-h'|'help')	# Помощь. Мы тут.
  echo

  if [ ${#reason[*]} -eq 0 ]
  then
	  echo "Указан несуществующий режим работы скрипта."
  fi

  for i in `seq 0 ${#reason[*]}`
  do
      echo "${reason[i]}"
  done

  echo "Параметры:"
  echo "$0 (restore|save) <целевая папка> <результирующий файл>"
  echo
  echo "Режимы работы:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  echo "Аргмуенты:"
  echo "Первый - тип действия"
  echo "Второй - папка для анализа/наложения настроек"
  echo "Третий - результирующий файл"
  echo
  echo "При указании путей используйте кавычки"
  echo
  exit 0
;;
esac

