#!/bin/bash
#
# Делает бэкап почтовых ящиков Zimbra, указанных в файле переданном через
# параметр
#

cat $1 | while read A
do
    echo $A
    (nohup /opt/zimbra/bin/zmmailbox -z -m $A getRestURL "//?fmt=tgz" > $A.tgz echo 'Done')  >> /tmp/$A.log 2>&1
    sleep 100
done
