#!/bin/bash
#
# Скрипт полуавтоматической миграции с microsd на 1Tb nvme с созданием lvm для
# Raspberry Pi 4B.
# Подразумевает запуск под root.
#
# 2024 (c) haegor
#
# TODO дописать sudo составляющую.
#

# Ручник.
echo "ВАЖНО: Скрипт может нанести непоправимые повреждения данным !!!!"
echo "Сначала посмотрите его и лишь потом снимайте с ручника."
echo "DANGER! SCRIPT CAN HARM YOUR DATA !!!!"
echo "Remove hand-brake only after you check it first !!!!"
exit 0

# TODO Надо ещё сделать прописывание в /boot/firmware/config.txt
# НО! Важно помнить, что:
# Загрузка по uuid - не работает. Вообще, даже без LVM.
# Зато работает по имени блочного устройства и PARTUUID.
# Последний выдаётся только primary партициям.
# Но если подсовывать устройство дев-маппера (/dev/mapper/storage-root) для
# LVM, то и оно не сработает. При этом остальные спокойно подключает.

#  А вообще, вроде как, лучше всего использовать sgdisk для gpt партиций
parted='sudo parted'
#-s' # script or "silent"

disk_name='/dev/sda'
lvm_vg_name='storage'

# Вот казалось бы - кроха, а сократила код строк на 50
f_write2fstab () {
  local uuid="$1"
  local tail="$2"

  local isInFSTAB=$(cat /etc/fstab | grep ^UUID=\"$uuid\")
  [ -z "$isInFSTAB" ] \
    && echo -e "UUID=\"$uuid\" $tail" >> "/etc/fstab"
  return 0
}

f_get_vol_uuid () {
  local volume="$1"

  # Пример строки: /dev/sda2: UUID="748f85a9-48d4-475a-ace0-7986d176537c"
  local blk_output=$(blkid --match-tag=UUID ${volume})
  local cut_uuid=${blk_output#"$volume: UUID="}
  local uuid=${cut_uuid:1:-1}

  [ -z "$uuid" ] && return 1 || echo $uuid
  return 0
}

case $1 in
'print')				# Вывести список партиций на диске
  $parted $disk_name print
  echo "===== LVM ====="
  pvs; vgs; lvs
  # echo lsblk --list --noheadings "${part_name}"
;;
'ls-pv')				# Показать PV
  pvdisplay "$disk_name"
  echo "-----"
  pvs --all -v
;;
'ls-vg')				# Показать VG
  vgdisplay --verbose $lvm_vg_name
  echo "-----"
  vgs --all -v
;;
'ls-lv')				# Показать LV
  lvdisplay
  echo "-----"
  lvs --all -v
;;
'install-pkgs')				# Установить основные пакеты
  echo "===== Apt Update ====="
  apt update

  echo "===== Full Upgrade ====="
  apt full-upgrade
  #apt-get --force-yes full-upgrade

  echo "===== Install LVM+XFS ====="
  apt install xfsprogs lvm2
;;
'mk-firmware')				# Создать 1 раздел, для firmware
  $parted -a optimal $disk_name mkpart primary 0% 550MiB || exit 1
#  sgdisk --new=1:0%:550MiB /dev/sda
  mkfs.vfat "${disk_name}1" \
    && echo "Раздел для прошивки создан." \
    || echo "Ошибка при создании раздела прошивок."
  $0 print
;;
'mk-boot')				# Создать 2 раздел, для boot
  $parted -a optimal $disk_name mkpart primary 550MiB 2050MiB || exit 1
#  sgdisk --new=2:550MiB:2050MiB /dev/sda
  mkfs.ext4 "${disk_name}2" \
    && echo "Загрузочный раздел создан." \
    || echo "Ошибка при создании загрузочного раздела."
  $0 print
;;
'mk-root')				# Создать 3, рутовую партицию
  $parted -a optimal $disk_name mkpart primary 2050MiB 34050MiB || exit 1
#  sgdisk --new=3:2050MiB:34050MiB /dev/sda
  mkfs.ext4 "${disk_name}3" \
    && echo "Корневой раздел создан." \
    || echo "Ошибка при создании корневого раздела."
  $0 print
;;
'mk-main')				# Создать 4 партицию, для PV + добавить в VG
  $parted -a optimal $disk_name mkpart primary 34050MiB 1TB || exit 1
#  sgdisk --new=4:34050MiB:1TiB /dev/sda
  pvcreate "${disk_name}4" || exit 1
  vgcreate $lvm_vg_name "${disk_name}4" || exit 1
  echo "Раздел под LVM создан."
  $0 print
;;
'mk-base')				# Создать все 4 базовые партиции разом
  $0 mk-firmware #&> /dev/null
  $0 mk-boot #&> /dev/null
  $0 mk-root #&> /dev/null
  $0 mk-main #&> /dev/null
  $0 print
;;
'mk-lv')				# Создаёт LV на имеющейся VG
  lvcreate -L 10GB -n home $lvm_vg_name
  lvcreate -L 16GB -n var  $lvm_vg_name
  lvcreate -L 16GB -n swap $lvm_vg_name
  lvcreate -L 14GB -n opt  $lvm_vg_name
  partprobe
  echo "-----"
  $0 ls-lv
  echo "Теперь $0 mk-lv-fs ?"
;;
'mk-containers')			# Создание одного волюма - "containers" на 20% места
  lvm_lv_name='containers'
  lvcreate -l 20%FREE -n $lvm_lv_name $lvm_vg_name || exit 1
  mkfs.xfs "/dev/mapper/${lvm_vg_name}-${lvm_lv_name}"
;;
'mk-volumes')
  lvm_lv_name='volumes'
  lvcreate -l 20%FREE -n $lvm_lv_name $lvm_vg_name || exit 1
  mkfs.xfs "/dev/mapper/${lvm_vg_name}-${lvm_lv_name}"
;;
'mk-lv-fs')				# Создаёт FS на созданных LV
  exit 0	# Ручник. Эта секция форматирует диски!

  for volume in $(ls /dev/mapper/${lvm_vg_name}-*)
  do
    lv=${volume#/dev/mapper/${lvm_vg_name}-}

    [ "$lv" == "swap" ] && { mkswap    $volume || exit 1; }
    [ "$lv" == "opt" ]  && { mkfs.ext4 $volume || exit 1; }
    [ "$lv" == "var" ]  && { mkfs.xfs  $volume || exit 1; }
    [ "$lv" == "home" ] && { mkfs.xfs  $volume || exit 1; }
  done
;;
'migrate2nvme')				# Примонтировать, скопировать, подчистить root
  [ -d "/mnt/boot/firmware" ] && mkdir -p /mnt/boot/firmware \
    || { echo "Нельзя создать папку под будущую boot партицию."; exit 1; }

  mount -t ext4 ${disk_name}2 /mnt/boot 2> /dev/null         || exit 1
  mount -t vfat ${disk_name}1 /mnt/boot/firmware 2>/dev/null || exit 1
  mount -t ext4 ${disk_name}3 /mnt/root 2>/dev/null          || exit 1

  echo "Rsync of firmware"
  rsync -arx /boot/firmware/ /mnt/boot/firmware/ || exit 1

  echo "Rsync of boot"
  rsync -arx /boot/ /mnt/boot/ || exit 1

  echo "Rsync of root"
  rsync -arx \
    --exclude='/opt/*' --exclude='/home/*' \
    --exclude='/var/*' --exclude='/boot/*' \
    / /mnt/root/ || exit 1

  # Вычисляем список томов, создаём под них папки, монтируем и rsync-аем
  for volume in $(ls /dev/mapper/${lvm_vg_name}-*)
  do
    lv=${volume#/dev/mapper/${lvm_vg_name}-}
    echo "LV: $lv"

    [ -d "/mnt/$lv" ] && { mkdir -p "/mnt/$lv" || exit 1; }
    mount $volume "/mnt/$lv" 2> /dev/null || exit 1

    [ "$lv" == 'swap' ] && continue

    [ -d "/$lv" ] && rsync -arx "/$lv/" "/mnt/$lv/"
  done
;;
'complete-del'|'complete-rm')		# excluder "Секретный уровень". Удалит все три партиции с диска
  exit 0				# Ручник. ОПАСНО!!! Реально всё удалит. В клочья прям. По настоящему.
  umount ${disk_name}*
  umount /dev/mapper/${lvm_vg_name}-*
  $0 deactivate			# Деактивация LV
  vgremove $lvm_vg_name
  pvremove ${disk_name}*
  sgdisk -Z /dev/sda		# Удаляет MBR и таблицу GPT
  sgdisk -o /dev/sda		# Создаёт новые MBR и таблицу GPT

  # for i in $(seq 1 4); do $parted $disk_name rm $i; done
  $0 print
;;
'nvme2fstab')				# Прописывает LV в fstab
  echo "Раздел firmware: ${disk_name}1"
  uuid_p1=$(f_get_vol_uuid "${disk_name}1")
  f_write2fstab "$uuid_p1" '\t\t\t\t/boot/firmware	vfat	defaults	0 2'

  echo "Раздел boot: ${disk_name}2"
  uuid_p2=$(f_get_vol_uuid "${disk_name}2")
  f_write2fstab "$uuid_p2" '\t/boot	ext4	defaults,noatime	0 1'

  echo "Раздел root: ${disk_name}3"
  uuid_p3=$(f_get_vol_uuid "${disk_name}3")
  f_write2fstab "$uuid_p3" '\t/		ext4	defaults,noatime	0 1'

  for volume in $(ls /dev/mapper/${lvm_vg_name}-*)
  do
    echo "Проходимся по тому: $volume"
    lv=${volume#/dev/mapper/${lvm_vg_name}-}
    uuid=$(f_get_vol_uuid "${volume}")

    [ -z "$uuid" ] && { echo "UUID пуст. Возможно вы не создали файловую систему на томе $volume" && continue; }

    [ "$lv" == "swap" ] && { f_write2fstab "$uuid" '\tnone	swap	sw			0 0' && continue; }
    [ "$lv" == "opt" ]  && { f_write2fstab "$uuid" '\t/opt	ext4	defaults,noatime	0 0' && continue; }
    [ "$lv" == "var" ]  && { f_write2fstab "$uuid" '\t/var	xfs	defaults,noatime	0 0' && continue; }
    [ "$lv" == "home" ] && { f_write2fstab "$uuid" '\t/home	xfs	defaults,noatime	0 0' && continue; }
    [ "$lv" == "containers" ] && { f_write2fstab "$uuid" '\t/srv/containers/\txfs\tdefaults,noatime\t0 0'; \
      mkdir -p "/srv/containers"; continue; }
    [ "$lv" == "volumes" ] && { f_write2fstab "$uuid" '\t/srv/volumes/\txfs\tdefaults,noatime\t0 0'; \
      mkdir -p "/srv/volumes"; continue; }
  done

  echo "Перезапуск systemd"	# Пересоздаст *.mount
  systemctl daemon-reload	
;;
'probe'|'pp'|'refresh')			# refresh part table
  partprobe
;;
'activate-ls')				# Activate LVs. Search by LS
  # Так себе способ, но оставил на случай отсутствия jq
  for volume in $(ls /dev/mapper/${lvm_vg_name}-*)
  do
    lv=${volume#/dev/mapper/${lvm_vg_name}-}
    echo "Activate LV: $lv"
    lvchange -aay ${lvm_vg_name}/${lv}
  done
  echo "Активация завершена"
;;
'activate')				# Activate LVs. Search by LVS
  lvs=$(lvs --noheadings --reportformat json | jq '.report[0].lv | .[] | .vg_name + "/" + .lv_name')
  for i in $lvs
  do
    echo "Activate LV: $i"
    lvchange -aay ${i:1:-1}
  done
  echo "Активация завершена"
;;
'deactivate')				# Деактивация LV
  lvs=$(lvs --noheadings --reportformat json | jq '.report[0].lv | .[] | .vg_name + "/" + .lv_name')
  for i in $lvs
  do
    echo "DEactivate LV: $i"
    lvchange -an ${i:1:-1}
  done
  echo "ДЕактивация завершена"
;;
'rebuild-initramfs')			# Переделать initrafs, чтобы драйверы LVM грузились на правильной стадии.
# Эта часть нужна на тот случай, если что-то пойдёт не так и при старте rpi
# не захочет автоматически монтировать тома LVM. Если так происходит, то это
# из-за того что не срабатывает автоматическая активация томов.
# А она не происходит потому что во время загрузки попытка их активации
# происходит не в положенное время, до того как загрузятся драйверы LVM.
# Именно это подразумевает systemd когда вещает о каких-то непонятных
# "зависимостях".
#
# Подспорье: https://gist.github.com/ArcezD/c8df7b8a5735c884b927b36c6cc73006
# TODO ЭТА ЧАСТЬ НЕ ПРОВЕРЯЛАСЬ НА РАБОТОСПОСОБНОСТЬ. Всё должно работать, но
# не факт что будет.

  exit 0

  # Пример: 6.1.0-rpi8-rpi-v8
  version=$(uname -r)

  $0 install-pkgs

  echo "===== Install tools ====="
  apt install initramfs-tools

  # Если при генерации mkinitramfs появится ошибка:
  # grep: /boot/config-6.6.18-v8+: No such file or directory
  # W: zstd compression (CONFIG_RD_ZSTD) not supported by kernel, using gzip
  # grep: /boot/config-6.6.18-v8+: No such file or directory
  # E: gzip compression (CONFIG_RD_GZIP) not supported by kernel
  # ... то скорее всего это говорит об отсутствии config-а для текущего initrd.
  # Его могли не положить во время обновления ядра при обновлении пакетов.
  # При этом, если взять "старый" конфиг, то mkinitramfs станет ругаться на компрессию.

  if [ ! -f "/boot/config-$version" ]
  then
    # Делаем доступным конфиг текущего ядра в proc
    modprobe configs || { echo "Нельзя посмотреть конфиг текущего ядра." && exit 1; }
    echo zcat /proc/config.gz > /boot/config-$version
  else
    echo "Конфиг для текущей версии ядра ($version) уже существует."
  fi

  # Будем убирать лишние модули?
  # /etc/initramfs-tools/initramfs.conf
  # rpi ~# sed -i 's/^MODULES=most/MODULES=list/' /etc/initramfs-tools/initramfs.conf

  initram_config='/etc/initramfs-tools/initramfs.conf'
  if [ ! "$(grep '^COMPRESS' $initram_config)" == "COMPRESS=xz" ]
  then
    # TODO проверить как работает маска. Если чё, то можно всю строку заменить.
    echo sed -i s/COMPRESS=*/COMPRESS=xz/ $initram_config
  fi

  [ ! -f "/boot/initrd.img-$version" ] \
    && echo mkinitramfs -o /boot/initrd.img-$version \
    || echo "Такой initrd уже существует."

  boot_config='/boot/firmware/config.txt'
  if [ -z "$(grep -n '\[rpi4\]' $boot_config | cut -f1 -d:)" ]
  then
    # TODO отладить
    # Тут sed-ом вставляем пару строк ДО секции all:
    #[pi4]
    #initramfs initrd.img-$version followkernel
    # Так мы указываем конкретную версию загружаемого initrd. То что только что создали.

    let line_section4all=$(grep -n '\[all\]' $boot_config | cut -f1 -d:)-1

    # TODO вот тут дописать.
    # sed "a,$line_section4all" "[pi4]" /boot/firmware/config.txt
    # sed "a,$line_section4all" "initramfs initrd.img-$version followkernel" /boot/firmware/config.txt
  fi
;;
'--help'|'-help'|'help'|'-h'|*|'')	# Автопомощь. Мы тут.
  echo
  echo "ВАЖНО: почти всё берётся из преднастроек. Сначала смотрите что прописано и лишь потом запускайте."
  echo "ТОЖЕ ВАЖНО: В скрипте полно ручников. Многие функции отключены 'во избежание'. Сначала смотрите"
  echo "и только потом комментируйте 'exit 0'."
  echo
  echo "Недостаточно параметров или они неверно указаны."
  echo
  echo "$0 <РЕЖИМ|help>"
  echo "В качестве параметра скрипта указывается его режим."
  echo
  echo "Перечень режимов:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac
