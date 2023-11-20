#!/usr/bin/env bash
# shellcheck disable=SC2016,SC1090,SC1091
set -e

####################################################################
#### dummy: changed this line 19 times to force another image build
####################################################################

usage() {
  echo -e "Usage: $(basename "$0") <platform> [oldstable]"
  echo -e "\\nCurrently supported platforms: rpi, rpi64"
}

cleanup_build() {
  if [[ -z "$buildFolder" ]]; then exit 1; fi

  umount "${buildFolder}/boot" &> /dev/null || true
  umount "${buildFolder}/root" &> /dev/null || true
  guestunmount --no-retry "${buildFolder}/boot" &> /dev/null || true
  guestunmount --no-retry "${buildFolder}/root" &> /dev/null || true

  rm -rf "$buildFolder"
}

##########################
#### Load help method ####
##########################
# shellcheck source=functions/helpers.bash
source "$(dirname "$0")"/functions/helpers.bash
# shellcheck source=functions/java-jre.bash
source "$(dirname "$0")"/functions/java-jre.bash
# shellcheck source=functions/packages.bash
source "$(dirname "$0")"/functions/packages.bash
# shellcheck source=functions/packages.bash
source "$(dirname "$0")"/functions/nodejs-apps.bash
# shellcheck source=functions/zram.bash
source "$(dirname "$0")"/functions/zram.bash

## This function formats log messages
##
##    echo_process(String message)
##
echo_process() {
  echo -e "${COL_CYAN}$(timestamp) [openHABian] ${*}${COL_DEF}"
}

## Function for checking if a command is available.
##
## First parameter: list of commands
## Second parameter: list of packets (may be omitted if all packages are named similar as the commands)
##
## Checks if all commands in $1 are available. If not, it proposes to install the packages
## listed in $2 and exits with exit code 1.
##
##    check_command_availability_and_exit()
##
check_command_availability_and_exit() {
  read -ra CMD <<< "$1"
  for i in "${CMD[@]}"; do
    if [[ -z $(command -v "$i") ]]; then
          echo_process "Command $i is missing on your system." 1>&2
          PKG="$2"
          if [[ -z "$PKG" ]]; then PKG="$1"; fi;
          echo_process "Please run the following command: sudo apt-get install $PKG" 1>&2
          exit 1
    fi
  done
}

## Mount RPi Image with userspace tools, for docker we use kpartx
##
##    mount_image_file_boot(String imageFile, String buildFolder)
##
mount_image_file_boot() {
  local imageFile="$1"
  local buildFolder="$2"
  local loopPrefix

  if ! running_in_docker && ! running_on_github && ! is_pi; then
    guestmount --format=raw -o uid="$EUID" -a "$imageFile" -m /dev/sda1 "${2}/boot"
  else
    loopPrefix="$(kpartx -asv "$imageFile" | grep -oE "loop([0-9]+)" | head -n 1)"
    mount -o rw -t vfat "/dev/mapper/${loopPrefix}p1" "${buildFolder}/boot"
  fi
  df -h "${buildFolder}/boot"
}

## Unmount RPi Image with userspace tools, for docker we use kpartx
##
##    umount_image_file_boot(String imageFile, String buildFolder)
##
umount_image_file_boot() {
  local imageFile="$1"
  local buildFolder="$2"

  if ! running_in_docker && ! running_on_github && ! is_pi; then
    guestunmount "${buildFolder}/boot"
  else
    umount "${buildFolder}/boot"
    kpartx -d "$imageFile"
  fi
}

## Mount RPi Image with userspace tools, for docker we use kpartx
##
##    mount_image_file_root(String imageFile, String buildFolder)
##
mount_image_file_root() {
  local imageFile="$1"
  local buildFolder="$2"
  local loopPrefix

  if ! running_in_docker && ! running_on_github && ! is_pi; then
    guestmount --format=raw -o uid="$EUID" -a "$imageFile" -m /dev/sda2 "${buildFolder}/root"
  else
    loopPrefix="$(kpartx -asv "$imageFile" | grep -oE "loop([0-9]+)" | head -n 1)"
    e2fsck -y -f "/dev/mapper/${loopPrefix}p2" &> /dev/null
    resize2fs "/dev/mapper/${loopPrefix}p2" &> /dev/null
    mount -o rw -t ext4 "/dev/mapper/${loopPrefix}p2" "${buildFolder}/root"
  fi
  df -h "${buildFolder}/root"
}

## Unmount RPi Image with userspace tools, for docker we use kpartx
##
##    umount_image_file_root(String imageFile, String buildFolder)
##
umount_image_file_root() {
  local imageFile="$1"
  local buildFolder="$2"

  if ! running_in_docker && ! running_on_github && ! is_pi; then
    guestunmount "${buildFolder}/root"
  else
    umount "${buildFolder}/root"
    kpartx -d "$imageFile"
  fi
}

## Make offline install modifications to code using systemd-nspawn
##
##    offline_install_modifications(String imageFile, String mountFolder)
##
offline_install_modifications() {
  local imageFile="$1"
  local mountFolder="$2"
  local loopPrefix

  if running_on_github; then
    echo_process "Caching packages for offline install..."
    loopPrefix="$(kpartx -asv "$imageFile" | grep -oE "loop([0-9]+)" | head -n 1)"
    mount -o rw -t ext4 "/dev/mapper/${loopPrefix}p2" "$mountFolder"
    mount -o rw -t vfat "/dev/mapper/${loopPrefix}p1" "${mountFolder}/boot"
    systemd-nspawn --directory="$2" /opt/openhabian/build-image/offline-install-modifications.bash &> /dev/null
    sync
    df -h "$mountFolder"
    df -h "${mountFolder}/boot"
    umount "${mountFolder}/boot"
    umount "$mountFolder"
    e2fsck -y -f "/dev/mapper/${loopPrefix}p2" &> /dev/null
    zerofree "/dev/mapper/${loopPrefix}p2" &> /dev/null
    sleep 30
    kpartx -d "$imageFile"
  fi
}

## Grow root partition and file system of a downloaded RaspiOS image
## Root partition if #2 and sector size is 512 bytes for RaspiOS image
## Arguments: $1 = filename of image
##            $2 = number of MBs to grow image by
##
##    grow_image(String image, int extraSize)
##
grow_image() {
  local partition="2"

  qemu-img resize "$1" "+${2}M" &> /dev/null
  echo ", +" | PATH=$PATH:/sbin sfdisk -N "$partition" "$1" &> /dev/null
}


############################
#### Build script start ####
############################

timestamp="$(printf "%(%Y%m%d%H%M)T\\n" "-1")"
echo_process "This script will build the openHABian image file."

# Identify hardware platform
if [ "$1" == "rpi" ]; then
  hwPlatform="pi-raspios32"
  echo_process "Hardware platform: Raspberry Pi (rpi)"

elif [ "$1" == "rpi64" ]; then
  hwPlatform="pi-raspios64"
  echo_process "Hardware platform: Raspberry Pi (rpi64)"

elif [ "$1" == "local-test" ]; then
  echo_process "Preparing local system for installation"
  cp ./build-image/first-boot.bash /boot/first-boot.bash
  cp ./build-image/webserver.bash /boot/webserver.bash
  cp ./build-image/openhabian.conf /boot/openhabian.conf
  cp "./build-image/openhabian-installer.service$release" /etc/systemd/system/
  ln -sf /etc/systemd/system/openhabian-installer.service /etc/systemd/system/multi-user.target.wants/openhabian-installer.service
  rm -f /opt/openHABian-install-successful
  rm -f /opt/openHABian-install-inprogress
  # Use local filesystem's version of openHABian
  # shellcheck disable=SC2016
  if ! running_in_docker; then
    sed -i 's|$(eval "$(openhabian_update "${clonebranch:-openHAB}" &> /dev/null)") -eq 0|true|' /boot/first-boot.bash
  fi
  chmod +x /boot/first-boot.bash
  chmod +x /boot/webserver.bash
  echo_process "Local system ready for installation test.\\n                                     Run 'systemctl start openhabian-installer' or reboot to initiate!"
  exit 0
else
  usage
  exit 0
fi

getstable="oldstable_"
if [ -n "$2" ]; then
  if [ "$2" == "latest" ]; then
    getstable=""
    release=.since_bookworm
  elif [ "$2" != "oldstable" ]; then
    usage
    exit 1
  fi
fi

trap cleanup_build EXIT ERR

# Switch to the script folder
cd "$(dirname "$0")" || (echo "$(dirname "$0") cannot be accessed."; exit 1)

# Log everything to a file
exec &> >(tee -a "openhabian-build-${timestamp}.log")

# Load config, create temporary build folder, cleanup
sourceFolder="build-image"
if [[ -f "${sourceFolder}/openhabian.${hwPlatform}.conf" ]]; then
  # shellcheck disable=SC1090
  source "${sourceFolder}/openhabian.${hwPlatform}.conf"
else
  # shellcheck disable=SC1090,1091
  source "${sourceFolder}/openhabian.conf"
fi
buildFolder="$(mktemp -d "${TMPDIR:-/tmp}"/openhabian-build-${hwPlatform}-image.XXXXX)"
imageFile="${buildFolder}/${hwPlatform}.img"
extraSize="1000"			# grow image root by this number of MB


# Build Raspberry Pi image
if [[ $hwPlatform == "pi-raspios32" ]] || [[ $hwPlatform == "pi-raspios64" ]]; then
  if [ "$hwPlatform" == "pi-raspios64" ]; then
    baseURL="https://downloads.raspberrypi.org/raspios_${getstable}lite_arm64_latest"
    bits="64"
  else
    baseURL="https://downloads.raspberrypi.org/raspios_${getstable}lite_armhf_latest"
    bits="32"
  fi
  xzURL="$(curl "$baseURL" -s -L -I  -o /dev/null -w '%{url_effective}')"
  xzFile="$(basename "$xzURL")"

  # Prerequisites
  echo_process "Checking prerequisites... "
  requiredCommands="git curl wget crc32 dos2unix xz qemu-img"
  requiredPackages="git curl wget libarchive-zip-perl dos2unix xz-utils qemu-utils"
  if running_in_docker || running_on_github || is_pi; then
    # in docker guestfstools are not used; do not install it and all of its prerequisites
    # -> must be run as root
    if [[ $EUID -ne 0 ]]; then
      echo_process "For use with Docker or on RPi, this script must be run as root" 1>&2
      exit 1
    fi
    requiredCommands+=" kpartx"
    requiredPackages+=" kpartx"
  else
    # if not running in Docker not on a RPi, use userspace tools
    requiredCommands+=" guestmount"
    requiredPackages+=" libguestfs-tools"
  fi
  check_command_availability_and_exit "$requiredCommands" "$requiredPackages"

  if [[ -f $xzFile ]]; then
    echo_process "Using local copy of Raspberry Pi OS (${bits}-bit) image... "
    cp "$xzFile" "${buildFolder}/${xzFile}"
  else
    echo_process "Downloading latest Raspberry Pi OS (${bits}-bit) image (no local copy found)... "
    curl -s -L "$baseURL" -o "$xzFile"
    cp "$xzFile" "${buildFolder}/${xzFile}"
  fi

  #echo_process "Verifying signature of downloaded image... "
  #curl -s -L "$xzURL".sig -o "$buildFolder"/"$xzFile".sig
  #if ! gpg -q --keyserver keyserver.ubuntu.com --recv-key 0x8738CD6B956F460C; then echo "FAILED (download public key)"; exit 1; fi
  #if gpg -q --trust-model always --verify "${buildFolder}/${xzFile}".sig "${buildFolder}/${xzFile}"; then echo "OK"; else echo "FAILED (signature)"; exit 1; fi
  curl -s -L "${baseURL}.sha256" -o "${xzFile}.sha256"
  if sha256sum -c "${xzFile}.sha256"; then echo "OK"; else echo "FAILED (download image checksum fail)"; exit 1; fi

  echo_process "Unpacking image... "
  xz -q "${buildFolder}/${xzFile}" -d
  mv "$buildFolder"/*-raspios-*.img "$imageFile" || true

  if [[ $extraSize -gt 0 ]]; then
    echo_process "Growing root partition of the image by ${extraSize} MB... "
    sizeBefore="$(( $(stat --format=%s "$imageFile") / 1024 / 1024 ))"
    grow_image "$imageFile" "$extraSize"
    sizeAfter="$(( $(stat --format=%s "$imageFile") / 1024 / 1024 ))"
    echo_process "Growing image from ${sizeBefore} MB to ${sizeAfter} MB completed."
  fi

  echo_process "Mounting the image for modifications... "
  mkdir -p "$buildFolder"/boot "$buildFolder"/root "$buildFolder"/mnt
  mount_image_file_root "$imageFile" "$buildFolder"

  echo_process "Setting hostname... "
  # shellcheck disable=SC2154
  sed -i "s/127.0.1.1.*/127.0.1.1 $hostname/" "$buildFolder"/root/etc/hosts
  echo "$hostname" > "$buildFolder"/root/etc/hostname

  installer=openhabian-installer.service
  echo_process "Injecting 'openhabian-installer.service', 'first-boot.bash' and 'openhabian.conf'... "
  cp "${sourceFolder}/${installer}$release" "$buildFolder/root/etc/systemd/system/${installer}"
  ln -s "${buildFolder}/root/etc/systemd/system/${installer}" "$buildFolder"/root/etc/systemd/system/multi-user.target.wants/${installer}

  # Open subshell to make sure we don't hurt the host system if for some reason $buildFolder is not properly set
  echo_process "Setting default runlevel multiuser.target and disabling autologin... "
  (
    cd "$buildFolder"/root/etc/systemd/system/ || exit 1
    rm -rf default.target
    ln -s ../../../lib/systemd/system/multi-user.target default.target
    rm -f getty@tty1.service.d/autologin.conf
  )

  echo_process "Cloning myself from ${repositoryurl:-https://github.com/openhab/openhabian.git}, ${clonebranch:-openHAB} branch... "
  if ! [[ -d ${buildFolder}/root/opt/openhabian ]]; then
    git clone "${repositoryurl:-https://github.com/openhab/openhabian.git}" "$buildFolder"/root/opt/openhabian &> /dev/null
    git -C "$buildFolder"/root/opt/openhabian checkout "${clonebranch:-openHAB}" &> /dev/null
  fi
  touch "$buildFolder"/root/opt/openHABian-install-inprogress

  # Cache zram for offline install.
  (
    echo_process "Downloading zram..."
    install_zram_code "${buildFolder}/root/opt/zram" &> /dev/null
  )

  # Cache FireMotD for offline install.
  (
    echo_process "Downloading FireMotD..."
    firemotd_download "${buildFolder}/root/opt" &> /dev/null
  )

  # Cache frontail for offline install.
  (
    echo_process "Downloading frontail..."
    frontail_download "${buildFolder}/root/opt" &> /dev/null
  )

  sync
  umount_image_file_root "$imageFile" "$buildFolder"

  mount_image_file_boot "$imageFile" "$buildFolder"

  echo_process "Reactivating SSH... "
  touch "$buildFolder"/boot/ssh
  cp "$sourceFolder"/first-boot.bash "$buildFolder"/boot/first-boot.bash
  touch "$buildFolder"/boot/first-boot.log
  if [[ -f "$sourceFolder"/openhabian.${hwPlatform}.conf ]]; then
    unix2dos -q -n "$sourceFolder"/openhabian.${hwPlatform}.conf "$buildFolder"/boot/openhabian.conf
  else
    unix2dos -q -n "$sourceFolder"/openhabian.conf "$buildFolder"/boot/openhabian.conf
  fi
  cp "$sourceFolder"/webserver.bash "$buildFolder"/boot/webserver.bash

  encryptedPassword=$(echo "${defaultPassword:-openhabian}" | openssl passwd -6 -stdin)
  echo "${defaultUser:-openhabian}:${encryptedPassword}" > "$buildFolder"/boot/userconf.txt

  echo_process "Closing up image file... "
  sync
  umount_image_file_boot "$imageFile" "$buildFolder"

  offline_install_modifications "$imageFile" "${buildFolder}/mnt"
fi

echo_process "Moving image and cleaning up... "
shorthash="$(git log --pretty=format:'%h' -n 1)"
crc32checksum="$(crc32 "$imageFile")"
destination="openhabian-${hwPlatform}-${timestamp}-git${shorthash}-crc${crc32checksum}.img"
mv -v "$imageFile" "$destination"
rm -rf "$buildFolder"

echo_process "Compressing image... "
# speedup compression, T0 will use all cores and should be supported by reasonably new versions of xz
xz --verbose --compress --keep -9 -T0 "$destination"
crc32checksum="$(crc32 "${destination}.xz")"
mv "${destination}.xz" "openhabian-${hwPlatform}-${timestamp}-git${shorthash}-crc${crc32checksum}.img.xz"

# generate json-file for integration in raspberry-imager
pathDownload="https://github.com/openhab/openhabian/releases/latest/download"
release_date=$(date "+%Y-%m-%d")
fileE="${destination}"
fileZ="openhabian-${hwPlatform}-${timestamp}-git${shorthash}-crc${crc32checksum}.img.xz"

imageE_size="$(stat -c %s "${fileE}")"
imageZ_size="$(stat -c %s "${fileZ}")"

echo_process "Computing SHA256 message digest of image... "
imageE_sha="$(sha256sum "${fileE}"| cut -d' ' -f1)"
imageZ_sha="$(sha256sum "${fileZ}"| cut -d' ' -f1)"

url="${pathDownload}/${fileZ}"

sed -i -e "s|%release_date%|${release_date}|g" rpi-imager-openhab.json
sed -i -e "s|%url${bits}%|${url}|g" rpi-imager-openhab.json
sed -i -e "s|%imageE_size${bits}%|${imageE_size}|g" rpi-imager-openhab.json
sed -i -e "s|%imageE_sha${bits}%|${imageE_sha}|g" rpi-imager-openhab.json
sed -i -e "s|%imageZ_size${bits}%|${imageZ_size}|g" rpi-imager-openhab.json
sed -i -e "s|%imageZ_sha${bits}%|${imageZ_sha}|g" rpi-imager-openhab.json

echo_process "Finished! The results:"
ls -alh "openhabian-${hwPlatform}-${timestamp}"*
ls -alh "rpi-imager-openhab.json"

# vim: filetype=sh
