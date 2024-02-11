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
'about')				# О Скрипте
  comment_brace=0

  while read LINE
  do
    if [[ "$LINE" == "#" ]] && [ $comment_brace -eq 0 ]      # Начало коммента
    then
      comment_brace=1
      echo -e "\n  О скрипте\n"
    elif [ "${LINE:16:21}" != 'haegor' ] && [ $comment_brace -eq 1 ]    # Текст коммента
    then
      echo "  ${LINE:2}"
    elif [ "${LINE:16:21}" == 'haegor' ] && [ $comment_brace -eq 1 ]    # Закрытие
    then
      echo -e "  ${LINE:2}\n"
      exit 0
    fi
  done < <(cat "$0")
;;
'--help'|'-help'|'help'|'-h'|'')	# Автопомощь. Мы тут.
  echo
  echo "Недостаточно параметров или они неверно указаны."
  echo "Cледует указать интересующий GROUP/VOLUME. Должно получиться что-то вроде:"
  echo "	$0 'GROUP/VOLUME'"
  echo
  echo "Таже можно указать ключевое слово all чтобы показать статистику для всех доступных волюмов"
  echo
  echo "Перечень режимов:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
*)
    if [ ! "$1" ]
    then
      $0 help
      exit 0
    fi

    echo "Подсчёт рациональности для: $1"
    f_get $1
;;
esac



