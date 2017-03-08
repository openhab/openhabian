#!/usr/bin/env bash
set -e

echo "[openHABian] This script will build the openHABian Raspberry Pi image file."
if [ ! "$1" == "go" ]; then
  echo "That's probably not what you wanted to do. Exiting."
  exit 0
fi

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Switch to the script folder
cd $(dirname $0) || exit 1

timestamp() { date +"%F_%T_%Z"; }
echo_process() { echo -e "\e[1;94m$(timestamp) [openHABian] $*\e[0m"; }

# Log everything to a file
exec &> >(tee -a "openhabian-build-$(date +%Y-%m-%d_%H%M%S).log")

# Load config, create temporary build folder
sourcefolder=build-rpi-ua-netinst
source $sourcefolder/openhabian.ua-netinst.conf
buildfolder=/tmp/build-rpi-ua-netinst
rm -rf $buildfolder

# Prerequisites
apt update && apt --yes install git wget curl bzip2 zip xz-utils gnupg kpartx dosfstools binutils bc

echo_process "Cloning \"debian-pi/raspbian-ua-netinst\" project... "
git clone -b "v1.1.x" https://github.com/debian-pi/raspbian-ua-netinst.git $buildfolder

echo_process "Copying openHABian settings and post-install script to \"raspbian-ua-netinst\"... "
cp $sourcefolder/post-install.txt $buildfolder/post-install.txt
cp $sourcefolder/openhabian.ua-netinst.conf $buildfolder/installer-config.txt

echo_process "Firing up \"raspbian-ua-netinst\"... "
(cd $buildfolder; /bin/bash clean.sh)
(cd $buildfolder; /bin/bash update.sh)
(cd $buildfolder; /bin/bash build.sh)
(cd $buildfolder; /bin/bash buildroot.sh)
echo ""

echo_process "Cleaning up... "
cp $buildfolder/raspbian-ua-netinst-*.img .
rm -rf $buildfolder
for file in raspbian-ua-netinst-*.*; do
  mv -v "$file" "${file//raspbian/openhabianpi}"
done
echo_process "Finished! The results:"
ls -al openhabianpi-ua-netinst-*.*

# vim: filetype=sh
