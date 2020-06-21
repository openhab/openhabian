#!/usr/bin/env bash

whiptail_check() {
  if ! command -v whiptail &>/dev/null; then
    echo -n "$(timestamp) [openHABian] Installing whiptail... "
    if cond_redirect apt-get install --yes whiptail; then echo "OK"; else echo "FAILED"; exit 1; fi
  fi
}

system_upgrade() {
  echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
  cond_redirect apt-get --yes upgrade
  # shellcheck disable=SC2154
  if cond_redirect java_install_or_update "$java_opt"; then echo "OK"; else echo "FAILED"; return 1; fi
}

basic_packages() {
  echo -n "$(timestamp) [openHABian] Installing basic can't-be-wrong packages (screen, vim, ...)... "
  apt-get remove -y raspi-config &>/dev/null || true
  if cond_redirect apt-get install --yes screen vim nano mc vfu bash-completion htop curl wget multitail git util-linux \
    bzip2 zip unzip xz-utils software-properties-common man-db whiptail acl usbutils dirmngr arping; \
  then echo "OK"; else echo "FAILED"; return 1; fi
}

needed_packages() {
  # Install apt-transport-https - update packages through https repository
  # Install bc + sysstat - needed for FireMotD
  # Install avahi-daemon - hostname based discovery on local networks
  # Install python/python3-pip - for python packages
  echo -n "$(timestamp) [openHABian] Installing additional needed packages... "
  if cond_redirect apt-get install --yes apt-transport-https bc sysstat avahi-daemon python3 python3-pip avahi-autoipd fontconfig; then echo "OK"; else echo "FAILED"; return 1; fi

  if is_pizerow || is_pithree || is_pithreeplus || is_pifour; then
    echo -n "$(timestamp) [openHABian] Installing additional bluetooth packages... "
    local BTPKGS
    BTPKGS="bluez python3-dev libbluetooth-dev raspberrypi-sys-mods pi-bluetooth"
    # phython3-bluez not available in stretch, but in newer distros
    if ! is_stretch; then
      BTPKGS="$BTPKGS python3-bluez"
    fi
    # shellcheck disable=SC2086
    if cond_redirect apt-get install --yes $BTPKGS; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
}

timezone_setting() {
  # shellcheck disable=SC2154
  if [ -n "$INTERACTIVE" ]; then
    echo -n "$(timestamp) [openHABian] Setting timezone based on user choice... "
    dpkg-reconfigure tzdata
  elif [ -n "${timezone+x}" ]; then
    echo -n "$(timestamp) [openHABian] Setting timezone based on openhabian.conf... "
    cond_redirect timedatectl set-timezone "$timezone"
  else
    echo -n "$(timestamp) [openHABian] Setting timezone based on IP geolocation... "
    if ! command -v tzupdate &>/dev/null; then
      cond_redirect apt-get install --yes python3-pip python3-wheel python3-setuptools
      if ! cond_redirect pip3 install --upgrade tzupdate; then echo "FAILED (pip3)"; return 1; fi
    fi
    cond_redirect pip3 install --upgrade tzupdate
    cond_redirect tzupdate
  fi
  # shellcheck disable=SC2181
  if [ $? -eq 0 ]; then echo -e "OK ($(cat /etc/timezone))"; else echo "FAILED"; return 1; fi
}

locale_setting() {
  cond_redirect apt-get -q -y install locales
  if [ -n "$INTERACTIVE" ]; then
    echo "$(timestamp) [openHABian] Setting locale based on user choice... "
    dpkg-reconfigure locales
    loc=$(grep "^[[:space:]]*LANG=" /etc/default/locale | sed 's/LANG=//g')
    cond_redirect update-locale LANG="$loc" LC_ALL="$loc" LC_CTYPE="$loc" LANGUAGE="$loc"
    whiptail --title "Change Locale" --msgbox "For the locale change to take effect, please reboot your system now." 10 60
    return 0
  fi

  echo -n "$(timestamp) [openHABian] Setting locale based on openhabian.conf... "
  if is_ubuntu; then
    # shellcheck disable=2086,2154
    cond_redirect locale-gen $locales
  else
    touch /etc/locale.gen
    for loc in $locales; do sed -i "/$loc/s/^# //g" /etc/locale.gen; done
    cond_redirect locale-gen
  fi
  cond_redirect dpkg-reconfigure --frontend=noninteractive locales
  cond_redirect "LANG=${system_default_locale:-en_US.UTF-8}"
  cond_redirect "LC_ALL=${system_default_locale:-en_US.UTF-8}"
  cond_redirect "LC_CTYPE=${system_default_locale:-en_US.UTF-8}"
  cond_redirect "LANGUAGE=${system_default_locale:-en_US.UTF-8}"
  export LANG LC_ALL LC_CTYPE LANGUAGE
  if cond_redirect update-locale LANG="$system_default_locale" LC_ALL="$system_default_locale" LC_CTYPE="$system_default_locale" LANGUAGE="$system_default_locale"; then echo "OK"; else echo "FAILED"; fi
}

hostname_change() {
  echo -n "$(timestamp) [openHABian] Setting hostname of the base system... "
  if [ -n "$INTERACTIVE" ]; then
    if ! new_hostname=$(whiptail --title "Change Hostname" --inputbox "Please enter the new system hostname (no special characters, no spaces):" 10 60 3>&1 1>&2 2>&3); then return 1; fi
    if ( echo "$new_hostname" | grep -q ' ' ) || [ -z "$new_hostname" ]; then
      whiptail --title "Change Hostname" --msgbox "The hostname you've entered is not a valid hostname. Please try again." 10 60
      echo "FAILED"
      return 1
    fi
  else
    new_hostname="${hostname:-openhab}"
  fi
  hostnamectl set-hostname "$new_hostname" &>/dev/null
  hostname "$new_hostname" &>/dev/null
  echo "$new_hostname" > /etc/hostname
  TMP="$(mktemp /tmp/openhabian.XXXXX)"
  sed "s/127.0.1.1.*/127.0.1.1 $new_hostname/g" /etc/hosts >"$TMP" && cp "$TMP" /etc/hosts
  rm -f "$TMP"

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Change Hostname" --msgbox "For the hostname change to take effect, please reboot your system now." 10 60
  fi
  echo "OK"
}

bashrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned bash config files to system... "
  cp "$BASEDIR"/includes/bash.bashrc /etc/bash.bashrc
  cp "$BASEDIR"/includes/bashrc-root /root/.bashrc
  cp "$BASEDIR"/includes/bash_profile /home/"${username:-openhabian}"/.bash_profile
  chown "$username:$username" /home/"$username"/.bash_profile
  echo "OK"
}

vimrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned vim config file to system... "
  cp "$BASEDIR/includes/vimrc" /etc/vim/vimrc
  echo "OK"
}

create_mount() {
  F=/etc/systemd/system/$(systemd-escape --path /srv/openhab2-"${2}").mount
  sed -e "s|%SRC|$1|g" -e "s|%DEST|$2|g" "$BASEDIR"/includes/mount_template > "$F"
  systemctl -q enable "srv-openhab2\\x2d$2.mount"
  systemctl -q start "srv-openhab2\\x2d$2.mount"
}

srv_bind_mounts() {
  echo -n "$(timestamp) [openHABian] Preparing openHAB folder mounts under /srv/... "
  cond_redirect systemctl is-active --quiet smbd && systemctl stop smbd
  cond_redirect systemctl is-active --quiet zram-config && systemctl stop zram-config
  cond_redirect umount -q /srv/openhab2-{sys,conf,userdata,logs,addons}
  cond_redirect rm -f /etc/systemd/system/srv*.mount
  cond_redirect mkdir -p /srv/openhab2-{sys,conf,userdata,logs,addons}
  cond_redirect cp "$BASEDIR"/includes/srv_readme.txt /srv/README.txt
  cond_redirect chmod ugo+w /srv /srv/README.txt

  cond_redirect create_mount /usr/share/openhab2 sys
  cond_redirect create_mount /etc/openhab2 conf
  cond_redirect create_mount /var/lib/openhab2 userdata
  cond_redirect create_mount /var/log/openhab2 logs
  cond_redirect create_mount /usr/share/openhab2/addons addons

  if [ -f /etc/ztab ]; then systemctl start zram-config; fi
  if [ -f /etc/samba/smb.conf ]; then systemctl start smbd; fi
  echo "OK"
}

permissions_corrections() {
  echo -n "$(timestamp) [openHABian] Applying file permissions recommendations... "
  if ! id -u openhab &>/dev/null; then
    echo "FAILED (please execute after openHAB was installed)"
    return 1
  fi

  for pGroup in audio bluetooth dialout gpio tty
  do
    if getent group "$pGroup" > /dev/null 2>&1 ; then
      cond_redirect adduser openhab "$pGroup"
      cond_redirect adduser "$username" "$pGroup"
    fi
  done
  cond_redirect adduser "$username" openhab

  openhab_folders=(/etc/openhab2 /var/lib/openhab2 /var/log/openhab2 /usr/share/openhab2)
  cond_redirect chown openhab:openhab /srv /srv/README.txt /opt
  cond_redirect chmod ugo+w /srv /srv/README.txt
  cond_redirect chown -R openhab:openhab "${openhab_folders[@]}"
  cond_redirect chmod -R ug+wX /opt "${openhab_folders[@]}"
  cond_redirect chown -R "$username:$username" "/home/$username"

  cond_redirect setfacl -R --remove-all "${openhab_folders[@]}"
  cond_redirect setfacl -R -m g::rwX "${openhab_folders[@]}"
  if cond_redirect setfacl -R -m d:g::rwX "${openhab_folders[@]}"; then echo "OK"; else echo "FAILED"; fi
}

misc_system_settings() {
  echo -n "$(timestamp) [openHABian] Applying miscellaneous system settings... "
  cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' "$(realpath /usr/bin/java)"
  cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' /usr/sbin/arping
  # user home note
  echo -e "This is your linux user's \"home\" folder.\\nPlace personal files, programs or scripts here." > "/home/$username/README.txt"
  # prepare SSH key file for the end user
  mkdir -p /home/"$username"/.ssh
  chmod 700 /home/"$username"/.ssh
  touch /home/"$username"/.ssh/authorized_keys
  chmod 600 /home/"$username"/.ssh/authorized_keys
  chown -R "$username:$username" /home/"$username"/.ssh
  # By default, systemd logs are kept in volatile memory. Relocate to persistent memory to allow log rotation and archiving
  cond_redirect echo "Creating persistent systemd journal folder location: /var/log/journal"
  mkdir -p /var/log/journal
  systemd-tmpfiles --create --prefix /var/log/journal
  cond_redirect echo "Keeping at most 30 days of systemd journal entries"
  journalctl -q --vacuum-time=30d
  # A distinguishable apt User-Agent
  echo "Acquire { http::User-Agent \"Debian APT-HTTP/1.3 openHABian\"; };" > /etc/apt/apt.conf.d/02useragent
  #
  echo "OK"
}


## change system swap size dependent on free space on /
## swap on SD (/var/swap per default) only used after ZRAM swap full if that exists
##
##    change_swapsize(int size in MB)
##
change_swapsize() {
  local totalMemory


  if ! is_raspbian; then return 0; fi

  totalMemory="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
  if [ -z "$totalMemory" ]; then return 1; fi

  swap=$((2*totalMemory))
  minfree=$((2*swap))
  free=$(df -hk / | awk '/dev/ { print $4 }')
  if [ "$free" -ge "$minfree" ]; then
    size=$swap
  elif [ "$free" -ge "$swap" ]; then
    size=$totalMemory
  else
    return 0
  fi
  ((size/=1024))
  echo "$(timestamp) [openHABian] Adjusting swap size to $size MB ... OK"

  # shellcheck disable=SC2086
  sed -i 's/^#*.*CONF_SWAPSIZE=.*/CONF_SWAPSIZE='"$size"'/g' /etc/dphys-swapfile
}

# RPi specific function
memory_split() {
  echo -n "$(timestamp) [openHABian] Setting the GPU memory split down to 16MB for headless system... "
  if grep -qs "^[[:space:]]*gpu_mem" /boot/config.txt; then
    sed -i 's/gpu_mem=.*/gpu_mem=16/g' /boot/config.txt
  else
    echo "gpu_mem=16" >> /boot/config.txt
  fi
  echo "OK"
}

# RPi specific function
enable_rpi_audio() {
  echo -n "$(timestamp) [openHABian] Enabling Audio output... "
  if ! grep -q "^[[:space:]]*dtparam=audio" /boot/config.txt; then
    echo "dtparam=audio=on" >> /boot/config.txt
  fi
  cond_redirect adduser "$username" audio
  echo "OK"
}

prepare_serial_port() {
  introtext="Proceeding with this routine, the serial console normally provided by a Raspberry Pi can be disabled for the sake of a usable serial port. The provided port can henceforth be used by devices like RaZberry, UZB or Busware SCC.
On a Raspberry Pi 3 and 4 the Bluetooth module should be disabled to ensure the operation of a RaZberry or other HAT. Usage of BT and HATs to use serial is mutually exclusive.
\\nPlease make your choice:"
#  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="All done. After a reboot the serial console will be available via /dev/ttyAMA0 or /dev/ttyS0 (depends on your device)."
  # \nThis might be a good point in time to update your Raspberry Pi firmware (if this is a RPi) and reboot:\n
  # sudo rpi-update
  # sudo reboot"

  echo -n "$(timestamp) [openHABian] Configuring serial console for serial port peripherals... "

  # Find current settings
  if is_pi && grep -q "^[[:space:]]*enable_uart=1" /boot/config.txt; then sel_1="ON"; else sel_1="OFF"; fi
  if is_pithree || is_pithreeplus && grep -q "^[[:space:]]*dtoverlay=pi3-miniuart-bt" /boot/config.txt; then sel_2="ON"; else sel_2="OFF"; fi

  if [ -n "$INTERACTIVE" ]; then
    if ! selection=$(whiptail --title "Prepare Serial Port" --checklist --separate-output "$introtext" 20 78 3 \
    "1"  "(RPi) Disable serial console           (RaZberry, SCC, Enocean)" $sel_1 \
    "2"  "(RPi3/4) Disable Bluetooth module      (RaZberry)" $sel_2 \
    3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  else
    echo "SKIPPED"
    return 0
  fi

  if [[ $selection == *"1"* ]] && is_pi; then
    cond_echo ""
    cond_echo "Adding 'enable_uart=1' to /boot/config.txt"
    if grep -Eq "^[[:space:]]*enable_uart" /boot/config.txt; then
      sed -i 's/^.*enable_uart=.*$/enable_uart=1/g' /boot/config.txt
    else
      echo "enable_uart=1" >> /boot/config.txt
    fi
    cond_echo "Removing serial console and login shell from /boot/cmdline.txt and /etc/inittab"
    cp /boot/cmdline.txt /boot/cmdline.txt.bak
    cp /etc/inittab /etc/inittab.bak &>/dev/null
    sed -i 's/console=tty.*console=tty1/console=tty1/g' /boot/cmdline.txt
    sed -i 's/console=serial.*console=tty1/console=tty1/g' /boot/cmdline.txt
    sed -i 's/^T0/\#T0/g' /etc/inittab &>/dev/null
    cond_echo "Disabling serial-getty service"
    cond_redirect systemctl stop serial-getty@ttyAMA0.service
    cond_redirect systemctl disable serial-getty@ttyAMA0.service
    cond_redirect systemctl stop serial-getty@serial0.service
    cond_redirect systemctl disable serial-getty@serial0.service
    cond_redirect systemctl stop serial-getty@ttyS0.service
    cond_redirect systemctl disable serial-getty@ttyS0.service
  else
    cond_echo "ATTENTION: This function is not yet implemented."
    #TODO this needs to be tested when/if someone actually cares...
    #cp /boot/cmdline.txt.bak /boot/cmdline.txt
    #cp /etc/inittab.bak /etc/inittab
  fi

  if [[ $selection == *"2"* ]]; then
    if is_pithree || is_pithreeplus || is_pifour; then
      #cond_redirect systemctl stop hciuart &>/dev/null
      #cond_redirect systemctl disable hciuart &>/dev/null
      cond_echo "Adding 'dtoverlay=miniuart-bt' to /boot/config.txt (RPi3/4)"
      if ! grep -Eq "^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt" /boot/config.txt; then
        echo "dtoverlay=miniuart-bt" >> /boot/config.txt
      fi
    else
      cond_echo "Option only available for Raspberry Pi 3/4."
    fi
  else
    if is_pithree || is_pithreeplus || is_pifour; then
      cond_echo "Removing 'dtoverlay=miniuart-bt' from /boot/config.txt"
      sed -i -E '/^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt/d' /boot/config.txt
    fi
  fi

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 16 80
  fi
  echo "OK (Reboot needed)"
}
