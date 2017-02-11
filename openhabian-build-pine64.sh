#!/usr/bin/env bash

echo "[openHABian] This script will build the openHABian Pine64 image file."
echo "That's probably not what you wanted to do."
echo ""
echo "Exiting."; exit 1 # Remove if you know what you are doing

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Switch to the script folder
cd $(dirname $0) || exit 1

# Log everything to a file
exec &> >(tee -a "openhabian-build-$(date +%Y-%m-%d_%H%M%S).log")

echo "[openHABian] Cloning \"longsleep/build-pine64-image\" project... "
buildfolder=/tmp/build-pine64-image
git clone -b master https://github.com/longsleep/build-pine64-image.git $buildfolder
wget -P $buildfolder/ https://www.stdin.xyz/downloads/people/longsleep/pine64-images/simpleimage-pine64-latest.img.xz
wget -P $buildfolder/ https://www.stdin.xyz/downloads/people/longsleep/pine64-images/linux/linux-pine64-latest.tar.xz

echo "[openHABian] Copying over 'rc.local' file for image integration... "
cp build-pine64-image/rc.local $buildfolder/simpleimage/openhabianpine64.rc.local

echo "[openHABian] Modifying \"build-pine64-image\" make script... "
makescript=$buildfolder/simpleimage/make_rootfs.sh
sed -i "s/TARBALL=\"\$BUILD/mkdir -p \$BUILD\nTARBALL=\"\$BUILD/g" $makescript
echo -e "\n# Add openHABian modifications" >> $makescript
echo "touch \$DEST/opt/openHABian-install-inprogress" >> $makescript
echo "cp ./openhabianpine64.rc.local \$DEST/etc/rc.local" >> $makescript
echo "echo \"openHABian preparations finished, /etc/rc.local in place\"" >> $makescript

echo "[openHABian] Executing \"build-pine64-image\" make script... "
(cd $buildfolder; /bin/bash build-pine64-image.sh simpleimage-pine64-latest.img.xz linux-pine64-latest.tar.xz xenial)

echo -e "\n[openHABian] Cleaning up... "
mv $buildfolder/xenial-pine64-*.img .
rm -rf $buildfolder
for file in xenial-*.img; do
  tar -cJf $file.xz $file
done
for file in xenial-*.*; do
  mv -v "$file" "${file//pine64/openhabianpine64}"
done

echo -e "\n[openHABian] Finished! The results:"
ls -al xenial-openhabianpine64-*.*

# vim: filetype=sh
