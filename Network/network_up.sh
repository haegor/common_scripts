#!/bin/bash
#
# Скрипт гасит NetworkManager, отделяет физические сетевые интерфейсы от
# виртуальных, создаёт под них DHCP-конфигурацию и включает. Все, кроме "wlan*".
#
# Скрипт предназначен для запуска по крону и нужен в первую очень для
# поддержания интерфейсов в поднятом состоянии.
#
# При этом он не зависит ни от количества интерфейсов, ни от их наименования.
#
# 2024 (c) haegor
#

systemctl='sudo systemctl'
interfaces="/etc/network/interfaces"

f_enableIface () {
  local iface="$1"

  local isWritten=$(cat "$interfaces" | grep "iface $iface inet dhcp")
  [ -z "$isWritten" ] \
    && echo "iface $iface inet dhcp" >> $interfaces

  local isEnabled=$(ifquery --state $iface)
  [ -z "$isEnabled" ] && ifup $iface

  return 0
}

if [ "$($systemctl is-enabled NetworkManager)" == 'enabled' ]
then
  $systemctl disable --now NetworkManager
fi

ifaces_full_list=$(ls /sys/class/net)
ifaces_virt_list=$(ls /sys/devices/virtual/net)

for i in $ifaces_full_list
do
  virtual=0
  for virt in $ifaces_virt_list
  do
    # TODO по хорошему бы ещё массив ifaces_full_list уменьшать при каждом срабатывании, но пока так.
    [ "$i" == "$virt" ] && { virtual=1; break ;}
  done

  [ $virtual == 0 ] && physical[${#physical[@]}]="$i"
done

for i in ${physical[*]}
do
  [ "${i:0:4}" == 'wlan' ] && continue
  # Если раскомментировать, то при запуске через cron админу будут приходить письма с этими строками
  # echo "Обрабатываем интерфейс: $i"
  f_enableIface "$i"
done
