#!/bin/bash
#
# Скрипт создан на основе sparse_swap.sh.
# Cоздаёт 4 файла и объединяет в RAID1 через LVM
#
# Назначение: использование с ceph
#
# Hint: чтобы продолжать пользоваться скриптом оставьте на месте файлов
# софт-ссылки.
#
# 2023 (c) haegor
#

pvcreate='sudo pvcreate'
vgcreate='sudo vgcreate'
vgextend='sudo vgextend'
lvcreate='sudo lvcreate'
lvremove='sudo lvremove'

losetup='sudo losetup'

volumename='sparse_volume'
groupname='ceph'

file_tpl='/srv/ceph/volume_'

volsize=1024
volcount=4

case $1 in
'create')		# Создать файлы, подключить, собрать в RAID, натянуть VG и LV, создать своп, включить его.
  for i in `seq 0 ${volcount}`
  do
    volume_file="${file_tpl}${i}"

    echo "===== ${volume_file} ========================================================================"

    loop_file="/dev/loop${i}"

    [ -f "${volume_file}" ] && continue

    dd if=/dev/zero of="${volume_file}" bs=1M count=${volsize} && echo "----- dd completed"
    ${losetup} "${loop_file}" "${volume_file}" && echo "----- losetup completed"

    if [ ${i} -eq 1 ]
    then
      ${pvcreate} "${loop_file}" && echo "----- pvcreate completed"
      ${vgcreate} ${groupname} "${loop_file}" && echo "----- vgcreate completed"
    else
      ${pvcreate} "${loop_file}" && echo "----- pvcreate competed"
      ${vgextend} ${groupname} "${loop_file}" && echo "----- vgextend completed"
    fi
  done
;;
'attach')		# TODO: Собрать logicalVolume из созданных ранее файлов
  echo empty
;;
'remove'|'rm')		# Удалить logicalVolume
  ${lvremove} ${groupname}/${volumename}
;;
'detach')		# Отключить loop-устройства. Возможно только после удаления logicalVolume
  for i in `seq 0 ${volcount}`
  do
    ${losetup} --detach /dev/loop${i}
  done
;;
'look'|'ls')		# Посмотреть что получилось
  echo "--- losetup ---"
  ${losetup}

  echo "--- LVS ---"
  sudo lvs 2>/dev/null | grep -P "${volumename}|LV"
  echo "--- VGS ---"
  sudo vgs 2>/dev/null | grep -P "${groupname}|VG"
  echo "--- PVS ---"
  sudo pvs 2>/dev/null | grep -P "${groupname}|PV"
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
  echo
  echo "$0 <create|remove|detach|look|help>"
  echo "В качестве параметра скрипта указывается его режим."
  echo
  echo "Перечень режимов:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac

