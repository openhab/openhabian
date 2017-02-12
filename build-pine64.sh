#!/usr/bin/env bash

echo "[openHABian] This script will build the openHABian Pine64 image file."
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
apt update && apt --yes install git curl bzip2 zip xz-utils xz-utils build-essential binutils kpartx dosfstools bsdtar qemu-user-static qemu-user

echo "$(timestamp) [openHABian] Cloning \"longsleep/build-pine64-image\" project... "
buildfolder=/tmp/build-pine64-image
git clone -b master https://github.com/longsleep/build-pine64-image.git $buildfolder

echo "$(timestamp) [openHABian] Downloading aditional files needed by \"longsleep/build-pine64-image\" project... "
wget -nv -P $buildfolder/ https://www.stdin.xyz/downloads/people/longsleep/pine64-images/simpleimage-pine64-latest.img.xz
wget -nv -P $buildfolder/ https://www.stdin.xyz/downloads/people/longsleep/pine64-images/linux/linux-pine64-latest.tar.xz

echo "$(timestamp) [openHABian] Copying over 'rc.local' and 'first-boot.sh' for image integration... "
cp build-pine64-image/rc.local $buildfolder/simpleimage/openhabianpine64.rc.local
cp build-pine64-image/first-boot.sh $buildfolder/simpleimage/openhabianpine64.first-boot.sh

echo "$(timestamp) [openHABian] Hacking \"build-pine64-image\" build and make script... "
sed -i "s/date +%Y%m%H/date +%Y%m%d%H/" $buildfolder/build-pine64-image.sh # Fix https://github.com/longsleep/build-pine64-image/pull/47
makescript=$buildfolder/simpleimage/make_rootfs.sh
sed -i "s/TARBALL=\"\$BUILD/mkdir -p \$BUILD\nTARBALL=\"\$BUILD/" $makescript # Fix https://github.com/longsleep/build-pine64-image/pull/46
sed -i "s/^pine64$/openHABianPine64/" $makescript
sed -i "s/127.0.1.1 pine64/127.0.1.1 openHABianPine64/" $makescript
sed -i "s/DEBUSER=ubuntu/DEBUSER=ubuntu/" $makescript
echo -e "\n# Add openHABian modifications" >> $makescript
echo "touch \$DEST/opt/openHABian-install-inprogress" >> $makescript
echo "cp ./openhabianpine64.rc.local \$DEST/etc/rc.local" >> $makescript
echo "cp ./openhabianpine64.first-boot.sh \$BOOT/first-boot.sh" >> $makescript
echo "echo \"openHABian preparations finished, /etc/rc.local in place\"" >> $makescript

echo "$(timestamp) [openHABian] Executing \"build-pine64-image\" build script... "
(cd $buildfolder; /bin/bash build-pine64-image.sh simpleimage-pine64-latest.img.xz linux-pine64-latest.tar.xz xenial)
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi

echo -e "$(timestamp) [openHABian] Moving image and cleaning up... "
mv $buildfolder/xenial-pine64-*.img .
rm -rf $buildfolder

echo -e "$(timestamp) [openHABian] Renaming image... "
for file in xenial-*.img; do
  mv -v "$file" "${file//pine64-bspkernel/openhabianpine64}"
done
shorthash=$(git log --pretty=format:'%h' -n 1)
for file in xenial-*.img; do
  mv -v "$file" "${file//-1.img/-git$shorthash.img}"
done

echo -e "$(timestamp) [openHABian] Compressing image... "
for file in xenial-*.img; do
  xz --verbose --compress --keep $file
done

echo -e "$(timestamp) [openHABian] Finished! The results:"
ls -alh xenial-*.*

# vim: filetype=sh
