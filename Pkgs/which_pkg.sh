#!/bin/bash
#
# Проблема: узнать каким пакетом был установлен файл.
# Наглядно её можно увидеть на примере:
#
# haegor@vetinari:~/$ dpkg -S "$(which bash)"
# dpkg-query: не найден путь, подходящий под шаблон /usr/bin/bash
# haegor@vetinari:~/$ ls -la /usr/bin/bash
# -rwxr-xr-x 1 root root 1183448 апр 18  2022 /usr/bin/bash
# haegor@vetinari:~/$ ls -la /bin
# lrwxrwxrwx 1 root root 7 июл 28  2021 /bin -> usr/bin
# haegor@vetinari:~/$ dpkg -S /bin/bash
# bash: /bin/bash
#
# Другой пример:
# haegor@vetinari:~/$ dpkg -S /usr/sbin/blockdev
# dpkg-query: не найден путь, подходящий под шаблон /usr/sbin/blockdev
# haegor@vetinari:~/$ ls -lad /sbin
# lrwxrwxrwx 1 root root 8 июл 28  2021 /sbin -> usr/sbin
# haegor@vetinari:~/$ dpkg -S "/sbin/blockdev"
# util-linux: /sbin/blockdev
# 
# Т.е. для поиска пакета из которого был установлен bash больше нельзя
# напрямую использовать which. Для исправления ситуации и написан сей скрипт.
#
# 2024 (c) haegor
#

[ -n "$1" ] && file="$1" || { echo "Вы не указали искомый бинарник"; exit 0; }

binary=$(which $1)
[ -z "$binary" ] && { echo "Бинарник $1 не доступен через переменную \$PATH"; exit 0; }

binary_rp=$(realpath "$binary") \
  || { echo "Невозможно определить реальный путь до $binary"; exit 0; }

allIsSimple=$(dpkg -S "$binary_rp")
if [ -n "$allIsSimple" ]
then
  echo "Простой случай. Прямой поиск дал искомый пакет:"
  echo "$allIsSimple"
  exit 0
fi

# Вот тут мы достаём список ссылок на директории из пакета с файлами для рутовой партиции
while read basefile
do
  ( [ -L "$basefile" ] && [ -d "$basefile" ] ) \
    && linked_base_dirs[${#linked_base_dirs[@]}]="$basefile"
done < <(sudo dpkg -L base-files)

for link in ${linked_base_dirs[*]}
do
  link_rp=$(realpath "$link")

  bin_name=${binary_rp#"$link_rp"}	# Удаляем директорию
  bin_name=${bin_name:1}			# Удаляем /

  compensated_bin_path="$link/$bin_name"

  dpkg_result=$(dpkg -S "$compensated_bin_path" 2>&1)
  if [[ ! "${dpkg_result}" =~ ^dpkg\-query\: ]]
  then
    # TODO вот тут нужно проконтролить всякие предложения от dpkg. Приоритет минимальный.
    echo "Успешно для : $link:"
    echo "$dpkg_result"
    job_is_done='true'
    break
  fi
done

if [ ! "$job_is_done" == 'true' ]
then
  echo "Среди ссылок пакета с базовыми файлами рутовой партиции ничего не найдено."
fi

