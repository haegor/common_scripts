#!/bin/bash
#
# Этот мелкий скрипт создаст 5 файлов и объединит их единой LVM-конфигурацией.
# Из 4х он создаст RAID 1 (stripe), а пятую подключит как кэш.
#
# Сперва кажется что скрипт создан ради баловства. Но растащите файлы по
# разным SATA-партициям, а cache положите на SSD или NVME и он заиграет иными
# красками.
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
lvconvert='sudo lvconvert'

losetup='sudo losetup'
mkswap='sudo mkswap'
swapon='sudo swapon'

volumename='volname'
groupname='groupname'
cachevol='cache_volume'

file_tpl='./volume_'
cache_file='./volume_cache'

volsize=512

case $1 in
'create')		# Создать файлы, подключить, собрать в RAID, натянуть VG и LV, создать своп, включить его.
  for i in `seq 1 5`
  do
    volume_file="${file_tpl}${i}"
    [ ${i} -eq 5 ] && volume_file="${cache_file}"

    echo "===== ${volume_file} ========================================================================"

    loop_file="/dev/loop${i}"

    [ -f "${volume_file}" ] && continue

    dd if=/dev/zero of="${volume_file}" bs=1M count=${volsize} && echo "----- dd completed"
    ${losetup} "${loop_file}" "${volume_file}" && echo "----- losetup completed"

    if [ ${i} -eq 1 ]
    then
      ${pvcreate} "${loop_file}" && echo "----- pvcreate completed"
      ${vgcreate} ${groupname} "${loop_file}" && echo "----- vgcreate completed"
    elif [ ${i} -lt 5 ] && [ ${i} -gt 1 ]
    then
      ${pvcreate} "${loop_file}" && echo "----- pvcreate competed"
      ${vgextend} ${groupname} "${loop_file}" && echo "----- vgextend completed"
    elif [ ${i} -eq 5 ]
    then
      ${lvcreate} --type raid1 -l 100%FREE -n ${volumename} ${groupname} && echo "----- lvcreate completed"
      ${vgextend} ${groupname} "${loop_file}" && echo "----- vgextend completed"
      ${lvcreate} -n ${cachevol} -l 100%FREE ${groupname} ${loop_file} && echo "----- vgcreate-cache completed"
      ${lvconvert} -y --type cache --cachesettings block_size=4096 --chunksize 1024 --cachepolicy smq --cachevol ${cachevol} ${groupname}/${volumename} && echo "----- lvconvert completed"
    fi
  done

  ${mkswap} /dev/mapper/${groupname}-${volumename}
  ${swapon} /dev/mapper/${groupname}-${volumename}
;;
'attach')		# TODO: Собрать logicalVolume из созданных ранее файлов
  echo empty
;;
'remove')		# Удалить logicalVolume
  ${lvremove} ${groupname}/${volumename}
;;
'detach')		# Отключить loop-устройства. Возможно только после удаления logicalVolume
  for i in `seq 1 5`
  do
    ${losetup} --detach /dev/loop${i}
  done
;;
'look')			# Посмотреть что получилось
  ${losetup}
  sudo pvs
  sudo lvs
  sudo vgs
;;
'--help'|'-help'|'help'|'-h'|*|'')	# Автопомощь. Мы тут.
  echo
  echo "Недостаточно параметров или они неверно указаны."
  echo
  echo "$0 <create|remove|detach|look>"
  echo "В качестве параметра скрипта указывается его режим."
  echo
  echo "Перечень режимов:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac
