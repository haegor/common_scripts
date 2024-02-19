#!/bin/bash
#
# Скрипт проверки срока годности crl, pem, crt файлов и сигнализации на почту.
# Для работы требуется пакет mailx.x86_64
#
# 2023, 2024 (c) haegor
#
# TODO: универсализировать задание почтовых адресов
#

[ -f "./.env" ] && . ./.env || exit 0

# Файл по умолчанию.
[ $2 ] && target_file="$2" || target_file="/etc/openvpn/server/$(hostname -f)_ca.crt"

# Количество дней по умолчанию.
[ $3 ] && limit="$3" || limit=30

# Адрес получателя
[ $4 ] && mail_to="$4" || mail_to=${USER_MAIL_TO:="admin@$(hostname -f)"}

# Адрес отправителя
[ $5 ] && mail_from="$5" || mail_from=${CERT_MAIL_FROM:="cert@$(hostname -f)"}

case $1 in
'crl')	# Certificate Revocations List = Список отозванных сертификатов
    # Файлы crl находятся в особом формате. Для их просмотра,
    # сначала его необходимо преобразовать в pkcs7

    intermidiate_file=$(mktemp)
    openssl crl2pkcs7 -in "${target_file}" -out "${intermidiate_file}"

    expiration_date=$(openssl pkcs7 -in "${intermidiate_file}" -print | grep "nextUpdate"| awk -F': ' '{ print $2}')
    rm "${intermidiate_file}"
;;
'sig')	# Sign. TODO: Дописать.
    # вот эти две команды взаимообратны:
    # base64 -d ./sign2.sig > sign2.dec
    # openssl x509 -inform DER -in ./sign2.dec
;;
'crt'|'pem')	# Проверка истечения срока годности для crl и pem файлов
    expiration_date=$(openssl x509 -text -in "${target_file}" | egrep "Not After" | awk -F" : " '{ print $2 }')
;;
'about')				# О Скрипте
  comment_brace=0

  while read LINE
  do
    if [[ "$LINE" == "#" ]] && [ $comment_brace -eq 0 ]      # Начало коммента
    then
      comment_brace=1
      echo -e "\n  О скрипте\n"
    elif [ "${LINE:17:23}" != 'haegor' ] && [ $comment_brace -eq 1 ]    # Текст коммента
    then
      echo "  ${LINE:2}"
    elif [ "${LINE:17:23}" == 'haegor' ] && [ $comment_brace -eq 1 ]    # Закрытие
    then
      echo -e "  ${LINE:2}\n"
      exit 0
    fi
  done < <(cat "$0")
;;
'--help'|'-help'|'help'|'-h'|*|'')	# Автопомощь. Мы тут.
  echo
  echo "Параметры:"
  echo "$0 {crl|[crt,pem]} <имя файла> <предел дней>"
  echo
  grep -P "^\'[[:graph:]]*\'\)[[:space:]]*#?.*$" $0 | grep -v 'excluder'
  echo
  echo "Первый аргумент - тип запроса: crl, crt, perm, sig"
  echo "Второй аргумент - имя файла. Используйте кавычки."
  echo "Третий аргумент - дней до истечения его срока годности."
  echo
  exit 0
;;
esac

################ Общая часть для всех режимов работы ################

# Переводим время экспирации в unix-time
expiration_unix=$(date -d "${expiration_date}" +%s)

# Смотрим текущую дату в формате unix-time
current_unix=$(date +%s)

# Считаем разницу и переводим в дни
let difference_sec=${expiration_unix}-${current_unix}
let difference_days=${difference_sec}/86400

# Если приблизились к порогу, то начинаем надоедать админу
# И делаем это на аглицком, чтобы избежать любых проблем с кодировкой.
if [ ${difference_days} -le ${limit} ]; then
    echo "$1-file ${target_file} will be expired at ${expiration_date}. There is ${difference_days} last." | \
    mail -s "Cryptografic files expiration time" -r "${mail_from}" "${mail_to}"
fi
