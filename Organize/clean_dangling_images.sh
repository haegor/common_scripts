#!/bin/bash
#
# Подчищает всякое лишнее в docker-е.
#
# 2023-2024 (c) haegor
#

# Умолчание
[ -n "$1" ] && mode="$1" || mode='dangling'

case $mode in
'dangling')		# Удалить "болтающиеся" образы
  docker rmi $(docker images -f "dangling=true" -q)
;;
'axe-dangling')		# Тоже что и dangling, но более топорно
  docker rmi $(docker image list --format "table {{.ID}}\t{{.Repository}}" | grep "<none>" | awk '{print $1}')
;;
'prune-all')		# Подчистить всё
  docker system prune -a
;;
'volumes')		# только хранилища
  docker volumes prune
;;
esac

