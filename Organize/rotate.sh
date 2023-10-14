#!/bin/bash
# Ротация чего угодно на любую глубину
# 2023 (c) haegor

msg_params () {
        echo
        echo "Использование: $0 <path> <filter> <depth>, где:"
        echo "  <path>   - путь по которому следует производить отбор"
        echo "  <filter> - шаблон для отбора удаляемых файлов"
        echo "             чтобы его не съел shell - используйте одинарные ковычки."
        echo "  <depth>  - глубина оставляемых логов"
        echo
        return 0
}

if [ $# -lt 3 ]
then
        echo
        echo "Недостаточно параметров. Нужно три!"
        msg_params
        exit 0
elif [ $# -gt 3 ]
then
        echo
        echo "Слишком много параметров. Нужно три!"
        msg_params
        exit 0
fi

base_dir="$1"
template="$2"
depth="$3"

# Ключ -t - наша защита от неправильной сортировки дат. К примеру для американского формата: DD-MM-YYYY
# А ещё это избавило нас от `sort -u`
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
