#!/bin/bash
#
# Скрипт генерирует файл со рандомизированным содержимым и размещает его в ОП.
# После чего несколько раз копирует его с засечением времени в две разные папки.
# Если они на разных дисках, то по данным можно сравнить производительность IO.
#
# 2024 (c) haegor
#

ram_disk='/mnt/tmp'
rnd_file="test_file"

test_dir1='/home/haegor'
test_dir2='/mnt/storage'

size=2048
amount=10

f_write2dir () {
  local test_dir="$1"

  echo "=== Directory: $test_dir ==="
  time for i in $(seq 1 $amount)
  do
    echo "--- Iteration $i ---"
    time cp "$ram_disk/$rnd_file" "${test_dir}/${rnd_file}_${i}"
    echo
    [ "$i" == "$amount" ] \
      && { echo "-------------------"; echo "Summary:"; }
  done
}

case $1 in
'mount_ram')
  mount -t tmpfs none "$ram_disk" \
    && echo "Ramdisk mounted." \
    || echo "Failed to mount raddisk."
;;
'gen')
  dd if=/dev/random of="$ram_disk/$rnd_file" bs=1M count=$size \
    && echo "Randomized file generated." \
    || echo "Failed to generate of randomized file."
;;
'clean')
  [ -f "${ram_disk}/${rnd_file}" ] \
    && rm "${ram_disk}/${rnd_file}"

  for i in $(seq 1 $amount)
  do
    [ -f "$test_dir1/${rnd_file}_${i}" ] \
      && rm "$test_dir1/${rnd_file}_${i}"
    [ -f "$test_dir2/${rnd_file}_${i}" ] \
      && rm "$test_dir2/${rnd_file}_${i}"
  done

  echo "Cleaning complete"
;;
'test')
  mkdir -p "$ram_disk"
  mount -t tmpfs none "$ram_disk"

  echo -e "\nRandom file generation, $size Mb"
  dd if=/dev/random of="$ram_disk/$rnd_file" bs=1M count=$size

  echo
  f_write2dir "$test_dir2"

  echo
  f_write2dir "$test_dir1"

  echo
  echo "Maybe now you need to run: $0 clean ?"
;;
*)
  echo "READ BEFORE YOU EXECUTE!"
;;
esac
