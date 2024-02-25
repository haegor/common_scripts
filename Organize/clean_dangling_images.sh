#!/bin/bash
#
# Убирает болтающиеся (осиротевшие) docker-образы
#
# 2023 (c) haegor
#

docker rmi $(docker images -f "dangling=true" -q)

# Аналог для:
# docker rmi $(docker image list --format "table {{.ID}}\t{{.Repository}}" | grep "<none>" | awk '{print $1}')

# Более мощный вариант:
# docker system prune -a
#
# А можно ещё и хранилища:
# docker volumes prune

