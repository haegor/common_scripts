#!/bin/bash
#
# Скрипт подсчёта эффективности ssd-кэша, подключённого к lvm-raid.
# Для вычислений задействован python. Отсюда зависимость.
# Даже не спрашивайте зачем.
#
# 2022,2024 (c) haegor
#

python_cmd="python3"

f_get () {
  reads=$(sudo lvdisplay "$1" 2>/dev/null | grep "Cache read hits/misses")
  writes=$(sudo lvdisplay "$1" 2>/dev/null | grep "Cache wrt hits/misses")

  read_hits=$(echo "${reads}" | awk '{print $4}')
  read_misses=$(echo "${reads}" | awk '{print $6}')

  write_hits=$(echo "${writes}" | awk '{print $4}')
  write_misses=$(echo "${writes}" | awk '{print $6}')

  read_ratio=$(${python_cmd} -c "print (${read_hits}/(${read_hits} + ${read_misses}.))")
  write_ratio=$(${python_cmd} -c "print (${write_hits}/(${write_hits} + ${write_misses}.))")

  echo "$1 read_ratio $read_ratio"
  echo "$1 write_ratio $write_ratio"
}

case $1 in
'help')
    echo "В качесте аргумента следует указать интересующий GROUP/VOLUME"
    echo "Должно получиться что-то вроде: $0 'GROUP/VOLUME'"
    exit 0
;;
'all')
    volumes=$(sudo lvs --select pool_lv=~'.*_cvol' -o vg_name,lv_name --noheadings 2>/dev/null)
    while read LINE
    do
      curr_volume=$(echo $LINE | tr -s '[:blank:]' )
      curr_volume=$(echo $curr_volume | tr '[:blank:]' '/' )
      echo "Подсчёт рациональности для: $curr_volume"
      f_get "$curr_volume"
      echo
    done < <(echo "$volumes")
;;
*)
    echo "Подсчёт рациональности для: $1"
    f_get $1
;;
esac



