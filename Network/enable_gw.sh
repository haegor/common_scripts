#!/bin/bash
# -x
#
# Скрипт для включения форвардинга на хосте для списка определённых хостов.
#
# 2024 (c) haegor
#

iptables='echo sudo iptables'
#iptables='sudo iptables'

inet_ip='8.8.8.8'

# Будет грузить хосты из файла enable_gw_hosts
hosts="$(cat ./${0:0:-3}_hosts)"

# А ещё можно вот так, чтобы одним файлом:
#hosts=$(cat << EOF
#192.168.0.1
#192.168.0.2
#192.168.0.3
#EOF
#)

# Столь лаконичное название исключительно ради лаконичности самих правил.
# Постоянно дёргать ip route - нормально, он же кеширует записи.
f_get () {
  set -			# Для удобства отладки
  local info_type="$1"
  local target_ip="$2"

  # При запросе 8.8.8.8 выдаст:
  #8.8.8.8 via 192.168.0.1 dev eth0 src 192.168.0.100 uid 1000
  local def_route=$(ip r get ${target_ip} | grep ${target_ip})

  # Вот тут особо важно: БЕЗ КОВЫЧЕК. Каждая линия должна быть отдельным словом.
  for word in $def_route
  do
    [ "$next_word_is_devname" == "1" ] && out_dev=$word
    [ "$word" == 'dev' ] && next_word_is_devname=1 || next_word_is_devname=0

    [ "$next_word_is_src" == "1" ] && src_ip=$word
    [ "$word" == 'src' ] && next_word_is_src=1 || next_word_is_src=0
  done

  [ "$info_type" == 'both' ] \
    && { echo "$iface_out $out_ip"; return 0; }
  [ "$info_type" == 'dev' ] && echo $out_dev
  [ "$info_type" == 'ip' ] && echo $src_ip
}

case $1 in
'yes'|'on'|'1'|'true')				# Включить форвардинг
  sudo sysctl -w "net.ipv4.conf.all.forwarding=1"
  # Снимаем запреты чтобы соблюсти очерёдность правил при добавлении форвардинга
  $iptables -D FORWARD -i lo -j REJECT --reject-with icmp-host-prohibited
  $iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited

  # Вот этого форвардинга
  while read LINE
  do
    $iptables -A FORWARD -i $(f_get dev $LINE) -o $(f_get dev $inet_ip) -s $LINE/32 -j ACCEPT
    $iptables -A FORWARD -i $(f_get dev $inet_ip) -o $(f_get dev $LINE) -d $LINE/32 -j ACCEPT
  done < <(echo "$hosts")

  # Возвращаем запреты
  $iptables -A FORWARD -i lo -j REJECT --reject-with icmp-host-prohibited
  $iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited

  while read LINE
  do
    $iptables -t nat -A POSTROUTING -s $LINE/32 -o $(f_get dev $inet_ip) -j SNAT --to-source=$(f_get ip $inet_ip)

    # А вот строка для DNAT, если будет нужен.
    # $iptables -t nat -A PREROUTING -d $(f_get dev $inet_ip)/32 -i $(f_get dev $inet_ip) -j DNAT --to-destination=$(f_get ip $LINE)/32
  done < <(echo "$hosts")

  echo "Форвардинг включен."
;;
'no'|'off'|'0'|'false')				# Выключить форвардинг
  sudo sysctl -w "net.ipv4.conf.all.forwarding=0"
  sudo iptables-restore /etc/sysconfig/iptables
  echo "Форвард и NAT отключены"
;;
'--help'|'-help'|'help'|'-h'|*|'')		# Автопомощь. Мы тут.
  echo
  echo "Недостаточно параметров или они неверно указаны."
  echo "В качестве обязательного параметра указывается его режим."
  echo
  echo "$0 <on|off|help>"
  echo
  echo "При этом список хостов передаётся через файл ${0:0:-3}_hosts"
  echo
  echo "Полный перечень режимов:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac
