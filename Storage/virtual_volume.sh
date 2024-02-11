#!/bin/bash
#
# Создаёт файл и подключает его как блочное устройство через loop.
# Планировалось использовать для экспериментов с ceph.
#
# 2023 (c) haegor
#

### Секция настроек ############################################################

# В $2 будет либо raw-файл, либо его loop. В зависимости от режима
[ "$2" ] && volume_file="$2" || volume_file='./test_volume'
[ "$3" ] && mount_point="$3" || mount_point='/mnt/dev'

losetup='sudo losetup'
mount='sudo mount'
umount='sudo umount'

size=256

### Ищет гнездо среди loop файлов ##############################################
# mortice - с английского "гнездо", в смысле пустая ячейка
#
f_find_mortice () {
  for i in $(seq 0 7)
  do
    tested_loop="/dev/loop${i}"
    cur=$(${losetup} | grep "${tested_loop}" | cut -f1 -d' ')

    if [ ! -n "${cur}" ]
    then
      first_empty="${tested_loop}"
      break
    fi
  done

  echo "${first_empty}"
}

### MAIN #######################################################################

case $1 in
'all')			# Создать raw-файл, подключить к loop устройству и смонтировать
    echo 1
;;
'create')		# Создать raw-файл, подключить к loop устройству и смонтировать
  [ ! -f "${volume_file}" ] && dd if=/dev/zero of="${volume_file}" bs=1M count=${size} 2>/dev/null

  mounted_loop=$(${losetup} | grep "${volume_file}" | cut -f1 -d' ')

  if [ "${mounted_loop}" ]
  then
      echo "Файл ${volume_file} уже был смонтирован"
      exit 0
  fi

  $0 attach "${volume_file}"
;;
'attach')		# Подключить raw-файл к loop-устройству
  loop_mortice=$(f_find_mortice)

  ${losetup} "${loop_mortice}" "${volume_file}"

  echo ${loop_mortice}
;;
'detach')		# Отключить raw-файл от loop-устройству
  # TODO: проверку на смонтированность

  loop_file=$(${losetup} | grep "${volume_file}" | cut -f1 -d' ')

  $0 umount

  if [ "${loop_file}" ]
  then
    ${losetup} --detach "${loop_file}"
  fi
;;
'mount')		# Примонтировать loop-устройство
  # TODO работу с параметрами. Возможность вызвать через другие части скрипта.
  ${mount} "${volume_file}" "${mount_point}"
;;
'umount')		# Демонтировать loop-устройство
  [ "${mount_point}" ] && ${umount} "${mount_point}"
  [ "${volume_file}" ] && ${umount} "${volume_file}"
;;
'look'|'ls')		# Осмотреться перед тем как что-то делать
  echo "=== Loop devices: =================================================================================="
  ${losetup}
  echo "=== Mount points: =================================================================================="
  ${mount} | grep '/dev/loop'
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
'--help'|'-help'|'help'|'-h'|*|'')	# Автопомощь. Мы тут.
  echo
  echo "Недостаточно параметров или они неверно указаны."
  echo "В качестве обязательного параметра указывается его режим."
  echo
  echo "$0 <all|create|attach|detach|mount|umount|look|help> \\"
  echo "	[raw-файл|loop-устройство] [точка монтирования]"
  echo
  echo "Перечень режимов:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac

