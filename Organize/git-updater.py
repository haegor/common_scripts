#!/usr/bin/env python3
#
# В качестве параметра можно указать одну папку.
#
# Скрипт обходит все вложенные папки и если видит в них папку .git, то меняет
# рабочую директорию и выполняет git pull, после чего выдаёт сообщение о том
# что он обновил папку.
#
# TODO надо сделать проверку параметров на то, папка это или нет
# и проходя по ним всем делать апдейт.
#
# 2017 (с) haegor
#

import os           # Для os.walk
import subprocess   # Для запуска команды
import sys

if len (sys.argv) == 1:
    walking_dir = os.getcwd()

elif len(sys.argv) > 2:
    print ('Слишком много параметров')
    sys.exit()

elif os.path.isdir (sys.argv[1]):
    walking_dir = sys.argv[1]

elif sys.argv[1] == '--help':
    print ("""
    Скрипт обновляет git репозитории в текущей и всех вложенных папках.
    В качестве параметра может быть указана иная папка для выполнения операции.
        """)
else:
    print ('Переданный параметр не является папкой')
    sys.exit ()

for path, dirs, files in os.walk(walking_dir):

    test_path = os.path.join(path, '.git')

    if os.path.exists(test_path) and os.path.isdir(test_path):
        print ('we start: ' + path + '===========================================================')
        os.chdir (path)
        subprocess.call(['/usr/bin/git', 'pull'])
        print ('updated: ' + path + '===========================================================' )
        continue

