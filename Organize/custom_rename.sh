#!/bin/bash
#
# Заготовки для неочевидного ренейминга
#
# 2023 (с) haegor
#

# Сначала изучи содержимое файла, закомментируй лишнее и только потом комментируй эту строку
exit 0


# Отрезать последние N символов у каждого файла, совпадающего с шаблоном, в текущей папке.
# На примере отрезания расширения .sh у всех скриптов в текущей папке
template="*.sh"
N=3

while read i
do
  truncated=${i:0:${#i}-${N}}
  mv "${i}" "${truncated}"
done < <(find . -name "${template}")