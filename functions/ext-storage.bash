#!/usr/bin/env bash

move_root2usb() {
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] Move root to USB must be run in interactive mode! Canceling move root to USB!"
    return 0
  fi
  if ! is_pi; then
    echo "$(timestamp) [openHABian] Move root to USB must be run on RPi only! Canceling move root to USB!"
    whiptail --title "Incompatible selection detected!" --msgbox "Move root to USB can only be used on a Raspberry Pi!" 7 80
    return 0
  fi
  if [[ -f /etc/ztab ]]; then
    echo "$(timestamp) [openHABian] Move root to USB must not be used while using ZRAM! Canceling move root to USB!"
    whiptail --title "Incompatible selection detected!" --msgbox "Move root to USB must not be used together with ZRAM.\\n\\nIf you want to mitigate SD card corruption, don't use this but stay with ZRAM, it is the proper choice.\\n\\nIf you want to move for other reasons, uninstall ZRAM first then return here." 13 80
    return 0
  fi

  local newRootDev="/dev/sda"
  local newRootPart="/dev/sda1"
  local introText="DANGEROUS OPERATION, USE WITH PRECAUTION!\\n\\nThis will move your system root from your SD card to a USB device like an SSD or a USB stick.\\nATTENTION: this is NOT the recommended method to reduce wearout and failure of the SD card. If that is your intention, stop here and go for ZRAM (menu option 38).\\n\\nIf you still want to proceed,\\n1.) Ensure your RPi model can boot from a device other than the internal SD card reader.\\n2.) Make a backup of your SD card\\n3.) Remove all USB mass storage devices from your Pi\\n4.) Insert the USB device to be used for the new system root.\\n\\nTHIS DEVICE WILL BE COMPLETELY DELETED!\\n\\nDo you want to continue at your own risk?"
  local rootOnSD
  local rootPart
  local srcSize
  local destSize

  rootPart="$(tr ' ' '\n' < /boot/cmdline.txt | grep 'root=PARTUUID=' | cut -d'=' -f2-)"
  srcSize="$(blockdev --getsize64 /dev/mmcblk0)"
  destSize="$(blockdev --getsize64 "$newRootDev")"

  if ! (whiptail --title "Move system root to '${newRootPart}'?" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 24 80); then echo "CANCELED"; return 0; fi

  # Check if system root is on partition 2 of the SD card since 2017-06, RaspiOS uses PARTUUID=.... in cmdline.txt and fstab instead of /dev/mmcblk0p2
  if [[ $rootPart == "PARTUUID="* ]]; then
    if (blkid -l -t "$rootPart" | grep -qs "/dev/mmcblk0p2"); then
      rootOnSD="true"
    fi
  elif [[ $rootPart == "/dev/mmcblk0p2" ]]; then
    rootOnSD="true"
  fi

  # Exit if root is not on SD card
  if [[ $rootOnSD != "true" ]]; then
    whiptail --title "System root not on SD card!" --msgbox "It seems that your system root is not on the SD card.\\n\\n***Aborting, process cannot be started!***" 9 80
    return 0
  fi

  # Exit if destination is not available
  if ! [[ -b "$newRootPart" ]]; then
    whiptail --title "No destination device?" --msgbox "It seems that there is no external storage medium inserted that we could move openHABian root to.\\n\\n***Aborting, process cannot be started!***" 9 80
    return 0
  fi

  if [[ $srcSize -gt $destSize ]]; then
    if ! (whiptail --title "Destination device to small?" --yes-button "Continue" --no-button "Cancel" --defaultno --yesno "Your internal storage medium is larger than the external device/medium you want to move your root to. This will very likely break your system.\\n\\nDo you still REALLY want to continue?" 10 80); then echo "CANCELED"; return 0; fi
  fi

  # Check if USB power is already unlimited, otherwise set it now
  if ! grep -qsF 'max_usb_current=1' /boot/config.txt; then
    echo -n "$(timestamp) [openHABian] Unlimiting USB power draw... "
    if (echo 'max_usb_current=1' >> /boot/config.txt); then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi
    whiptail --title "Reboot required!" --msgbox "USB power draw had to be unlimited. Please REBOOT and RECALL this menu item." 8 80
    return 0
  fi

  # Check if USB boot delay is on, otherwise set it here
  if ! grep -qsF 'program_usb_timeout=1' /boot/config.txt; then
    echo -n "$(timestamp) [openHABian] Setting USB boot delay... "
    if (echo 'program_usb_timeout=1' >> /boot/config.txt); then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi
    whiptail --title "Reboot required!" --msgbox "USB boot delay had to be set first. Please REBOOT and RECALL this menu item." 8 80
    return 0
  fi

  whiptail --title "Ready to move root?" --yes-button "Continue" --no-button "Cancel" --defaultno --yesno "After final confirmation, the system root will be moved.\\n\\nPlease be patient. This can take from 5 to 15+ minutes, depending mainly on the speed of your USB device.\\n\\nWhen the process is finished, you will be informed via message box." 12 80

  echo -n "$(timestamp) [openHABian] Preparing device '$newRootDev'... "
  if openhab_is_running; then
    cond_echo "\\nStopping openHAB"
    if ! cond_redirect systemctl stop openhab.service; then echo "FAILED (stop openHAB)"; return 1; fi
  fi

  cond_echo "\\nCleaning new root disk"
  if ! cond_redirect dd if=/dev/zero of="$newRootDev" bs=512 count=1; then echo "FAILED (clean new disk)"; return 1; fi

  cond_echo "\\nCreating partition on new root disk"
  if ! (echo ';' | cond_redirect sfdisk "$newRootDev"); then echo "FAILED (partition)"; return 1; fi


  cond_echo "\\nCreating filesystem on new root disk"
  if ! cond_redirect mke2fs -t ext4 -L openHABianFS "$newRootPart"; then echo "FAILED (filesystem)"; return 1; fi

  cond_echo "\\nMounting new root disk"
  if cond_redirect mount "$newRootPart" /mnt; then echo "OK"; else echo "FAILED (mount)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Copying files to device '$newRootDev'... "
  if cond_redirect rsync -axv / /mnt; then echo "OK"; else echo "FAILED"; return 1; fi

  echo -n "$(timestamp) [openHABian] Finalizing move to USB... "
  cond_echo "\\nAdjusting system root in fstab"
  if ! cond_redirect sed -i 's|'"${rootPart}"'|'"${newRootPart}"'|' /mnt/etc/fstab; then echo "FAILED (fstab)"; return 1; fi

  cond_echo "\\nAdjusting system root in cmdline.txt"
  if ! cond_redirect cp /boot/cmdline.txt /boot/cmdline.txt.sdcard; then echo "FAILED (backup cmdline.txt)"; return 1; fi
  if cond_redirect sed -i 's|root='"${rootPart}"'|root='"${newRootPart}"'|' /boot/cmdline.txt; then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi

  whiptail --title "Operation Successful!" --msgbox "The system root has successfully been moved to the USB. PLEASE REBOOT!\\n\\nIn the unlikely case that the reboot does not succeed, please put the SD card into another device and copy back '/boot/cmdline.txt.sdcard' to '/boot/cmdline.txt'." 11 80
}
