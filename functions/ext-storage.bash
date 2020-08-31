#!/usr/bin/env bash

move_root2usb() {
  NEWROOTDEV=/dev/sda
  NEWROOTPART=/dev/sda1

  infotext="DANGEROUS OPERATION, USE WITH PRECAUTION!\\n\\nThis will move your system root from your SD card to a USB device like an SSD or USB stick.\\nATTENTION: this is NOT the recommended method to reduce wearout and failure of the SD card. If that is your intention, stop here and go for ZRAM (menu option 38).\\n\\nIf you still want to proceed,\\n1.) Ensure your RPi model can boot from a device other than the internal SD card reader.\\n2.) Make a backup of your SD card\\n3.) Remove all USB mass storage devices from your Pi\\n4.) Insert the USB device to be used for the new system root.\\n\\nTHIS DEVICE WILL BE COMPLETELY DELETED\\n\\nDo you want to continue at your own risk?"

  if ! is_pi; then
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "Incompatible hardware detected" --msgbox "Move root to USB: this option is for the Raspberry Pi only." 10 60
    fi
    echo "FAILED"; return 1
  fi

  if [ -f /etc/ztab ]; then
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "Incompatible selection detected" --msgbox "Move root to USB must not be used together with ZRAM.\\nIf you want to mitigate SD card corruption, don't move root but stay with ZRAM, it is the proper choice.\\nIf you want to move for other reasons, uninstall ZRAM first then return here." 10 65
    fi
    echo "FAILED"; return 1
  fi
  if ! (whiptail --title "Move system root to '$NEWROOTPART'" --yes-button "Continue" --no-button "Back" --yesno "$infotext" 22 116); then echo "CANCELED"; return 0; fi

  # check if system root is on partition 2 of the SD card
  # since 2017-06, rasbian uses PARTUUID=.... in cmdline.txt and fstab instead of /dev/mmcblk0p2...
  rootonsdcard=false

  # extract rootpart
  rootpart=$(sed "s/.*root=\\([a-zA-Z0-9\\/=-]*\\)\\(.*\\)/\\1/" < /boot/cmdline.txt)

  if [[ $rootpart == *"PARTUUID="* ]]; then
    if blkid -l -t "$rootpart" | grep -q "/dev/mmcblk0p2"; then
      rootonsdcard=true
    fi
  elif [[ $rootpart == "/dev/mmcblk0p2" ]]; then
    rootonsdcard=true
  fi

  # exit if root is not on SDCARD
  if ! [ $rootonsdcard = true ]; then
    infotext="It seems as if your system root is not on the SD card.
       ***Aborting, process cant be started***"
    whiptail --title "System root not on SD card ?" --msgbox "$infotext" 8 78
    return 0
  fi

  # exit if destination is not available
  if ! [[ -b "$NEWROOTPART" ]]; then
    infotext="Seems there is no external storage medium inserted that we could move openHABian root to.\\n***Aborting, process cant be started***"
    whiptail --title "No destination SD card ?" --msgbox "$infotext" 8 78
    return 0
  fi

  srcsize=$(blockdev --getsize64 /dev/mmcblk0)
  destsize=$(blockdev --getsize64 "$NEWROOTDEV")
  if [[ "$srcsize" -gt "$destsize" ]]; then
    infotext="Your internal storage medium is larger than the external device/medium you want to move your root to. This will very likely break your system.\\n\\nDo you still REALLY want to continue ?"
    if ! (whiptail --title "Move system root to '$NEWROOTPART'" --yes-button "Continue" --no-button "Stop" --defaultno --yesno "$infotext" 12 78) then echo "CANCELED"; return 0; fi
  fi

  # check if USB power is already set to 1A, otherwise set it there
  if grep -q -F 'max_usb_current=1' /boot/config.txt; then
     echo "max_usb_current already set, ok"
  else
     echo 'max_usb_current=1' >> /boot/config.txt

     echo
     echo "********************************************************************************"
     # shellcheck disable=SC2086
     echo "REBOOT, run $(basename $0) again and recall menu item 'Move root to USB'"
     echo "********************************************************************************"
     whiptail --title "Reboot needed!" --msgbox "USB had to be set to high power (1A) first. Please REBOOT and RECALL this menu item." 15 78
     exit 0
  fi

  # ask user to be patient ...
  infotext="After confirming with OK, system root will be moved.\\nPlease be patient. This will take 5 to 15 minutes, depending mainly on the speed of your USB device.\\nWhen the process is finished, you will be informed via message box..."

  whiptail --title "Moving system root ..." --msgbox "$infotext" 14 78

  echo "stopping openHAB"
  systemctl stop openhab2

  # delete all old partitions
  # http://www.cyberciti.biz/faq/linux-remove-all-partitions-data-empty-disk
  dd if=/dev/zero of=$NEWROOTDEV  bs=512 count=1

  # https://suntong.github.io/blogs/2015/12/25/use-sfdisk-to-partition-disks
  echo "partitioning on '$NEWROOTDEV'"
  # create one big new partition
  echo ';' | /sbin/sfdisk $NEWROOTDEV


  echo "creating filesys on '$NEWROOTPART'"
  # create new filesystem on partion 1
  mkfs.ext4 -F -L oh_usb $NEWROOTPART

  echo "mounting new root '$NEWROOTPART'"
  mount $NEWROOTPART /mnt

  echo
  echo "**********************************************************************************************************"
  echo "copying root sys, please be patient. Depending on the speed of your USB device, this can take 10 to 15 min"
  echo "**********************************************************************************************************"

  #tar cf - --one-file-system --exclude=/mnt/* --exclude=/proc/* --exclude=/lost+found/* --exclude=/sys/* --exclude=/media/* --exclude=/dev/* --exclude=/tmp/* --exclude=/boot/* --exclude=/run/* / | ( cd /mnt; sudo tar xfp -)
  rsync -aAXH --info=progress2 --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/boot/*"} / /mnt

  echo
  echo "adjusting fstab on new root"
  # adjust system root in fstab
  sed -i "s#$rootpart#$NEWROOTPART#" /mnt/etc/fstab

  echo "adjusting system root in kernel bootline"
  # make a copy of the original cmdline
  cp /boot/cmdline.txt /boot/cmdline.txt.sdcard
  # adjust system root in kernel bootline
  sed -i "s#root=$rootpart#root=$NEWROOTPART#" /boot/cmdline.txt

  echo
  echo "*************************************************************"
  echo "OK, moving system root finished you're all set, PLEASE REBOOT"
  echo
  echo "In the unlikely case that the reboot does not succeed,"
  echo "please put the SD card into another device and copy back"
  echo "/boot/cmdline.txt.sdcard to /boot/cmdline.txt"
  echo "*************************************************************"

  infotext="OK, moving system root finished. PLEASE REBOOT\\nIn the unlikely case that the reboot does not succeed,\\nplease put the SD card into another device and copy back\\n/boot/cmdline.txt.sdcard to /boot/cmdline.txt\\n"
  whiptail --title "Moving system root finished ...." --msgbox "$infotext" 12 78
}
