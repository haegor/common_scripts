#!/bin/bash
#
# Делает бэкап конфигурации LDAP и базы внутри неё
#

bkp_dir=$1

cd "${bkp_dir}"

/sbin/slapcat -n 0 | /bin/gzip > $(date +%Y-%m-%d)_config.ldif.gz
/sbin/slapcat -n 2 | /bin/gzip > $(date +%Y-%m-%d)_base.ldif.gz
