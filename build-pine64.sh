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

# Switch to the script folder
cd "$(dirname $0)" || exit 1

timestamp() { date +"%F_%T_%Z"; }
echo_process() { echo -e "\\e[1;94m$(timestamp) [openHABian] $*\\e[0m"; }

# Log everything to a file
exec &> >(tee -a "openhabian-build-$(date +%Y-%m-%d_%H%M%S).log")

# Load config, create temporary build folder
sourcefolder=build-pine64-image
# shellcheck source=build-pine64-image/openhabian.pine64.conf
source $sourcefolder/openhabian.pine64.conf
buildfolder=/tmp/build-pine64-image
imagefile=$buildfolder/pine64-xenial.img
rm -rf $buildfolder

# Prerequisites
apt update && apt --yes install git wget curl bzip2 zip xz-utils xz-utils build-essential binutils kpartx dosfstools bsdtar qemu-user-static qemu-user libarchive-zip-perl

echo_process "Cloning \"longsleep/build-pine64-image\" project... "
git clone -b master https://github.com/longsleep/build-pine64-image.git $buildfolder

echo_process "Downloading aditional files needed by \"longsleep/build-pine64-image\" project... "
wget -nv -P $buildfolder/ https://www.stdin.xyz/downloads/people/longsleep/pine64-images/simpleimage-pine64-latest.img.xz
wget -nv -P $buildfolder/ https://www.stdin.xyz/downloads/people/longsleep/pine64-images/linux/linux-pine64-latest.tar.xz

echo_process "Copying over 'rc.local' and 'first-boot.sh' for image integration... "
cp build-pine64-image/rc.local $buildfolder/simpleimage/openhabianpine64.rc.local
cp build-pine64-image/first-boot.sh $buildfolder/simpleimage/openhabianpine64.first-boot.sh
cp build-pine64-image/openhabian.pine64.conf $buildfolder/simpleimage/openhabian.conf

source build-pine64-image/openhabian.pine64.conf

echo_process "Hacking \"build-pine64-image\" build and make script... "
sed -i "s/date +%Y%m%d_%H%M%S_%Z/date +%Y%m%d%H/" $buildfolder/build-pine64-image.sh
makescript=$buildfolder/simpleimage/make_rootfs.sh
sed -i "s/^pine64$/openHABianPine64/" $makescript
sed -i "s/127.0.1.1 pine64/127.0.1.1 openHABianPine64/" $makescript
sed -i "s/DEBUSER=ubuntu/DEBUSER=$username/" $makescript
sed -i "s/DEBUSERPW=ubuntu/DEBUSERPW=$userpw/" $makescript
echo -e "\n# Add openHABian modifications" >> $makescript
echo "touch \$DEST/opt/openHABian-install-inprogress" >> $makescript
echo "cp ./openhabianpine64.rc.local \$DEST/etc/rc.local" >> $makescript
echo "cp ./openhabianpine64.first-boot.sh \$BOOT/first-boot.sh" >> $makescript
echo "cp ./openhabian.conf \$BOOT/openhabian.conf" >> $makescript
echo "echo \"openHABian preparations finished, /etc/rc.local in place\"" >> $makescript

echo_process "Executing \"build-pine64-image\" build script... "
(cd $buildfolder; /bin/bash build-pine64-image.sh simpleimage-pine64-latest.img.xz linux-pine64-latest.tar.xz xenial)
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
mv $buildfolder/xenial-pine64-*.img $imagefile
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

echo_process "Moving image and cleaning up... "
shorthash=$(git log --pretty=format:'%h' -n 1)
crc32checksum=$(crc32 $imagefile)
destination="openhabianpine64-xenial-$(date +%Y%m%d%H%M)-git$shorthash-crc$crc32checksum.img"
mv -v $imagefile "$destination"
rm -rf $buildfolder

echo_process "Compressing image... "
xz --verbose --compress --keep "$destination"

echo_process "Finished! The results:"
ls -alh "$destination"*

# vim: filetype=sh
