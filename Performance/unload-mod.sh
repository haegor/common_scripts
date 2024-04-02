#!/bin/bash
#
# Скрипт для выгрузки модулей ядра.
#
# 2024 (c) haegor
#

fs_modules=$(cat << EOF
nvme_fabrics
nvme_core
hfs
hfsplus
jfs
ntfs
minix
qnx4
btrfs
EOF
)

net_modules=$(cat << EOF
iptable_nat
nf_nat
nf_conntrack_ipv4
nf_defrag_ipv4
nf_conntrack
EOF
)

case $1 in
'unload-fs')			# Выгружает самые неиспользуемые FS модули
  for i in $fs_modules
  do
    sudo rmmod $i
  done
;;
'unload-net')			# Выгружает модули затормаживающие сеть. Несовместимо с k8s.
  for i in $net_modules
  do
    sudo rmmod $i
  done
;;
'list'|'ls')			# Вывести список всех загруженных модулей
  sudo lsmod
;;
'permanent'|'perm')		#
#TODO Вот тут нужно делать изменения перманентными. Что-то вроде вычёркивания из /etc/modules
  :
;;
esac
