#!/bin/bash
#
# Скрипт предназначен для внесения сертификата CA в список доверенных корневых
# сертификатов. К примеру для гос.учреждений или фирм.
#
# В качестве параметра указывается путь до файла, который следует прописать.
#
# Зависимости: sudo, coreutils, ca-certificates
#
# 2024 (c) haegor
#

[ ! -z "$1" ] && new_ca_cert="$1" \
  || { echo "Останов. Вы не указали сертификат CA для прописывания."; exit 1; }

[ -f "$new_ca_cert" ] \
  || { echo "Указанный вами файл не существует"; exit 1; }

if [[ ! "$(file $new_ca_cert)" =~ .*:\ PEM\ certificate$ ]] \
&& [[ ! "$(mimetype $new_ca_cert)" =~ .*\ application\/pkix-cert$ ]]
then
  echo "Указанный вами файл не является сертификатом" && exit 1
fi

cert_basename="$(basename $new_ca_cert)"

ca_certificates_file='/etc/ca-certificates.conf'
placement_dir='/usr/local/share/ca-certificates'

isCertAlreadyAdded=$(cat "$ca_certificates_file" | grep "$new_ca_cert")
[ -z "$isCertAlreadyAdded" ] \
  || { echo "Такой сертификат уже имеется."; exit 1; }

[ -f "$placement_dir/$cert_basename" ] \
  && { echo "Такой файл уже существует в папке назначения."; exit 1; } \
  || sudo cp "$new_ca_cert" "$placement_dir/$cert_basename"

sudo update-ca-certificates
