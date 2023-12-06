#!/bin/bash
#
# Достаёт из БД dpkg список файлов и аккуратно копирует их в chroot-овую директорию.
# Директории воссоздаются. Ссылки переносятся.
# Для исполнимых: если это бинарник, то привлекается вспомогательный скрипт,
# рекурсивно копирующий зависимости. Скрипты просто копируются. Как и всё остальное.
#
# Скрипт создан для быстрого создания chroot-ов и изначально ориентирован на
# исполнимые файлы. Так что если он не скопирует какой-то man, то это скорее фича.
#
# 2023 (c) haegor
#

cp='sudo cp'
mkdir='sudo mkdir'
dpkg='sudo dpkg'

[ "$1" ] && pkg="$1" || pkg='coreutils'
[ "$2" ] && target_dir="$2" || target_dir='./work_dir'
if [ "$3" ]
then
  echo "Слишком много аргументов"
  exit 0
fi

bin2chroot='./bin2chroot.sh'

f_file_copy () {
  ${cp} --parents --dereference --update "$1" "${target_dir}"
}

f_link_copy () {
  ${cp} --parents --no-dereference "$1" "${target_dir}"
}

while read i
do
    if [ -d "${i}" ]
    then
	${mkdir} -p "${target_dir}/${i}" && \
            echo "Создана директория: ${i}"
	continue
    fi

    if [ -L "${i}" ]
    then
        f_link_copy "${i}" && \
	    echo "Скопирована ссылка: ${i}"
        continue
    fi

    if [ -x "${i}" ]
    then
	# haegor@vetinari:~/dev/virtualisation/isolation$ file /usr/bin/bashbug
	# /usr/bin/bashbug: POSIX shell script, ASCII text executable
	#
	# haegor@vetinari:~$ file /usr/bin/mesa-overlay-control.py
	# /usr/bin/mesa-overlay-control.py: Python script, ASCII text executable
	#
	# haegor@vetinari:~$ file /usr/bin/isohybrid.pl
	# /usr/bin/isohybrid.pl: Perl script text executable

	text_executable='' && text_executable="$(file ${i} | grep 'text executable')"
	if [ "$text_executable" ]
	then
            f_file_copy "${i}" && \
		echo "Скопирован скрипт: ${i}"
	    continue
	fi

	${bin2chroot} "${i}" "${target_dir}"
	continue
    fi

    f_file_copy "${i}" && \
	echo "Скопирован файл: ${i}"

done < <(${dpkg} -L "${pkg}")
