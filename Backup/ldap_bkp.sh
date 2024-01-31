#!/bin/bash
#
# Скрипт для работы с бэкапаи LDAP. Как корневой базы (0, она же dc=config),
# так и основной рабочей (2, она же dc=чего-нибудь)
#
# Можно запускать от обычного пользователя, но тогда нужен sudo.
#
# 2023 (c) haegor
#
# TODO: добавить работу с gzip
#

# Перепроверить перед использованием
exit 0

# Секция настроек
ldap_user='ldap'
bkp_dir='/var/backup/'
slapd_dir='/etc/openldap/slapd.d'
base_dir='/var/lib/ldap'

timestamp=$(date +%F_%T)
dt=$(date +%Y-%m-%d)

systemctl="sudo systemctl"
slapadd="sudo /sbin/slapadd"
slapcat="/sbin/slapcat"

case $1 in
'base_restore'|'config_restore')		# excluder
    [ ! "$2" ] && echo "Не указан бэкап для восстановления." && exit 0

    if      [ -f "$2" ]             # Если указан прямой путь до файла
    then
            restorable_bkp="$2"

    elif    [ -f "${bkp_dir}/$2" ]  # А вдруг нам дали только имя файла и его надо поискать среди остальных бэкапов
    then
            restorable_bkp="$2"

    elif    [ -f "./$2" ]           # Возможно, работаем с чем-то, что только что сделано вручную
    then
            restorable_bkp="./$2"
    fi

    # Для удобства
    [ "$2" == 'prev' ] && restorable_bkp=$(ls -At "${bkp_dir}/*.ldif" | head -2 | tail -1)
    [ "$2" == 'last' ] && restorable_bkp=$(ls -At "${bkp_dir}/*.ldif" | head -1)
;;
esac

case $1 in
'config_backup')		# Бэкап базы с настройками
	${slapcat} -n 0 > "${bkp_dir}/slapd_${timestamp}.ldif"
;;
'base_backup')			# Бэкап самой бaзы LDAP
	${slapcat} -n 2 > "${bkp_dir}/base_${timestamp}.ldif"
;;
'paranoic_backup')		# Делает бэкап простым копированием папок с базами
	${systemctl} stop dlapd

	# Бэкап папки с базой
	cp -r "${slapd_dir}" "${bkp_dir}/slapd.d_${timestamp}"

	# Бэкап папки с базой. Чисто на всякий случай
	cp -r "${base_dir}" "${base_dir}_${timestamp}"

	${systemctl} start dlapd
;;
'config_restore')		# Восстановить все настройки:
	${systemctl} stop slapd

	# Чистка
	[ "${slapd_dir}" ] && rm -rf "${slapd_dir}"
	mkdir -p "${slapd_dir}"

	# slapd.ldif создаёт backup_config
	${slapadd} -n 0 -F "${slapd_dir}" -l "${restorable_bkp}"

	chown -R ${ldap_user}:${ldap_user} "${slapd_dir}"

	${systemctl} start slapd
;;
'base_restore')			# Восстановление бaзы LDAP
	${systemctl} stop slapd
	${slapadd} -n 2 -l "${restorable_bkp}"
	${systemctl} start slapd
;;
'--help'|'-help'|'help'|'-h'|*|'')	# Автопомощь. Мы тут.
  echo
  echo "Параметры:"
  echo "$0 <действие> [<файл>]"
  echo
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  echo "Первый аргумент - тип действия"
  echo "Второй аргумент - имя файла бэкапа, из которого следует восстановить базу. Используйте кавычки."
  echo "                  Также можно указать 'last' или 'prev'"
  echo
  exit 0
;;
esac

