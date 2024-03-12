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
# TODO: ВАЖНО: при написании скрипта подразумевалось что все loop устройства не
# заняты. Проверок на их наличие нет.
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
swapoff='sudo swapoff'

volumename='volname'
groupname='groupname'
cachevol='cache_volume'

file_tpl='./volume_'
cache_file='./volume_cache'
devmapper_file="/dev/mapper/${groupname}-${volumename}"

volsize=512
volcount=5		#ВАЖНО: volcount не может быть больше 7и.

case $1 in
'create')				# Создать файлы, подключить, собрать в RAID, натянуть VG и LV, создать своп, включить его.
  for i in `seq 0 ${volcount}`
  do
    volume_file="${file_tpl}${i}"
    [ ${i} -eq ${volcount} ] && volume_file="${cache_file}"

    echo "===== ${volume_file} ========================================================================"

    loop_file="/dev/loop${i}"

    [ -f "${volume_file}" ] && continue

    dd if=/dev/zero of="${volume_file}" bs=1M count=${volsize} && echo "----- dd completed"
    ${losetup} "${loop_file}" "${volume_file}" && echo "----- losetup completed"

    if [ ${i} -eq 1 ]
    then
      ${pvcreate} "${loop_file}" && echo "----- pvcreate completed"
      ${vgcreate} ${groupname} "${loop_file}" && echo "----- vgcreate completed"
    elif [ ${i} -lt ${volcount} ] && [ ${i} -gt 1 ]
    then
      ${pvcreate} "${loop_file}" && echo "----- pvcreate competed"
      ${vgextend} ${groupname} "${loop_file}" && echo "----- vgextend completed"
    elif [ ${i} -eq ${volcount} ]
    then
      ${lvcreate} --type raid1 -l 100%FREE -n ${volumename} ${groupname} && echo "----- lvcreate completed"
      ${vgextend} ${groupname} "${loop_file}" && echo "----- vgextend completed"
      ${lvcreate} -n ${cachevol} -l 100%FREE ${groupname} ${loop_file} && echo "----- vgcreate-cache completed"
      ${lvconvert} -y --type cache --cachesettings block_size=4096 --chunksize 1024 --cachepolicy smq --cachevol ${cachevol} ${groupname}/${volumename} && echo "----- lvconvert completed"
    fi
  done

  ${mkswap} "${devmapper_file}"
  ${swapon} "${devmapper_file}"
;;
'attach')				# TODO: Собрать logicalVolume из созданных ранее файлов
  echo empty
;;
'remove'|'rm')				# Отцепит swap и удалит его logicalVolume
  inode=$(stat -L -c %i ${devmapper_file}) 		# без -L будет inode ссылки, которая тоже файл
  dm_file=$(sudo find /dev/ -maxdepth 1 -inum ${inode})

  [ ! "$(${swapon} | grep ${dm_file})" == '' ] && ${swapoff} "${devmapper_file}" && echo "swapoff ${devmapper_file} прошёл успешно"

  ${lvremove} ${groupname}/${volumename}
;;
'detach')				# Отключить loop-устройства. Возможно только после удаления logicalVolume
  for i in `seq 0 ${volcount}`
  do
    ${losetup} --detach /dev/loop${i}
  done
;;
'swapon')				# Подключить созданный диск как swap
  ${mkswap} "${devmapper_file}"
  ${swapon} "${devmapper_file}"
;;
'look'|'ls')				# Посмотреть что получилось
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
