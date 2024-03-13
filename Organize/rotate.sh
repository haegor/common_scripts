#!/bin/bash
#
# Ротация чего угодно на любую глубину
#
# 2023-2024 (c) haegor
#

show_params () {
    echo
    echo "Использование: $0 <path> <filter> <depth>, где:"
    echo "  <path>   - путь по которому следует производить отбор"
    echo "  <filter> - шаблон для отбора удаляемых файлов"
    echo "  СОВЕТ:     чтобы его не съел shell - используйте одинарные ковычки."
    echo "  <depth>  - глубина оставляемых файлов"
    echo
    return 0
}

[ $# -gt 3 ] && { echo && echo "Слишком много параметров. Нужно всего три!" ; show_params; exit 1; }

[ -n "$1" ] && base_dir="$1" || { echo && echo "Не указан путь с файлами для обработки."  ; show_params; exit 1; }
[ -n "$2" ] && template="$2" || { echo && echo "Не указан шаблон для просева файлов."     ; show_params; exit 1; }
[ -n "$3" ] && depth="$3"    || { echo && echo "Не указана глубина сохранения для файлов."; show_params; exit 1; }

# Защита от дурака.
[ "$base_dir" == "/" ] && { echo "Останов: потенциальное удаление корня файловой системы."; exit 1; }

# Ключ -t нужен для защиты от неправильной сортировки дат. К примеру для
# американского формата: DD-MM-YYYY. А ещё это избавило от `sort -u`
current_list=`ls -t "${base_dir}" | grep -P "${template}"`
current_count=`echo "${current_list}" | wc -l`

if [ ${current_count} -gt ${depth} ]
then
    let count=${current_count}-${depth}

    # Без двойных ковычек многострочные $current_list и $victims канкатенируют в одну строку
    victims=`echo "${current_list}" | tail -${count}`

    for LINE in `echo "${victims}"`
    do
        rm -rf "${base_dir}/${LINE}"
    done
fi
