#!/usr/bin/env bash

whiptail_check() {
  if ! command -v whiptail &>/dev/null; then
    echo -n "$(timestamp) [openHABian] Installing whiptail... "
    cond_redirect apt update
    cond_redirect apt -y install whiptail
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  fi
}

system_upgrade() {
  echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
  cond_redirect apt update
  cond_redirect apt --yes upgrade
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

basic_packages() {
  echo -n "$(timestamp) [openHABian] Installing basic can't-be-wrong packages (screen, vim, ...)... "
  cond_redirect apt update
  apt remove raspi-config &>/dev/null || true
  cond_redirect apt -y install screen vim nano mc vfu bash-completion htop curl wget multitail git bzip2 zip unzip \
                               xz-utils software-properties-common man-db whiptail acl usbutils dirmngr arping
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

needed_packages() {
  # Install apt-transport-https - update packages through https repository
  # Install bc + sysstat - needed for FireMotD
  # Install avahi-daemon - hostname based discovery on local networks
  # Install python/python-pip - for python packages
  echo -n "$(timestamp) [openHABian] Installing additional needed packages... "
  #cond_redirect apt update
  cond_redirect apt -y install apt-transport-https bc sysstat avahi-daemon python python-pip avahi-autoipd
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

  if is_pithree || is_pithreeplus || is_pizerow; then
    echo -n "$(timestamp) [openHABian] Installing additional bluetooth packages... "
    cond_redirect apt -y install bluez python-bluez python-dev libbluetooth-dev raspberrypi-sys-mods pi-bluetooth
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  fi
}

timezone_setting() {
  source "$CONFIGFILE"
  if [ -n "$INTERACTIVE" ]; then
    echo -n "$(timestamp) [openHABian] Setting timezone based on user choice... "
    dpkg-reconfigure tzdata
  elif [ ! -z "${timezone+x}" ]; then
    echo -n "$(timestamp) [openHABian] Setting timezone based on openhabian.conf... "
    cond_redirect timedatectl set-timezone $timezone
  else
    echo -n "$(timestamp) [openHABian] Setting timezone based on IP geolocation... "
    if ! command -v tzupdate &>/dev/null; then
      cond_redirect apt update
      cond_redirect apt -y install python-pip
      cond_redirect pip install --upgrade tzupdate
      if [ $? -ne 0 ]; then echo "FAILED (pip)"; return 1; fi
    fi
    cond_redirect pip install --upgrade tzupdate
    cond_redirect tzupdate
  fi
  if [ $? -eq 0 ]; then echo -e "OK ($(cat /etc/timezone))"; else echo "FAILED"; return 1; fi
}

locale_setting() {
  if [ -n "$INTERACTIVE" ]; then
    echo "$(timestamp) [openHABian] Setting locale based on user choice... "
    dpkg-reconfigure locales
    loc=$(grep "LANG=" /etc/default/locale | sed 's/LANG=//g')
    cond_redirect update-locale LANG=$loc LC_ALL=$loc LC_CTYPE=$loc LANGUAGE=$loc
    whiptail --title "Change Locale" --msgbox "For the locale change to take effect, please reboot your system now." 10 60
    return 0
  fi

  echo -n "$(timestamp) [openHABian] Setting locale based on openhabian.conf... "
  source "$CONFIGFILE"
  if is_ubuntu; then
    cond_redirect locale-gen $locales
  else
    for loc in $locales; do sed -i "/$loc/s/^# //g" /etc/locale.gen; done
    cond_redirect locale-gen
  fi
  cond_redirect dpkg-reconfigure --frontend=noninteractive locales
  cond_redirect LANG=$system_default_locale; export LANG &>/dev/null
  cond_redirect LC_ALL=$system_default_locale; export LC_ALL &>/dev/null
  cond_redirect LC_CTYPE=$system_default_locale; export LC_CTYPE &>/dev/null
  cond_redirect LANGUAGE=$system_default_locale; export LANGUAGE &>/dev/null
  cond_redirect update-locale LANG=$system_default_locale LC_ALL=$system_default_locale LC_CTYPE=$system_default_locale LANGUAGE=$system_default_locale
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

hostname_change() {
  echo -n "$(timestamp) [openHABian] Setting hostname of the base system... "
  if [ -n "$INTERACTIVE" ]; then
    new_hostname=$(whiptail --title "Change Hostname" --inputbox "Please enter the new system hostname (no special characters, no spaces):" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 1; fi
    if ( echo "$new_hostname" | grep -q ' ' ) || [ -z "$new_hostname" ]; then
      whiptail --title "Change Hostname" --msgbox "The hostname you've entered is not a valid hostname. Please try again." 10 60
      echo "FAILED"
      return 1
    fi
  else
    source "$CONFIGFILE"
    new_hostname="$hostname"
  fi
  hostnamectl set-hostname "$new_hostname" &>/dev/null
  hostname "$new_hostname" &>/dev/null
  echo "$new_hostname" > /etc/hostname
  sed -i "s/127.0.1.1.*/127.0.1.1 $new_hostname/" /etc/hosts

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Change Hostname" --msgbox "For the hostname change to take effect, please reboot your system now." 10 60
  fi
  echo "OK"
}

bashrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned bash config files to system... "
  cp $BASEDIR/includes/bash.bashrc /etc/bash.bashrc
  cp $BASEDIR/includes/bashrc-root /root/.bashrc
  cp $BASEDIR/includes/bash_profile /home/$username/.bash_profile
  chown $username:$username /home/$username/.bash_profile
  echo "OK"
}

vimrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned vim config file to system... "
  cp $BASEDIR/includes/vimrc /etc/vim/vimrc
  echo "OK"
}

srv_bind_mounts() {
  echo -n "$(timestamp) [openHABian] Preparing openHAB folder mounts under /srv/... "
  sed -i "\#[ \t]/srv/openhab2-#d" /etc/fstab
  sed -i "/^$/d" /etc/fstab
  (
    echo ""
    echo "/usr/share/openhab2          /srv/openhab2-sys           none bind 0 0"
    echo "/etc/openhab2                /srv/openhab2-conf          none bind 0 0"
    echo "/var/lib/openhab2            /srv/openhab2-userdata      none bind 0 0"
    echo "/var/log/openhab2            /srv/openhab2-logs          none bind 0 0"
    echo "/usr/share/openhab2/addons   /srv/openhab2-addons        none bind 0 0"
  ) >> /etc/fstab
  cond_redirect cat /etc/fstab
  cond_redirect mkdir -p /srv/openhab2-{sys,conf,userdata,logs,addons}
  cond_redirect cp $BASEDIR/includes/srv_readme.txt /srv/README.txt
  cond_redirect chmod ugo+w /srv /srv/README.txt
  cond_redirect mount --all --verbose
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

permissions_corrections() {
  echo -n "$(timestamp) [openHABian] Applying file permissions recommendations... "
  if ! id -u openhab &>/dev/null; then
    echo "FAILED (please execute after openHAB was installed)"
    exit 1
  fi

  if is_pine64; then
    cond_redirect groupadd gpio
    cond_redirect cp $BASEDIR/includes/PINE64-80-gpio-noroot.rules /etc/udev/rules.d/80-gpio-noroot.rules
    cond_redirect sed -i -e '$i \chown -R root:gpio /sys/class/gpio \n' /etc/rc.local
    cond_redirect sed -i -e '$i \chmod -R ug+rw /sys/class/gpio \n' /etc/rc.local
  fi

  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect adduser openhab gpio
  cond_redirect adduser openhab audio
  cond_redirect adduser $username openhab
  cond_redirect adduser $username dialout
  cond_redirect adduser $username tty
  cond_redirect adduser $username gpio
  cond_redirect adduser $username audio
  #
  openhab_folders=(/etc/openhab2 /var/lib/openhab2 /var/log/openhab2 /usr/share/openhab2/addons)
  cond_redirect chown openhab:$username /srv /srv/README.txt
  cond_redirect chmod ugo+w /srv /srv/README.txt
  cond_redirect chown -R openhab:openhab /usr/share/openhab2
  cond_redirect chown -R openhab:$username /opt ${openhab_folders[@]}
  cond_redirect chmod -R ug+wX /opt ${openhab_folders[@]}
  cond_redirect chown -R $username:$username /home/$username
  #
  cond_redirect setfacl -R --remove-all ${openhab_folders[@]}
  cond_redirect setfacl -R -m g::rwX ${openhab_folders[@]}
  cond_redirect setfacl -R -m d:g::rwX ${openhab_folders[@]}
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

misc_system_settings() {
  echo -n "$(timestamp) [openHABian] Applying miscellaneous system settings... "
  cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' $(realpath /usr/bin/java)
  if is_pine64; then cond_redirect dpkg --add-architecture armhf; fi
  # user home note
  echo -e "This is your linux user's \"home\" folder.\nPlace personal files, programs or scripts here." > /home/$username/README.txt
  # prepare SSH key file for the end user
  mkdir /home/$username/.ssh
  chmod 700 /home/$username/.ssh
  touch /home/$username/.ssh/authorized_keys
  chmod 600 /home/$username/.ssh/authorized_keys
  chown -R $username:$username /home/$username/.ssh
  # A distinguishable apt User-Agent
  echo "Acquire { http::User-Agent \"Debian APT-HTTP/1.3 openHABian\"; };" > /etc/apt/apt.conf.d/02useragent
  #
  echo "OK"
}

pine64_platform_scripts() {
  echo -n "$(timestamp) [openHABian] Executing pine64 platform scripts (longsleep)... "
  if [ -f "/usr/local/sbin/pine64_update_kernel.sh" ]; then
    cond_redirect /usr/local/sbin/pine64_update_kernel.sh || echo -n "FAILED (kernel) "
    cond_redirect /usr/local/sbin/pine64_update_uboot.sh || echo -n "FAILED (uboot) "
    cond_redirect /usr/local/sbin/pine64_fix_whatever.sh || echo -n "FAILED (whatever) "
    cond_redirect /usr/local/sbin/resize_rootfs.sh || echo -n "FAILED (resize) "
    echo "OK"
  else
    echo "FAILED"
  fi
}

pine64_fix_systeminfo_binding() { # This will maybe be fixed upstreams some day. Keep an eye open.
  echo -n "$(timestamp) [openHABian] Enable PINE64 support for systeminfo binding... "
  cond_redirect apt install -y udev:armhf
  cond_redirect ln -s /lib/arm-linux-gnueabihf/ /lib/linux-arm
  cond_redirect ln -s /lib/linux-arm/libudev.so.1 /lib/linux-arm/libudev.so
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

pine64_fixed_mac() {
  echo -n "$(timestamp) [openHABian] Assigning fixed MAC address to eth0 (longsleep)... "
  if ! grep -q "mac_addr=" /boot/uEnv.txt; then
    MAC=$(cat /sys/class/net/eth0/address)
    sed -i "/^console=/ s/$/ mac_addr=$MAC/" /boot/uEnv.txt
    echo "OK"
  else
    echo "SKIPPED"
  fi
}

# RPi specific function
memory_split() {
  echo -n "$(timestamp) [openHABian] Setting the GPU memory split down to 16MB for headless system... "
  if grep -q "gpu_mem" /boot/config.txt; then
    sed -i 's/gpu_mem=.*/gpu_mem=16/g' /boot/config.txt
  else
    echo "gpu_mem=16" >> /boot/config.txt
  fi
  echo "OK"
}

# RPi specific function
enable_rpi_audio() {
  echo -n "$(timestamp) [openHABian] Enabling Audio output... "
  if ! grep -q "dtparam=audio" /boot/config.txt; then
    echo "dtparam=audio=on" >> /boot/config.txt
  fi
  cond_redirect adduser openhab audio
  cond_redirect adduser $username audio
  echo "OK"
}

prepare_serial_port() {
  introtext="Proceeding with this routine, the serial console normally provided by a Raspberry Pi can be disabled for the sake of a usable serial port. The provided port can henceforth be used by devices like Razberry, UZB or Busware SCC.
On a Raspberry Pi 3 the Bluetooth module can additionally be disabled, ensuring the operation of a Razberry (mutually exclusive).
Finally, all common serial ports can be made accessible to the openHAB java virtual machine.
\nPlease make your choice:"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="All done. After a reboot the serial console will be available via /dev/ttyAMA0 or /dev/ttyS0 (depends on your device)."
  # \nThis might be a good point in time to update your Raspberry Pi firmware (if this is a RPi) and reboot:\n
  # sudo rpi-update
  # sudo reboot"

  echo -n "$(timestamp) [openHABian] Configuring serial console for serial port peripherals... "

  # Find current settings
  if is_pi && grep -q "enable_uart=1" /boot/config.txt; then sel_1="ON"; else sel_1="OFF"; fi
  if is_pithree || is_pithreeplus && grep -q "dtoverlay=pi3-miniuart-bt" /boot/config.txt; then sel_2="ON"; else sel_2="OFF"; fi
  if grep -q "serial ports added by openHABian" /etc/default/openhab2; then sel_3="ON"; else sel_3="OFF"; fi

  if [ -n "$INTERACTIVE" ]; then
    selection=$(whiptail --title "Prepare Serial Port" --checklist --separate-output "$introtext" 20 78 3 \
    "1"  "(RPi) Disable serial console           (Razberry, SCC, Enocean)" $sel_1 \
    "2"  "(RPi3) Disable Bluetooth module        (Razberry)" $sel_2 \
    "3"  "Add common serial ports to openHAB JVM (Razberry, Enocean)" $sel_3 \
    3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then echo "CANCELED"; return 0; fi
  else
    echo "SKIPPED"
    return 0
  fi

  if [[ $selection == *"1"* ]] && is_pi; then
    cond_echo ""
    cond_echo "Adding 'enable_uart=1' to /boot/config.txt"
    if grep -q "enable_uart" /boot/config.txt; then
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
    if is_pithree || is_pithreeplus; then
      #cond_redirect systemctl stop hciuart &>/dev/null
      #cond_redirect systemctl disable hciuart &>/dev/null
      cond_echo "Adding 'dtoverlay=pi3-miniuart-bt' to /boot/config.txt (RPi3)"
      if ! grep -q "dtoverlay=pi3-miniuart-bt" /boot/config.txt; then
        echo "dtoverlay=pi3-miniuart-bt" >> /boot/config.txt
      fi
    else
      cond_echo "Option only available for Raspberry Pi 3."
    fi
  else
    if is_pithree || is_pithreeplus; then
      cond_echo "Removing 'dtoverlay=pi3-miniuart-bt' from /boot/config.txt"
      sed -i '/dtoverlay=pi3-miniuart-bt/d' /boot/config.txt
    fi
  fi

  if [[ $selection == *"3"* ]]; then
    cond_echo "Adding serial ports to openHAB java virtual machine in /etc/default/openhab2"
    sed -i 's#^EXTRA_JAVA_OPTS=.*#EXTRA_JAVA_OPTS="-Xms250m -Xmx350m -Dgnu.io.rxtx.SerialPorts=/dev/ttyUSB0:/dev/ttyS0:/dev/ttyS2:/dev/ttyACM0:/dev/ttyAMA0"  \# serial ports added by openHABian#g' /etc/default/openhab2
  else
    cond_echo "Removing serial ports from openHAB java virtual machine in /etc/default/openhab2"
    sed -i 's#^EXTRA_JAVA_OPTS=.*#EXTRA_JAVA_OPTS="-Xms250m -Xmx350m"#g' /etc/default/openhab2
  fi

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 16 80
  fi
  echo "OK (Reboot needed)"
}
