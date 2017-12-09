#!/usr/bin/env bash
set -e

echo "[openHABian] This script will build the openHABian RPi (Raspbian Lite) image file."
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

# Load config, create temporary build folder, cleanup
sourcefolder=build-rpi-raspbian
# shellcheck source=build-rpi-raspbian/openhabian.raspbian.conf
source $sourcefolder/openhabian.raspbian.conf
buildfolder=/tmp/build-raspbian-image
imagefile=$buildfolder/raspbian.img
umount $buildfolder/boot &>/dev/null || true
umount $buildfolder/root &>/dev/null || true
rm -rf $buildfolder

# Prerequisites
echo_process "Downloading prerequisites... "
apt update
apt --yes install git wget curl unzip kpartx libarchive-zip-perl

echo_process "Downloading latest Raspbian Lite image... "
mkdir $buildfolder
if [ -f "raspbian.zip" ]; then
  echo "(Using local copy...)"
  cp raspbian.zip $buildfolder/raspbian.zip
else
  wget -nv -O $buildfolder/raspbian.zip "https://downloads.raspberrypi.org/raspbian_lite_latest"
fi

echo_process "Unpacking image... "
unzip $buildfolder/raspbian.zip -d $buildfolder
mv $buildfolder/*raspbian*.img $buildfolder/raspbian.img

echo_process "Mounting the image for modifications... "
mkdir -p $buildfolder/boot $buildfolder/root
kpartx -asv $imagefile
#dosfslabel /dev/mapper/loop0p1 "OPENHABIAN"
mount -o rw -t vfat /dev/mapper/loop0p1 $buildfolder/boot
mount -o rw -t ext4 /dev/mapper/loop0p2 $buildfolder/root

echo_process "Setting hostname, reactivating SSH... "
sed -i "s/127.0.1.1.*/127.0.1.1 $hostname/" $buildfolder/root/etc/hosts
echo "$hostname" > $buildfolder/root/etc/hostname
touch $buildfolder/boot/ssh

echo_process "Injecting 'rc.local', 'first-boot.sh' and 'openhabian.conf'... "
cp $sourcefolder/rc.local $buildfolder/root/etc/rc.local
cp $sourcefolder/first-boot.sh $buildfolder/boot/first-boot.sh
touch $buildfolder/boot/first-boot.log
cp $sourcefolder/openhabian.raspbian.conf $buildfolder/boot/openhabian.conf
touch $buildfolder/root/opt/openHABian-install-inprogress

echo_process "Closing up image file... "
sync
umount $buildfolder/boot
umount $buildfolder/root
kpartx -dv $imagefile

echo_process "Moving image and cleaning up... "
shorthash=$(git log --pretty=format:'%h' -n 1)
crc32checksum=$(crc32 $imagefile)
destination="openhabianpi-raspbian-$(date +%Y%m%d%H%M)-git$shorthash-crc$crc32checksum.img"
mv -v $imagefile "$destination"
rm -rf $buildfolder

echo_process "Compressing image... "
xz --verbose --compress --keep "$destination"

echo_process "Finished! The results:"
ls -alh "$destination"*

# vim: filetype=sh
