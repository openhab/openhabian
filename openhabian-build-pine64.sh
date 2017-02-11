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

makescript=$buildfolder/simpleimage/make_rootfs.sh

sed -i "s/^pine64$/openHABianPine64/" makescript
sed -i "s/^127.0.1.1 pine64$/127.0.1.1 openHABianPine64/" makescript

echo -e "\n# Add openHABian modifications" >> makescript
cat build-pine64-image/post-image-build.txt >> makescript
(cd $buildfolder; /bin/bash build-pine64-image.sh simpleimage-pine64-latest.img.xz linux-pine64-latest.tar.xz xenial)

# vim: filetype=sh
