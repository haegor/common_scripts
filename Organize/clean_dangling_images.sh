#!/bin/bash
#
# Убирает болтающиеся (осиротевшие) docker-образы
#

docker rmi $(docker images -f "dangling=true" -q)

# Аналог для:
# docker rmi $(docker image list --format "table {{.ID}}\t{{.Repository}}" | grep "<none>" | awk '{print $1}')

