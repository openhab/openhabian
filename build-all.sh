#!/usr/bin/env bash
set -e

echo "[openHABian] This script will build the openHABian Pine64 image file."
if [ ! "$1" == "go" ]; then
  echo "That's probably not what you wanted to do. Exiting."
  exit 0
fi

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

#bash build-rpi-ua-netinst.sh go
bash build-pine64.sh go
bash build-rpi-raspbian.sh go
