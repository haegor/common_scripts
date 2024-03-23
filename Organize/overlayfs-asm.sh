#!/bin/bash
#
# Изначально скрипт писался для сборки нескольких отдельных git-репозиториев, часть
# которых не может быть опубликована, но после ревью стал самостоятельным.
# Однако своё назначение он не сменил. С его помощью всё также сливаются несколько
# репозиториев в один и это определяет его дальнейшее развитие.
#
# 2024 (c) haegor
#

##### Settings #################################################################

mount='sudo mount'
umount='sudo umount'

lower='./lower'
upper='./upper'
merged='./merged'
workdir='./workdir'
# Из man: The workdir needs to be an empty directory on the same filesystem as
# upperdir.

##### MAIN #####################################################################

f_create_dirs () {
  [ ! -d "$lower" ]   && { mkdir -p "$lower"   || return 1; }
  [ ! -d "$upper" ]   && { mkdir -p "$upper"   || return 1; }
  [ ! -d "$merged" ]  && { mkdir -p "$merged"  || return 1; }
  [ ! -d "$workdir" ] && { mkdir -p "$workdir" || return 1; }
  return 0
}

isDirsExists () {
  local fail=0
  ( [ -d "$lower" ]   || [ -L "$lower" ]   ) || let fail+=1
  ( [ -d "$upper" ]   || [ -L "$upper" ]   ) || let fail+=1
  ( [ -d "$merged" ]  || [ -L "$merged" ]  ) || let fail+=1
  ( [ -d "$workdir" ] || [ -L "$workdir" ] ) || let fail+=1
  [ $fail -eq 0 ] && return 0 || return 1
}

# TODO две очень похожие функции это как-то не очень.
isDirMounted () {
  local dir="$1"
  local isMounted=$(findmnt --noheadings "${dir}")

  if [ -z "$isMounted" ]
  then
    [ "$2" == 'show' ] && echo "В пути $dir ничего не смонтировано."
    return 0
  else
    [ "$2" == 'show' ] && { echo "Директория $dir смонтирована как:"; echo "$isMounted"; }
    return 1
  fi
}

isDirOverlayed () {
  local dir="$1"
  local isOverlayfs=$(findmnt --noheadings --types=overlay "${dir}")

  if [ -z "$isOverlayfs" ]
  then
    [ "$2" == 'show' ] && echo "Директория $dir НЕ смонтирована в overlayfs."
    return 0
  else
    [ "$2" == 'show' ] && { echo "Директория $dir смонтирована:"; echo "$isOverlayfs"; }
    return 1
  fi
}

case $1 in
'test')					# excluder
  echo 'Данный пункт используется исключительно для отладки.'
  exit 0
;;
'init'|'prepare'|'prep')		# Создать папки для работы
  if [ ! isDirsExists ]
  then
    f_create_dirs \
      &&  echo "Не хватало директорий, но мы создали." \
      ||  echo "Ошибка при создании директорий.";
   fi
;;
'bind')					# Создать папки и подключить $2 как lower
  [ -n "$2" ] \
    && local_bind_path="$2" \
    || { echo "Локальная папка не определена"; exit 1; }

  isDirsExists || f_create_dirs
  $mount -o bind "$local_bind_path" "$lower"
;;
'unbind')				# Открепить (unbind) lower
  $umount "$lower" \
    && echo "Папка успешно откреплена (unbind) от $lower." \
    || echo "Ошибка при откреплении директории (unbind)."
;;
'mount'|'assemble'|'asm')		# Собрать итоговую конфигурацию
  isDirOverlayed "$merged" \
    || { echo "Останов. Папка $merged уже собрана."; exit 1; }

  $0 init

  $mount -t overlay overlay -o lowerdir="$lower",upperdir="$upper",workdir="$workdir" "$merged" \
    && { echo "Слои собраны в папке $merged"; exit 0; } \
    || { echo "Останов. Ошибка при попытке сборки директории $merged"; exit 1; }

;;
'umount'|'unmount'|'disasm')		# Демонтировать (разобрать) наслоение
  $umount "$(realpath $merged)" \
    && echo "Слои разобраны для директории $merged" \
    || echo "Ошибка при попытке демонтирования папки $merged"
;;
'diff')					# Показать различия между оригиналом и изменениями (lower vs upper)
  while read LINE
  do
    file_path=${LINE#$upper/}
    if [ -f "${lower}/${file_path}" ]
    then
      echo ">>> Изменённый файл: $file_path <<<"
      diff "${lower}/${file_path}" "${upper}/${file_path}"
      echo "-------------------------------------------------------------------"
    else
      echo ">>> Был создан файл: $file_path <<<"
      cat "${upper}/${file_path}"
    fi
  done < <(find "$upper" -type f)
;;
'look'|'ls'|'list'|'show'|'sh')		# Осмотреться. Показать точки монтирования.
  isDirOverlayed "$merged" 'show' && isDirMounted "$merged" 'show'
  echo
  isDirOverlayed "$lower" 'show'  && isDirMounted "$lower" 'show'
;;
'about')				# О Скрипте
  start=0;

# Никогда так не пишите.
   while read LINE; do
  ( [[ "$LINE" == "#" ]] && [ $start -eq 0 ] ) && { start=1; echo -e "\n  О скрипте\n"; } \
  || { ( [ "${LINE:11:17}" != 'haegor' ] && [ $start -eq 1 ] ) && echo "  ${LINE:2}" \
  || { ( [ "${LINE:11:17}" == 'haegor' ] && [ $start -eq 1 ] ) && { echo -e "  ${LINE:2}\n"; exit 0; } } }
  done < <(cat "$0")
;;
'--help'|'-help'|'help'|'-h'|''|*)	# Автопомощь. Мы тут.
  echo
  echo "Недостаточно параметров или они неверно указаны."
  echo "В качестве обязательного параметра указывается его режим."
  echo
  echo "Перечень режимов:"
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  exit 0
;;
esac
