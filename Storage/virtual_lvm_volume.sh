#!/bin/bash
#
# Создаёт файл, организует в нём LVM структуру и подключает.
# Используется чтобы потом скормить всё это какой-нить службе, вроде ceph.
# Зачем LVM? Чтобы можно было потом наращивать хранилище добавлением новых PV.
#
# 2023 (c) haegor
#

losetup='sudo losetup'
pvcreate='sudo pvcreate'
vgcreate='sudo vgcreate'
lvcreate='sudo lvcreate'
lvremove='sudo lvremove'

volumename='ceph-vol'
groupname='ceph'
volume_file='/srv/ceph/ceph_volume'
loop_file='/dev/loop1'
size=1024
devmapper_file="/dev/mapper/${groupname}-${volumename}"

case $1 in
'create')				# Создать
  [ ! -f "${volume_file}" ] && dd if=/dev/zero of="${volume_file}" bs=1M count=${size}

  already_looped_at=$(${losetup} | grep "${volume_file}" | cut -f1 -d' ')
  echo $already_looped_at

  [ ! "${already_looped_at}" == "${loop_file}" ] && ${losetup} "${loop_file}" "${volume_file}"

  ${pvcreate} "${loop_file}"
  ${vgcreate} "${groupname}" "${loop_file}"
  ${lvcreate} -l 100%FREE -n "${volumename}" "${groupname}"
;;
'detach')				# Отключить
#  inode=$(stat -L -c %i ${devmapper_file})              # без -L будет inode ссылки, которая тоже файл
#  dm_file=$(sudo find /dev/ -maxdepth 1 -inum ${inode})
#  [ ! "$(${swapon}  | grep ${dm_file})" == '' ] && ${swapoff} "${devmapper_file}" && echo "swapoff ${devmapper_file} прошёл успешно"

  ${lvremove} ${groupname}/${volumename}
  ${losetup} --detach "${loop_file}"
;;
'look'|'ls')				# Осмотреться
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
  echo "$0 <create|detach|look|help>"
  echo "В качестве параметра скрипта указывается его режим."
  echo
  echo "Перечень режимов:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
esac

