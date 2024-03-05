#!/bin/bash
#
# Скрипт для включения форвардинга на хосте для списка предопределённых хостов.
#
# 2024 (c) haegor
#

#iptables='echo DEBUG sudo iptables'
iptables='sudo iptables'

f_read_args () {
#D  set -x
  local next_value_isTarget=0

  isDNAT=0
  isSNAT=0
  isMASQ=0

  for LINE in $@
  do
    [ "$next_value_isTarget" == '1' ] && dest_ip="$LINE"

    [ "$LINE" == '-t' ] \
      && next_value_isTarget=1 \
      || next_value_isTarget=0

    [ "$LINE" == '-d' ] && isDNAT=1
    [ "$LINE" == '-s' ] && isSNAT=1
    [ "$LINE" == '-m' ] && isMASQ=1
  done

  [ -z "$dest_ip" ] && dest_ip='8.8.8.8'
#D  set -
}

f_read_file () {
  # Будет грузить хосты из файла enable_gw_hosts
  hosts="$(cat ./${0:0:-3}_hosts 2>/dev/null)"  || return 1

# А ещё можно вот так, чтобы одним файлом:
#hosts=$(cat << EOF
#192.168.0.1
#192.168.0.2
#192.168.0.3
#EOF
#)
}

# Столь лаконичное название исключительно ради лаконичности самих правил.
# Постоянно дёргать ip route - нормально, он же кеширует записи.
f_get () {
  local info_type="$1"
  local target_ip="$2"

  # При запросе 8.8.8.8 выдаст:
  #8.8.8.8 via 192.168.0.1 dev eth0 src 192.168.0.100 uid 1000
  local def_route=$(ip r get ${target_ip} | grep ${target_ip})

  # Вот тут особо важно: def_route - БЕЗ КОВЫЧЕК. Каждая линия должна быть отдельным словом.
  for word in $def_route
  do
    [ "$next_word_is_devname" == "1" ] && out_dev=$word
    [ "$word" == 'dev' ] && next_word_is_devname=1 || next_word_is_devname=0

    [ "$next_word_is_src" == "1" ] && src_ip=$word
    [ "$word" == 'src' ] && next_word_is_src=1     || next_word_is_src=0
  done

  [ "$info_type" == 'dev' ] && echo $out_dev
  [ "$info_type" == 'ip' ] && echo $src_ip
  [ "$info_type" == 'both' ] \
    && { echo "$iface_out $out_ip"; return 0; }
}

case $1 in
'enable'|'yes'|'on'|'1'|'true')			# Включить форвардинг
  sudo sysctl -w "net.ipv4.conf.all.forwarding=1"
  # Пока без операций с запретами, а то всё может отвалиться. Во избежание так сказать
  #
  # Снимаем запреты чтобы соблюсти очерёдность правил при добавлении форвардинга
  # $iptables -D FORWARD -i lo -j REJECT --reject-with icmp-host-prohibited
  # $iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited

  f_read_args "$@"
  f_read_file || { echo "Файл с перечнем хостов не найден" && exit 1; }

  # Вот этого форвардинга
  while read LINE
  do
    $iptables -A FORWARD -i $(f_get dev $LINE) -o $(f_get dev $dest_ip) -s $LINE/32 -j ACCEPT
    $iptables -A FORWARD -i $(f_get dev $dest_ip) -o $(f_get dev $LINE) -d $LINE/32 -j ACCEPT
    echo "Форвардинг включён"
  done < <(echo "$hosts")

  # Возвращаем запреты
  # $iptables -A FORWARD -i lo -j REJECT --reject-with icmp-host-prohibited
  # $iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited

  while read LINE
  do
    [ "$isSNAT" == '1' ] && { \
      $iptables -t nat -A POSTROUTING -s $LINE/32 -o $(f_get dev $dest_ip) -j SNAT --to-source=$(f_get ip $dest_ip); \
      echo "SNAT включён"; \
    }

    [ "$isDNAT" == '1' ] && { \
      $iptables -t nat -A PREROUTING -d $(f_get ip $dest_ip)/32 -i $(f_get dev $dest_ip) -j DNAT --to-destination=$LINE; \
      echo "DNAT включён"; \
    }

    [ "$isMASQ" == '1' ] && { \
      $iptables -t nat -A POSTROUTING -p tcp -o $(f_get dev $dest_ip) -j MASQUERADE; \
      echo "MASQUERADE включён"; \
    }
  done < <(echo "$hosts")
;;
'disable'|'no'|'off'|'0'|'false')		# Выключить форвардинг
  sudo sysctl -w "net.ipv4.conf.all.forwarding=0"
#  sudo iptables-restore /etc/sysconfig/iptables
  sudo iptables-restore /opt/scripts/ipt_empty
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
