#!/usr/bin/env bash

echo "[openHABian] This script will build the openHABian Raspberry Pi image file."
if [ ! "$1" == "go" ]; then
  echo "That's probably not what you wanted to do. Exiting."
  exit 0
fi
echo ""

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Switch to the script folder
cd $(dirname $0) || exit 1

timestamp() { date +"%F_%T_%Z"; }

# Log everything to a file
exec &> >(tee -a "openhabian-build-$(date +%Y-%m-%d_%H%M%S).log")

# Prerequisites
apt update && apt --yes install git curl bzip2 zip xz-utils gnupg kpartx dosfstools binutils bc

echo "$(timestamp) [openHABian] Cloning \"debian-pi/raspbian-ua-netinst\" project... "
buildfolder=/tmp/raspbian-ua-netinst
git clone -b "v1.1.x" https://github.com/debian-pi/raspbian-ua-netinst.git $buildfolder

echo "$(timestamp) [openHABian] Copying openHABian settings and post-install script to \"raspbian-ua-netinst\"... "
cp raspbian-ua-netinst/post-install.txt $buildfolder/post-install.txt
cp raspbian-ua-netinst/openhabian.rpi.conf $buildfolder/installer-config.txt

echo "$(timestamp) [openHABian] Firing up \"raspbian-ua-netinst\"... "
(cd $buildfolder; /bin/bash clean.sh)
(cd $buildfolder; /bin/bash update.sh)
(cd $buildfolder; /bin/bash build.sh)
(cd $buildfolder; /bin/bash buildroot.sh)

echo -e "\n$(timestamp) [openHABian] Cleaning up... "
cp $buildfolder/raspbian-ua-netinst-*.img .
rm -rf $buildfolder &>/dev/null
for file in raspbian-ua-netinst-*.*; do
  mv -v "$file" "${file//raspbian/openhabianpi}"
done
echo -e "\n$(timestamp) [openHABian] Finished! The results:"
ls -al openhabianpi-ua-netinst-*.*

# vim: filetype=sh
