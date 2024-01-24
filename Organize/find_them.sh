#!/bin/bash
#
# Скрипт предназначен для поиска файлов в целевой директории, названных в честь
# субдиректорий из указанной директории. Запутанно звучит, да? Сейчас поясню.
#
# Подразумевается что существует директория, в которой находятся субдиректории,
# названные в честь признака, по которому следует отобирать для них файлы.
#
# Например папка с музыкой, в которой файлы рассортированы по исполнителям.
# Скрипт сформирует список исполнителей из списка субдиректорий, замонстрячит
# из них маски и пойдёт искать по файламм в указанной директории. Конечно,
# исключая саму дирректорию с исполнителями.
# По нахождении, в директории затронутых исполнителей, он создаст субдирректорию,
# в которую сложит ссылки на все найденные файлы.
#
# Мановением руки (удалением -s) мягкие ссылки могут быть превращены в жёсткие,
# а заменой ln на mv файлы можно переместить.
#
# 2023 (c) haegor
#

help_msg () {
  echo
  echo "Полный формат таков:"
  echo "  $0 <целевая папка> [<директория с категориями>]"
  echo
  echo "Если второй параметр не указан, то будет использована дочерняя подпапка"
  echo "по умолчанию ('./By name')"
  echo
}

if [ $1 ]
then
  if [ ! -d ${target_dir} ]
  then
    echo
    echo "Указанной папки не существует!"
    help_msg
    exit 0
  fi

  target_dir=$1

else
  echo
  echo "Необходимо указать целевую папку!"
  help_msg
  exit 0
fi


[ $2 ] && categories_dir=$2 || categories_dir="${target_dir}/By name"

if [ ! -d "${categories_dir}" ]
then
  echo
  echo "Папки с категориями не существует!"
  help_msg
  exit 0
fi

excluded_tpl='0_!_*'
app_subdir='__appearancies__'
action='ln -s'

# TODO: Это для отдельной обработки
#echo ===== LINKS =====
#find ./ -maxdepth 1 -type l ! -iname "0_!_*"

count=$(echo -n "${categories_dir}" | wc -c)
let count=count+2						# Потому что начинается с 1, а ещё есть /, что ещё +1

list=$(find "${categories_dir}" -mindepth 1 -maxdepth 1 -type d ! -iname "${excluded_tpl}" -print | cut -b ${count}-)

count=0
while read LINE
do
    appearancies=''

    tpl=$(echo \*${LINE}\* | tr [:blank:] \?)

    [ "*${LINE}*" == "${tpl}" ] && continue			# Пропускаем те папки, под которые могут свалиться слишком многие

    echo "=== Ищем: ${tpl} ========================================"

    #D name_escaped=$(echo ${LINE} | sed 's/ /\\ /' ; )
    #D echo "escaped name: -- ${name_escaped} --"

    appearancies=$(find "${target_dir}/" -type f \( -iname "${tpl}" -a -not \( -iname "*.jpg" -o -iname "*.part" \) \)  -a ! -path "${categories_dir}/${LINE}/*")

    #D [ $count -eq 20 ] && break || let count=${count}+1	# Ограничитель. Для отладки

    [ ! -n "${appearancies}" ] && continue			# Нигде не встретилось

    app_dir="${categories_dir}/${LINE}/${app_subdir}"
    [ ! -d "${app_dir}" ] && mkdir -p "${app_dir}"

    while read APPEAR
    do
        BN=$(basename "${APPEAR}")

        if [ -L "${app_dir}/${BN}" ]
        then
            echo "Встретилось, но уже есть: ${APPEAR}"
            continue
        fi

        ${action} "${APPEAR}" "${app_dir}/" && echo "Добавили ссылку на ${APPEAR}"

    done < <(echo "$appearancies")

    echo

done < <(echo "${list}")
