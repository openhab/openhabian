#!/bin/bash

# create one swap partition per core with a total size of the machine's RAM
# origin https://github.com/novaspirit/rpi_zram

cores=$(nproc --all)
modprobe zram num_devices=$cores

# for safety don't remove existing swap
#swapoff -a

totalmem=`free | grep -e "^Mem:" | awk '{print $2}'`
mem=$(( ($totalmem / $cores)* 1024 ))

core=0
while [ $core -lt $cores ]; do
  echo $mem > /sys/block/zram$core/disksize
  mkswap /dev/zram$core
  swapon -p 5 /dev/zram$core
  let core=core+1
done
