#!/usr/bin/env bash
set -e

##########################
#### Load help method ####
##########################

## This format timestamp
timestamp() { date +"%F_%T_%Z"; }

## This function format log messages
##
##      echo_process(String message)
##
echo_process() { echo -e "\\e[1;94m$(timestamp) [openHABian] $*\\e[0m"; }

## Function for identify and returning current active git repository and branch
##
## Return answer in global variable $clone_string
##
get_git_repo() {
  local repo_url repo_branch user_name repo_name
  repo_url=$(git remote get-url origin)
  repo_branch=$(git branch | grep "\*" | cut -d ' ' -f2)
  if [[ ! $repo_url = *"https"* ]]; then
    # Convert URL from SSH to HTTPS
    user_name=$(echo "$repo_url" | sed -Ene's#git@github.com:([^/]*)/(.*).git#\1#p')
    if [[ -z "$user_name" ]]; then
      echo_process "Could not identify git user while converting to SSH URL. Exiting."
      exit 1
    fi
    repo_name=$(echo "$repo_url" | sed -Ene's#git@github.com:([^/]*)/(.*).git#\2#p')
    if [[ -z "$repo_name" ]]; then
      echo_process "Could not identify git repo while converting to SSH URL. Exiting."
      exit 1
    fi
    repo_url="https://github.com/${user_name}/${repo_name}.git"
  fi
  clone_string=$repo_branch
  clone_string+=" "
  clone_string+=$repo_url
}

## Function for injecting custom development branch when building images.
## This function will also watermark the image as a test build.
##
## The first parameter shall be the temporary first-boot.sh file used when building the image.
## The global varible $clone_string must be set prior running this function.
##
##    inject_build_repo(String path)
##
inject_build_repo() {
  if [ -z ${clone_string+x} ]; then
    echo_process "inject_build_repo() invoked without clone_string varible set, exiting...."
    exit 1
  fi
  sed -i '$a /usr/bin/apt -y install figlet &>/dev/null' $1
  sed -i '$a echo "#!/bin/sh\n\ntest -x /usr/bin/figlet || exit 0\n\nfiglet \"Test build, Do not use!\" -w 55" > /etc/update-motd.d/04-test-build-text' $1
  sed -i '$a chmod +rx /etc/update-motd.d/04-test-build-text' $1
  sed -i '$a echo "$(timestamp) [openHABian] Warning! This is a test build."' $1
  sed -i "s@master https://github.com/openhab/openhabian.git@$clone_string@g" $1
}

############################
#### Build script start ####
############################

timestamp=$(date +%Y%m%d%H%M)
echo_process "This script will build the openHABian image file."

# Identify hardware platform
if [ "$1" == "rpi" ]; then
  hw_platform="pi-raspbian"
  echo_process "Hardware platform: Raspberry Pi (rpi)"

elif [ "$1" == "pine64" ]; then
  hw_platform="pine64-xenial"
  echo_process "Hardware platform: Pine A64 (pine64)"

else
  echo_process "Please provide a valid hardware platform as first argument, \"rpi\" or \"pine64\"  Exiting."
  exit 0
fi

# Check if a specific repository shall be included
if [ "$2" == "dev-git" ]; then # Use current git repo and branch as a development image
  get_git_repo
  echo_process "Injecting current branch and git repo when building this image, make sure to push local content to:"
  echo_process $clone_string

elif [ "$2" == "dev-url" ]; then # Use custom git server as a development image
  clone_string=$3
  clone_string+=" "
  clone_string+=$4
  echo_process "Injecting current branch and git repo when building this image, make sure to push local content to:"
  echo_process $clone_string
fi

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
  echo_process "This script must be run as root" 1>&2
  exit 1
fi

# Switch to the script folder
cd "$(dirname $0)" || exit 1

# Log everything to a file
exec &> >(tee -a "openhabian-build-$timestamp.log")

# Load config, create temporary build folder, cleanup
sourcefolder=build-image
source $sourcefolder/openhabian.$hw_platform.conf
buildfolder=/tmp/build-$hw_platform-image
imagefile=$buildfolder/$hw_platform.img
umount $buildfolder/boot &>/dev/null || true
umount $buildfolder/root &>/dev/null || true
rm -rf $buildfolder
mkdir $buildfolder

# Prerequisites
echo_process "Downloading prerequisites... "
apt update

# Build PINE64 image
if [ "$hw_platform" == "pine64-xenial" ]; then
  apt-get -y install git wget curl bzip2 zip xz-utils xz-utils build-essential binutils kpartx dosfstools bsdtar qemu-user-static qemu-user libarchive-zip-perl dos2unix
  echo_process "Cloning \"longsleep/build-pine64-image\" project... "
  git clone -b master https://github.com/longsleep/build-pine64-image.git $buildfolder

  echo_process "Downloading aditional files needed by \"longsleep/build-pine64-image\" project... "
  wget -nv -P $buildfolder/ https://www.stdin.xyz/downloads/people/longsleep/pine64-images/simpleimage-pine64-latest.img.xz
  wget -nv -P $buildfolder/ https://www.stdin.xyz/downloads/people/longsleep/pine64-images/linux/linux-pine64-latest.tar.xz

  echo_process "Copying over 'rc.local' and 'first-boot.sh' for image integration... "
  cp $sourcefolder/rc.local $buildfolder/simpleimage/openhabianpine64.rc.local
  cp $sourcefolder/first-boot.sh $buildfolder/simpleimage/openhabianpine64.first-boot.sh
  sed -i -e '1r functions/helpers.sh' $buildfolder/simpleimage/openhabianpine64.first-boot.sh # Add platform identification
  cp $sourcefolder/openhabian.$hw_platform.conf $buildfolder/simpleimage/openhabian.conf
  unix2dos $buildfolder/simpleimage/openhabian.conf
  cp $sourcefolder/webif.sh $buildfolder/simpleimage/webif.sh

  # Injecting development git repo if clone_string is set and watermark build
  if ! [ -z ${clone_string+x} ]; then
    inject_build_repo $buildfolder/simpleimage/openhabianpine64.first-boot.sh
  fi

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
  echo "touch \$BOOT/first-boot.log" >> $makescript
  echo "cp ./openhabian.conf \$BOOT/openhabian.conf" >> $makescript
  echo "cp ./webif.sh \$BOOT/webif.sh" >> $makescript
  echo "echo \"openHABian preparations finished, /etc/rc.local in place\"" >> $makescript
  echo_process "Executing \"build-pine64-image\" build script... "
  (cd $buildfolder; /bin/bash build-pine64-image.sh simpleimage-pine64-latest.img.xz linux-pine64-latest.tar.xz xenial)
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  mv $buildfolder/xenial-pine64-*.img $imagefile
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# Build Raspberry Pi image
elif [ "$hw_platform" == "pi-raspbian" ]; then
  apt-get -y install git wget curl unzip kpartx libarchive-zip-perl dos2unix
  echo_process "Downloading latest Raspbian Lite image... "
  if [ -f "raspbian.zip" ]; then
    echo "(Using local copy...)"
    cp raspbian.zip $buildfolder/raspbian.zip
  else
    wget -nv -O $buildfolder/raspbian.zip "https://downloads.raspberrypi.org/raspbian_lite_latest"
  fi
  echo_process "Unpacking image... "
  unzip $buildfolder/raspbian.zip -d $buildfolder
  mv $buildfolder/*raspbian*.img $imagefile

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
  sed -i -e '1r functions/helpers.sh' $buildfolder/boot/first-boot.sh # Add platform identification
  touch $buildfolder/boot/first-boot.log
  cp $sourcefolder/openhabian.$hw_platform.conf $buildfolder/boot/openhabian.conf
  unix2dos $buildfolder/boot/openhabian.conf
  cp $sourcefolder/webif.sh $buildfolder/boot/webif.sh
  touch $buildfolder/root/opt/openHABian-install-inprogress

  # Injecting development git repo if clone_string is set and watermark build
  if ! [ -z ${clone_string+x} ]; then
    inject_build_repo $buildfolder/boot/first-boot.sh
  fi

  echo_process "Closing up image file... "
  sync
  umount $buildfolder/boot
  umount $buildfolder/root
  kpartx -dv $imagefile
fi

echo_process "Moving image and cleaning up... "
shorthash=$(git log --pretty=format:'%h' -n 1)
crc32checksum=$(crc32 $imagefile)
destination="openhabian-$hw_platform-$timestamp-git$shorthash-crc$crc32checksum.img"
mv -v $imagefile "$destination"
rm -rf $buildfolder

echo_process "Compressing image... "
xz --verbose --compress --keep "$destination"
crc32checksum=$(crc32 "$destination.xz")
mv "$destination.xz" "openhabian-$hw_platform-$timestamp-git$shorthash-crc$crc32checksum.img.xz"

echo_process "Finished! The results:"
ls -alh "openhabian-$hw_platform-$timestamp"*

# vim: filetype=sh
