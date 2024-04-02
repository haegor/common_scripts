#!/bin/bash
#
# Делает бэкап почтовых ящиков Zimbra, указанных в файле переданном через
# параметр
#

log_dir='/tmp'
bkp_dir='/var/backup'

[ -z "$1" ] && {
  echo "Параметр не был задан".
  exit 1
}

[ -f "$1" ] && {
  echo "Указан несуществующий файл."
  exit 1
}

cat $1 | grep -v '^#' | while read mailbox
do
    echo "Обрабатывается $mailbox"
    # TODO Не помню как работает этот echo 'Done', толи это часть команды zmmailbox, толи забыт &&
    (nohup /opt/zimbra/bin/zmmailbox -z -m $mailbox getRestURL "//?fmt=tgz" > $bkp_dir/$mailbox.tgz echo 'Done')  >> $log_dir/$mailbox.log 2>&1
    sleep 100
done
