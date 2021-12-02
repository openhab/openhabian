#!/usr/bin/env bash
set -e

####################################################################
#### dummy: changed this line 19 times to force another image build
####################################################################

usage() {
  echo -e "Usage: $(basename "$0") <platform> [dev-git|dev-url] <branch> <url>"
  echo -e "\\nCurrently supported platforms: rpi, rpi64 (beta)"
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

## Function for identify and returning current active git repository and branch
##
## Returns global variable $cloneString
##
##    get_git_repo()
##
get_git_repo() {
  local repoURL repoBranch userName repoName

  repoURL="$(git remote get-url origin)"
  repoBranch="$(git rev-parse --abbrev-ref HEAD)"

  if ! [[ $repoURL == "https"* ]]; then
    # Convert URL from SSH to HTTPS
    userName="$(echo "$repoURL" | sed -Ene's#git@github.com:([^/]*)/(.*).git#\1#p')"
    if [[ -z $userName ]]; then
      echo_process "Could not identify git user while converting to SSH URL. Exiting."
      exit 1
    fi
    repoName="$(echo "$repoURL" | sed -Ene's#git@github.com:([^/]*)/(.*).git#\2#p')"
    if [[ -z $repoName ]]; then
      echo_process "Could not identify git repo while converting to SSH URL. Exiting."
      exit 1
    fi
    repoURL="https://github.com/${userName}/${repoName}.git"
  fi

  cloneString="${repoBranch} ${repoURL}"
}

## Function for injecting custom development branch when building images.
## This function will also watermark the image as a test build.
##
## The first parameter shall be the temporary first-boot.bash file used when building the image.
## The global varible $cloneString must be set prior running this function.
##
##    inject_build_repo(String path)
##
inject_build_repo() {
  if [[ -z "${cloneString+x}" ]]; then
    echo_process "inject_build_repo() invoked without cloneString variable set, exiting...."
    exit 1
  fi

  sed -i '/if (openhabian-config unattended); then/a echo "$(timestamp) [openHABian] Warning! This is a test build."' "$1"
  sed -i '/if (openhabian-config unattended); then/a chmod +rx /etc/update-motd.d/04-test-build-text' "$1"
  sed -i '/if (openhabian-config unattended); then/a echo "#!/bin/sh\n\ntest -x /usr/bin/figlet || exit 0\n\nfiglet \"Test build, Do not use!\" -w 55" > /etc/update-motd.d/04-test-build-text' "$1"
  sed -i '/if (openhabian-config unattended); then/a apt-get install --yes figlet &> /dev/null' "$1"
  sed -i 's|^clonebranch=.*$|clonebranch='"${clonebranch:-openHAB3}"'|g' "/etc/openhabian.conf"
  sed -i 's|^repositoryurl=.*$|repositoryurl='"${repositoryurl:-https://github.com/openhab/openhabian.git}"'|g' "/etc/openhabian.conf"
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

timestamp="$(date +%Y%m%d%H%M)"
fileTag="" # marking output file for special builds
echo_process "This script will build the openHABian image file."

# Identify hardware platform
if [ "$1" == "rpi" ]; then
  hwPlatform="pi-raspios32"
  echo_process "Hardware platform: Raspberry Pi (rpi)"

elif [ "$1" == "rpi64" ]; then
  hwPlatform="pi-raspios64beta"
  echo_process "Hardware platform: Raspberry Pi (rpi64) - BETA -"

elif [ "$1" == "local-test" ]; then
  echo_process "Preparing local system for installation"
  cp ./build-image/first-boot.bash /boot/first-boot.bash
  cp ./build-image/webserver.bash /boot/webserver.bash
  cp ./build-image/openhabian.conf /boot/openhabian.conf
  cp ./build-image/openhabian-installer.service /etc/systemd/system/
  ln -sf /etc/systemd/system/openhabian-installer.service /etc/systemd/system/multi-user.target.wants/openhabian-installer.service
  rm -f /opt/openHABian-install-successful
  rm -f /opt/openHABian-install-inprogress
  # Use local filesystem's version of openHABian
  # shellcheck disable=SC2016
  if ! running_in_docker; then
    sed -i 's|$(eval "$(openhabian_update "${clonebranch:-openHAB3}" &> /dev/null)") -eq 0|true|' /boot/first-boot.bash
  fi
  chmod +x /boot/first-boot.bash
  chmod +x /boot/webserver.bash
  echo_process "Local system ready for installation test.\n                                     Run 'systemctl start openhabian-installer' or reboot to initiate!"
  exit 0
else
  usage
  exit 0
fi

# Check if a specific repository should be included
if [ "$2" == "dev-git" ]; then # Use current git repo and branch as a development image
  fileTag="custom"
  get_git_repo
  echo_process "Injecting current branch and git repo when building this image, make sure to push local content to:"
  echo_process "$cloneString"
elif [ "$2" == "dev-url" ]; then # Use custom git server as a development image
  fileTag="custom"
  cloneString="$3 $4"
  clonebranch="$3"
  repositoryurl="$4"
  echo_process "Injecting given git repo when building this image, make sure to push local content to:"
  echo_process "$cloneString"
elif [ -n "$2" ]; then
  usage
  exit 1
fi

trap cleanup_build EXIT ERR

# Switch to the script folder
cd "$(dirname "$0")" || (echo "$(dirname "$0") cannot be accessed."; exit 1)

# Log everything to a file
exec &> >(tee -a "openhabian-build-${timestamp}.log")

# Load config, create temporary build folder, cleanup
sourceFolder="build-image"
# shellcheck disable=SC1090
source "${sourceFolder}/openhabian.${hwPlatform}.conf"
buildFolder="$(mktemp -d "${TMPDIR:-/tmp}"/openhabian-build-${hwPlatform}-image.XXXXX)"
imageFile="${buildFolder}/${hwPlatform}.img"
extraSize="1000"			# grow image root by this number of MB

# Build Raspberry Pi image
if [[ $hwPlatform == "pi-raspios32" ]] || [[ $hwPlatform == "pi-raspios64beta" ]]; then
  if [ "$hwPlatform" == "pi-raspios64beta" ]; then
    baseURL="https://downloads.raspberrypi.org/raspios_lite_arm64_latest"
    bits="64"
  else
    baseURL="https://downloads.raspberrypi.org/raspios_lite_armhf_latest"
    bits="32"
  fi
  zipURL="$(curl "$baseURL" -s -L -I  -o /dev/null -w '%{url_effective}')"
  zipFile="$(basename "$zipURL")"

  # Prerequisites
  echo_process "Checking prerequisites... "
  requiredCommands="git curl wget unzip crc32 dos2unix xz qemu-img"
  requiredPackages="git curl wget unzip libarchive-zip-perl dos2unix xz-utils qemu-utils"
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

  if [[ -f $zipFile ]]; then
    echo_process "Using local copy of Raspberry Pi OS (${bits}-bit) image... "
    cp "$zipFile" "${buildFolder}/${zipFile}"
  else
    echo_process "Downloading latest Raspberry Pi OS (${bits}-bit) image (no local copy found)... "
    curl -L "$baseURL" -o "$zipFile"
    cp "$zipFile" "${buildFolder}/${zipFile}"
  fi

  echo_process "Verifying signature of downloaded image... "
  curl -s "$zipURL".sig -o "$buildFolder"/"$zipFile".sig
  if ! gpg -q --keyserver keyserver.ubuntu.com --recv-key 0x8738CD6B956F460C; then echo "FAILED (download public key)"; exit 1; fi
  if gpg -q --trust-model always --verify "${buildFolder}/${zipFile}".sig "${buildFolder}/${zipFile}"; then echo "OK"; else echo "FAILED (signature)"; exit 1; fi

  echo_process "Unpacking image... "
  unzip -q "${buildFolder}/${zipFile}" -d "$buildFolder"
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

  echo_process "Injecting 'openhabian-installer.service', 'first-boot.bash' and 'openhabian.conf'... "
  cp "$sourceFolder"/openhabian-installer.service "$buildFolder"/root/etc/systemd/system/
  ln -s "$buildFolder"/root/etc/systemd/system/openhabian-installer.service "$buildFolder"/root/etc/systemd/system/multi-user.target.wants/openhabian-installer.service

  # Open subshell to make sure we don't hurt the host system if for some reason $buildFolder is not properly set
  echo_process "Setting default runlevel multiuser.target and disabling autologin... "
  (
    cd "$buildFolder"/root/etc/systemd/system/ || exit 1
    rm -rf default.target
    ln -s ../../../lib/systemd/system/multi-user.target default.target
    rm -f getty@tty1.service.d/autologin.conf
  )

  echo_process "Cloning myself from ${repositoryurl:-https://github.com/openhab/openhabian.git}, ${clonebranch:-openHAB3} branch... "
  if ! [[ -d ${buildFolder}/root/opt/openhabian ]]; then
    git clone "${repositoryurl:-https://github.com/openhab/openhabian.git}" "$buildFolder"/root/opt/openhabian &> /dev/null
    git -C "$buildFolder"/root/opt/openhabian checkout "${clonebranch:-openHAB3}" &> /dev/null
  fi
  touch "$buildFolder"/root/opt/openHABian-install-inprogress

  # Cache zram for offline install.
  (
    echo_process "Downloading zram..."
    install_zram_code "${buildFolder}/root/opt/zram" &> /dev/null
  )

  # Cache Java for offline install.
  (
    # Source config to set Java option correctly, this cache currently only works for Zulu.
    # shellcheck disable=SC1090
    source "${sourceFolder}/openhabian.${hwPlatform}.conf"

    echo_process "Downloading Java..."
    # Using variable hw intended for CI only to force use of arm packages.
    # java_zulu_fetch takes version/bits as parameter, but internally uses is_arm
    # to decide if x86/64 or arm packages are downloaded. Parameter works for 32 and 64bit.
    hwarch="armv7l" java_zulu_fetch "${cached_java_opt:-Zulu11-32}" "$buildFolder"/root &> /dev/null
    java_zulu_install_crypto_extension "$(find "$buildFolder"/root/opt/jdk/*/lib -type d -print -quit)/security" &> /dev/null
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
  unix2dos -q -n "$sourceFolder"/openhabian.${hwPlatform}.conf "$buildFolder"/boot/openhabian.conf
  cp "$sourceFolder"/webserver.bash "$buildFolder"/boot/webserver.bash

  # Injecting development git repo if cloneString is set and watermark build
  if [[ -n "${cloneString+x}" ]]; then
    inject_build_repo "$buildFolder"/boot/first-boot.bash
  fi

  echo_process "Closing up image file... "
  sync
  umount_image_file_boot "$imageFile" "$buildFolder"

  offline_install_modifications "$imageFile" "${buildFolder}/mnt"
fi

echo_process "Moving image and cleaning up... "
shorthash="$(git log --pretty=format:'%h' -n 1)"
crc32checksum="$(crc32 "$imageFile")"
destination="openhabian-${hwPlatform}-${timestamp}-git${fileTag}${shorthash}-crc${crc32checksum}.img"
mv -v "$imageFile" "$destination"
rm -rf "$buildFolder"

echo_process "Compressing image... "
# speedup compression, T0 will use all cores and should be supported by reasonably new versions of xz
xz --verbose --compress --keep -9 -T0 "$destination"
crc32checksum="$(crc32 "${destination}.xz")"
mv "${destination}.xz" "openhabian-${hwPlatform}-${timestamp}-git${fileTag}${shorthash}-crc${crc32checksum}.img.xz"

echo_process "Finished! The results:"
ls -alh "openhabian-${hwPlatform}-${timestamp}"*

# vim: filetype=sh
