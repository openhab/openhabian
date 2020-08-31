#!/usr/bin/env bash

## Function for checking for and installing whiptail.
## This enables the diplay of the interactive menu used by openHABian.
##
##    whiptail_check()
##
whiptail_check() {
  if ! [[ -x $(command -v whiptail) ]]; then
    echo -n "$(timestamp) [openHABian] Installing whiptail... "
    if cond_redirect apt-get install --yes whiptail; then echo "OK"; else echo "FAILED"; exit 1; fi
  fi
}

## Function for upgrading installed packages from apt.
## Additionally, this also updates Java if an update is available.
##
##    system_upgrade()
##
system_upgrade() {
  echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
  if ! cond_redirect apt-get upgrade --yes; then echo "FAILED"; return 1; fi
  if cond_redirect java_install_or_update "${java_opt:-Zulu8-32}"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Function for installing basic Linux packages.
##
##    basic_packages()
##
basic_packages() {
  echo -n "$(timestamp) [openHABian] Installing basic can't-be-wrong packages (screen, vim, ...)... "
  if [[ -x $(command -v raspi-config) ]]; then
    if ! cond_redirect apt-get purge --yes raspi-config; then echo "FAILED (remove raspi-config)"; return 1; fi
  fi
  if cond_redirect apt-get install --yes screen vim nano mc vfu bash-completion \
    htop curl wget multitail git util-linux bzip2 zip unzip xz-utils \
    software-properties-common man-db whiptail acl usbutils dirmngr arping; \
  then echo "OK"; else echo "FAILED"; exit 1; fi
}

## Function for installing additional needed Linux packages.
##
##    needed_packages()
##
needed_packages() {
  local bluetoothPackages

  bluetoothPackages="bluez python3-dev libbluetooth-dev raspberrypi-sys-mods pi-bluetooth"

  # Install apt-transport-https - update packages through https repository
  # Install bc + sysstat - needed for FireMotD
  # Install avahi-daemon - hostname based discovery on local networks
  # Install python3/python3-pip/python3-wheel/python3-setuptools - for python packages
  echo -n "$(timestamp) [openHABian] Installing additional needed packages... "
  if cond_redirect apt-get install --yes apt-transport-https bc sysstat \
    avahi-daemon python3 python3-pip python3-wheel python3-setuptools \
    avahi-autoipd fontconfig; \
  then echo "OK"; else echo "FAILED"; return 1; fi

  if is_pizerow || is_pithree || is_pithreeplus || is_pifour; then
    echo -n "$(timestamp) [openHABian] Installing additional bluetooth packages... "
    # phython3-bluez is not available in stretch so only add it if we are runnning on buster or later
    if ! is_stretch; then
      bluetoothPackages+=" python3-bluez"
    fi
    # shellcheck disable=SC2086
    if cond_redirect apt-get install --yes $bluetoothPackages; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
}

## Function for setting the timezone of the current system.
##
##   The timezone setting will default to the users choice on an INTERACTIVE setup,
## or it will use whatever value is provided in the openhabian.conf file.
##
##   As a last resort, it will default to using the IP geolocation of the user to
## determine the current timezone.
##
##    timezone_setting()
##
timezone_setting() {
  # shellcheck source=/etc/openhabian.conf disable=SC2154
  if [[ -n $INTERACTIVE ]]; then
    echo -n "$(timestamp) [openHABian] Setting timezone based on user choice... "
    if dpkg-reconfigure tzdata; then echo "OK ($(cat /etc/timezone))"; else echo "FAILED"; return 1; fi
  elif [[ -n $timezone ]]; then
    echo -n "$(timestamp) [openHABian] Setting timezone based on openhabian.conf... "
    if cond_redirect timedatectl set-timezone "$timezone"; then echo "OK ($(cat /etc/timezone))"; else echo "FAILED"; return 1; fi
  else
    echo "$(timestamp) [openHABian] Beginning setup of timezone based on IP geolocation... OK"
    if ! dpkg -s 'python3' 'python3-pip' 'python3-wheel' 'python3-setuptools' &> /dev/null; then
      echo -n "$(timestamp) [openHABian] Installing Python for needed packages... "
      if cond_redirect apt-get install --yes python3 python3-pip python3-wheel python3-setuptools; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
    echo -n "$(timestamp) [openHABian] Setting timezone based on IP geolocation... "
    if ! cond_redirect pip3 install --upgrade tzupdate; then echo "FAILED (update tzupdate)"; return 1; fi
    if cond_redirect tzupdate; then echo "OK ($(cat /etc/timezone))"; else echo "FAILED"; return 1; fi
  fi
}

## Enable time synchronization via systemd-timesyncd to NTP servers obtained via DHCP
## RPis have no RTC (hw clock)
## Valid arguments: "enable" or "disable"
##
##    setup_ntp(String option)
##
setup_ntp() {
  if running_in_docker || ! is_raspbian; then
    echo "$(timestamp) [openHABian] Enabling time synchronization using NTP... SKIPPED"
    return 0
  fi

  if [[ $1 == "enable" ]]; then
    echo -n "$(timestamp) [openHABian] Enabling time synchronization using NTP... "
    if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/50-timesyncd.conf /lib/dhcpcd/dhcpcd-hooks/; then echo "FAILED (copy)"; return 1; fi
    if cond_redirect timedatectl set-ntp true; then echo "OK"; else echo "FAILED (enable)"; return 1; fi
  elif [[ $1 == "disable" ]]; then
    echo -n "$(timestamp) [openHABian] Disabling time synchronization using NTP... "
    if ! cond_redirect rm -f /lib/dhcpcd/dhcpcd-hooks/50-timesyncd.conf; then echo "FAILED (delete)"; return 1; fi
    if cond_redirect timedatectl set-ntp false; then echo "OK"; else echo "FAILED (disable)"; return 1; fi
  fi
}

## Function for setting the locale of the current system.
##
##   The locale setting will default to the users choice on an INTERACTIVE setup,
## or it will use whatever value is provided in the openhabian.conf file.
##
##    locale_setting()
##
locale_setting() {
  local locale

  if ! dpkg -s 'locales' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing locales from apt... "
    if cond_redirect apt-get install --yes locales; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  if [[ -n $INTERACTIVE ]]; then
    echo -n "$(timestamp) [openHABian] Setting locale based on user choice... "
    if ! dpkg-reconfigure locales; then echo "FAILED (reconfigure locales)"; return 1; fi
  else
    echo -n "$(timestamp) [openHABian] Setting locale based on openhabian.conf... "
    # shellcheck disable=SC2154,SC2086
    if is_ubuntu; then
      if ! cond_redirect locale-gen $locales; then echo "FAILED (locale-gen)"; return 1; fi
    else
      for loc in $locales; do
         sed -i '/^#[[:space:]]'"${loc}"'/s/^#[[:space:]]//' /etc/locale.gen
      done
      if ! cond_redirect locale-gen; then echo "FAILED (locale-gen)"; return 1; fi
    fi
    if ! cond_redirect dpkg-reconfigure --frontend=noninteractive locales; then echo "FAILED (reconfigure locales)"; return 1; fi
  fi

  if ! locale="$(grep "^[[:space:]]*LANG=" /etc/default/locale | sed 's|LANG=||g')"; then echo "FAILED"; return 1; fi
  if cond_redirect update-locale LANG="${locale:-${system_default_locale:-en_US.UTF-8}}" LC_ALL="${locale:-${system_default_locale:-en_US.UTF-8}}" LC_CTYPE="${locale:-${system_default_locale:-en_US.UTF-8}}" LANGUAGE="${locale:-${system_default_locale:-en_US.UTF-8}}"; then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Change Locale" --msgbox "For the locale change to take effect, please reboot your system now." 7 80
  fi
}

## Function for setting the hostname of the current system.
##
##   The hostname setting will default to the users choice on an INTERACTIVE setup,
## or it will use whatever value is provided in the openhabian.conf file.
##
##    hostname_change()
##
hostname_change() {
  if running_in_docker; then echo "$(timestamp) [openHABian] Setting hostname of the base system... SKIPPED"; return 0; fi

  local newHostname

  if [[ -n $INTERACTIVE ]]; then
    echo -n "$(timestamp) [openHABian] Setting hostname of the base system based on user choice... "
    if ! newHostname=$(whiptail --title "Change Hostname" --inputbox "\\nPlease enter the new system hostname (no special characters, no spaces):" 9 80 3>&1 1>&2 2>&3); then echo "FAILED"; return 1; fi
    if [[ -z $newHostname ]] || ( echo "$newHostname" | grep -q ' ' ); then
      whiptail --title "Change Hostname" --msgbox "The hostname you have entered is not a valid hostname. Please try again." 7 80
      echo "FAILED"
      return 1
    fi
  else
    echo -n "$(timestamp) [openHABian] Setting hostname of the base system based on openhabian.conf... "
    newHostname="${hostname:-openhab}"
  fi

  if ! cond_redirect hostnamectl set-hostname "$newHostname"; then echo "FAILED (hostnamectl)"; return 1; fi
  if sed -i 's|127.0.1.1.*$|127.0.1.1 '"${newHostname}"'|g' /etc/hosts; then echo "OK"; else echo "FAILED (edit hosts)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Change Hostname" --msgbox "For the hostname change to take effect, please reboot your system now." 7 80
  fi
}

## Function for adding tuned bash configuration files to the current system.
##
##    bashrc_copy()
##
bashrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned bash configuration files to system... "
  if ! cp "${BASEDIR:-/opt/openhabian}"/includes/bash.bashrc /etc/bash.bashrc; then echo "FAILED (user bashrc)"; return 1; fi
  if ! cp "${BASEDIR:-/opt/openhabian}"/includes/bashrc-root /root/.bashrc; then echo "FAILED (root bashrc)"; return 1; fi
  if ! cp "${BASEDIR:-/opt/openhabian}"/includes/bash_profile /home/"${username:-openhabian}"/.bash_profile; then echo "FAILED (user bash_profile)"; return 1; fi
  if chown "${username:-openhabian}:${username:-openhabian}" /home/"${username:-openhabian}"/.bash_profile; then echo "OK"; else echo "FAILED (permissions)"; return 1; fi
}

## Function for adding a tuned vim configuration file to the current system.
##
##    vimrc_copy()
##
vimrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned vim configuration file to system... "
  if cp "${BASEDIR:-/opt/openhabian}/includes/vimrc" /etc/vim/vimrc; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Function for adding a mountpoint to the system.
##
##    create_mount(String source, String destination)
##
create_mount() {
  # Docker systemctl replacement does not support mount services
  if running_in_docker; then
    echo "$(timestamp) [openHABian] Creating mount $2 in '/srv/openhab2-${1}'... SKIPPED"
    return 0
  fi

  local destination
  local mountPoint
  local source

  destination="$2"
  mountPoint="$(systemd-escape --path "/srv/openhab2-${destination}" --suffix "mount")"
  source="$1"

  echo -n "$(timestamp) [openHABian] Creating mount $source in '/srv/openhab2-${destination}'... "
  if ! sed -e 's|%SRC|'"${source}"'|g; s|%DEST|'"${destination}"'|g' "${BASEDIR:-/opt/openhabian}"/includes/mount_template > /etc/systemd/system/"$mountPoint"; then echo "FAILED (sed)"; return 1; fi
  if ! cond_redirect systemctl enable --now "$mountPoint"; then echo "FAILED (enable service)"; return 1; fi
}

## Function for adding openHAB folder mountpoints to the /srv/ folder.
##
##    srv_bind_mounts()
##
srv_bind_mounts() {
  echo -n "$(timestamp) [openHABian] Preparing openHAB folder mounts under '/srv/openhab2-*'... "
  if [[ -f /etc/samba/smb.conf ]] && [[ $(systemctl is-active --quiet smbd) ]]; then
    cond_redirect systemctl stop smbd
  fi
  if [[ -f /etc/ztab ]] && [[ $(systemctl is-active --quiet zram-config) ]]; then
    cond_redirect systemctl stop zram-config
  fi

  cond_redirect umount -q /srv/openhab2-{sys,conf,userdata,logs,addons}
  if ! cond_redirect rm -f /etc/systemd/system/srv*.mount; then echo "FAILED (clean mounts)"; return 1; fi
  if ! cond_redirect mkdir -p /srv/openhab2-{sys,conf,userdata,logs,addons}; then echo "FAILED (prepare dirs)"; return 1; fi
  if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/srv_readme.txt /srv/README.txt; then echo "FAILED (copy readme)"; return 1; fi
  if ! cond_redirect chmod ugo+w /srv /srv/README.txt; then echo "FAILED (permissions for readme)"; return 1; fi

  if ! cond_redirect create_mount "/usr/share/openhab2" "sys"; then echo "FAILED (sys)"; return 1; fi
  if ! cond_redirect create_mount "/etc/openhab2" "conf"; then echo "FAILED (conf)"; return 1; fi
  if ! cond_redirect create_mount "/var/lib/openhab2" "userdata"; then echo "FAILED (userdata)"; return 1; fi
  if ! cond_redirect create_mount "/var/log/openhab2" "logs"; then echo "FAILED (logs)"; return 1; fi
  if cond_redirect create_mount "/usr/share/openhab2/addons" "addons"; then echo "OK"; else echo "FAILED (addons)"; return 1; fi

  cond_redirect systemctl -q daemon-reload &> /dev/null

  if [[ -f /etc/ztab ]]; then systemctl restart zram-config; fi
  if [[ -f /etc/samba/smb.conf ]]; then systemctl restart smbd; fi
}

## Function for applying common user account permission settings to system folders.
##
##    permissions_corrections()
##
permissions_corrections() {
  local openhabFolders=(/etc/openhab2 /var/lib/openhab2 /var/log/openhab2 /usr/share/openhab2)
  local openhabHome="/var/lib/openhab2"
  local gpioDir="/sys/devices/platform/soc"

  echo -n "$(timestamp) [openHABian] Applying file permissions recommendations... "
  if ! id -u openhab &> /dev/null; then
    echo "FAILED (please execute after openHAB is installed)"
    return 1
  fi

  for pGroup in audio bluetooth dialout gpio tty
  do
    if getent group "$pGroup" &> /dev/null ; then
      if ! cond_redirect adduser --quiet openhab "$pGroup"; then echo "FAILED (openhab ${pGroup})"; return 1; fi
      if ! cond_redirect adduser --quiet "${username:-openhabian}" "$pGroup"; then echo "FAILED (${username:-openhabian} ${pGroup})"; return 1; fi
    fi
  done
  if ! cond_redirect adduser --quiet "${username:-openhabian}" openhab; then echo "FAILED (${username:-openhabian} openhab)"; return 1; fi

  if ! cond_redirect chown openhab:openhab /srv /srv/README.txt /opt; then echo "FAILED (openhab server mounts)"; return 1; fi
  if ! cond_redirect chmod ugo+w /srv /srv/README.txt; then echo "FAILED (server mounts)"; return 1; fi
  if ! cond_redirect chown -R openhab:openhab "${openhabFolders[@]}"; then echo "FAILED (openhab folders)"; return 1; fi
  if ! cond_redirect chmod -R ug+wX /opt "${openhabFolders[@]}"; then echo "FAILED (folders)"; return 1; fi
  if [[ -d "$openhabHome"/.ssh ]]; then
    if ! cond_redirect chmod -R go-rwx "$openhabHome"/.ssh; then echo "FAILED (set .ssh access)"; return 1; fi
  fi

  if ! cond_redirect chown -R "${username:-openhabian}:${username:-openhabian}" "/home/${username:-openhabian}"; then echo "FAILED (${username:-openhabian} own $HOME)"; return 1; fi

  if ! cond_redirect setfacl -R --remove-all "${openhabFolders[@]}"; then echo "FAILED (reset file access)"; return 1; fi
  if ! cond_redirect setfacl -R -m g::rwX "${openhabFolders[@]}"; then echo "FAILED (set file access)"; return 1; fi
  if cond_redirect setfacl -R -m d:g::rwX "${openhabFolders[@]}"; then echo "OK"; else echo "FAILED"; return 1; fi

  if ! cond_redirect chgrp root /var/log/samba /var/log/unattended-upgrades; then echo "FAILED (3rd party logdir)"; return 1; fi

  if [[ -d /etc/homegear ]]; then
    chown -R root:root /etc/homegear
    find /etc/homegear -type d -print0 | xargs -0 chmod 755
    find /etc/homegear -type f -print0 | xargs -0 chmod 644
    find /etc/homegear -name "*.key" -print0 | xargs -0 chmod 644
    find /etc/homegear -name "*.key" -print0 | xargs -0 chown homegear:homegear
    chown homegear:homegear /etc/homegear/rpcclients.conf
    chmod 400 /etc/homegear/rpcclients.conf
    chown homegear:homegear -R /var/log/homegear

    # homeMatic/homegear controller HM-MOD-RPI-PCB uses GPIO 18 to reset HW
    if ! [[ -d "${gpioDir}/gpio18" ]]; then
      echo "18" > /sys/class/gpio/export
      echo "out" > /sys/class/gpio/gpio/direction
      echo "0" > /sys/class/gpio/gpio/value
    fi
    if ! [[ -d "${gpioDir}/gpio18" ]]; then echo "FAILED (set GPIO 18 access)"; return 1; fi
    chgrp gpio ${gpioDir}/gpio18/*
    chmod g+rw ${gpioDir}/gpio18/*
  fi
}

## Function for applying miscellaneous system settings.
##
##    misc_system_settings()
##
misc_system_settings() {
  echo -n "$(timestamp) [openHABian] Applying miscellaneous system settings... "
  # Set Java and arping file capabilites
  cond_echo "Setting Java and arping file capabilites"
  if ! cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' "$(realpath /usr/bin/java)"; then echo "FAILED (setcap java)"; return 1; fi
  if ! cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' /usr/sbin/arping; then echo "FAILED (setcap arping)"; return 1; fi

  # Add README.txt note to the end user's home folder
  cond_echo "Creating a README note for end user's home folder"
  echo -e "This is your linux user's \"home\" folder.\\nPlace personal files, programs or scripts here." > "/home/${username:-openhabian}/README.txt"

  # Create a SSH key file for the end user
  cond_echo "Creating SSH key files"
  if ! cond_redirect mkdir -p /home/"${username:-openhabian}"/.ssh; then echo "FAILED (create .ssh)"; return 1; fi
  if ! cond_redirect chmod 700 /home/"${username:-openhabian}"/.ssh; then echo "FAILED (set .ssh permissions)"; return 1; fi
  if ! cond_redirect touch /home/"${username:-openhabian}"/.ssh/authorized_keys; then echo "FAILED (create authorized_keys)"; return 1; fi
  if ! cond_redirect chmod 600 /home/"${username:-openhabian}"/.ssh/authorized_keys; then echo "FAILED (set authorized_keys permissions)"; return 1; fi
  if ! cond_redirect chown -R "${username:-openhabian}:${username:-openhabian}" /home/"${username:-openhabian}"/.ssh; then echo "FAILED (chown .ssh)"; return 1; fi

  if is_raspbian || is_raspios; then
    # By default, systemd logs are kept in volatile memory. Relocate to persistent memory to allow log rotation and archiving
    sed -i '/SystemMax/d' /etc/systemd/journald.conf
    echo -e "SystemMaxUse=50M\\nSystemMaxFileSize=10M\\nSystemMaxFiles=5" >> /etc/systemd/journald.conf
    cond_echo "Creating persistent systemd journal folder location: /var/log/journal"
    if ! cond_redirect mkdir -p /var/log/journal; then echo "FAILED (create /var/log/journal)"; return 1; fi
    if ! cond_redirect systemd-tmpfiles --create --prefix /var/log/journal; then echo "FAILED (systemd-tmpfiles)"; return 1; fi
    cond_echo "Keeping at most 30 days of systemd journal entries"
    if ! cond_redirect journalctl --vacuum-time=30d; then echo "FAILED (journalctl)"; return 1; fi
  fi
  # A distinguishable apt User-Agent
  cond_echo "Setting a distinguishable apt User-Agent"
  if echo "Acquire { http::User-Agent \"Debian APT-HTTP/1.3 openHABian\"; };" > /etc/apt/apt.conf.d/02useragent; then echo "OK"; else echo "FAILED (apt User-Agent)"; return 1; fi
}

## Change system swap size dependent on free space on '/swap' on SD
## ('/var/swap' per default) only used after ZRAM swap is full if ZRAM is enabled.
##
##    change_swapsize(int size in MB)
##
change_swapsize() {
  if ! is_pi; then return 0; fi

  local free
  local minFree
  local swap
  local totalMemory

  totalMemory="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
  if [[ -z $totalMemory ]]; then return 1; fi
  swap="$((2*totalMemory))"
  minFree="$((2*swap))"
  free="$(df -hk / | awk '/dev/ { print $4 }')"
  if [[ $free -ge "$minFree" ]]; then
    size=$swap
  elif [[ $free -ge "$swap" ]]; then
    size=$totalMemory
  else
    return 0
  fi
  ((size/=1024))

  echo -n "$(timestamp) [openHABian] Adjusting swap size to $size MB... "
  if ! cond_redirect dphys-swapfile swapoff; then echo "FAILED (swapoff)"; return 1; fi
  if ! cond_redirect sed -i 's|^#*.*CONF_SWAPSIZE=.*$|CONF_SWAPSIZE='"${size}"'|g' /etc/dphys-swapfile; then echo "FAILED (swapfile)"; return 1; fi
  if cond_redirect dphys-swapfile swapon; then echo "OK (reboot required)"; else echo "FAILED (swapon)"; return 1; fi
}

## Reduce the RPi GPU memory to the minimum to allow for the system to utilize
## the maximum amount of memory for Linux operations.
##
##    memory_split()
##
memory_split() {
  if ! is_pi; then return 0; fi
  echo -n "$(timestamp) [openHABian] Setting the GPU memory split down to 16MB for headless system... "
  if grep -qs "^[[:space:]]*gpu_mem" /boot/config.txt; then
    if cond_redirect sed -i 's|gpu_mem=.*$|gpu_mem=16|g' /boot/config.txt; then echo "OK"; else echo "FAILED"; return 1; fi
  else
    if echo "gpu_mem=16" >> /boot/config.txt; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
}

## Enable audio output on the RPi
##
##    enable_rpi_audio()
##
enable_rpi_audio() {
  if ! is_pi; then return 0; fi
  echo -n "$(timestamp) [openHABian] Enabling Audio output... "
  if grep -qs "^[[:space:]]*dtparam=audio" /boot/config.txt; then
    if ! cond_redirect sed -i 's|dtparam=audio.*$|dtparam=audio=on|g' /boot/config.txt; then echo "FAILED"; return 1; fi
  else
    if ! echo "dtparam=audio=on" >> /boot/config.txt; then echo "FAILED"; return 1; fi
  fi
  if cond_redirect adduser "${username:-openhabian}" audio; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Configure serial port options on the RPi
##
##    prepare_serial_port()
##
prepare_serial_port() {
  if ! is_pi; then return 0; fi
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] Serial port setup must be run in interactive mode! Canceling Serial port setup!"
    return 0
  fi

  local introText
  local successText
  local optionOne
  local optionTwo
  local selection

  introText="\\nProceeding with this routine, the serial console normally provided by a Raspberry Pi can be disabled for the sake of a usable serial port. The provided port can henceforth be used by devices like RaZberry, UZB or Busware SCC.\\n\\nOn a Raspberry Pi 3 or 4 the Bluetooth module should be disabled to ensure the proper operation of a RaZberry or other HAT. Usage of Bluetooth and HATs that use serial is mutually exclusive.\\n\\nPlease make your choice:"
  successText="The serial options have successfully been configured!\\n\\nPlease reboot for changes to take effect."
  # Find current settings
  if grep -qs "^[[:space:]]*enable_uart=1" /boot/config.txt; then optionOne="ON"; else optionOne="OFF"; fi
  if is_pithree || is_pithreeplus || is_pifour; then
    if grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt" /boot/config.txt; then
      optionTwo="ON"
    else
      optionTwo="OFF"
    fi
  else
    optionTwo="OFF"
  fi

  echo -n "$(timestamp) [openHABian] Beginning configuration of serial console for serial port peripherals... "
  if selection=$(whiptail --title "Prepare Serial Port" --checklist --separate-output "$introText" 19 80 2 \
  "1"  "(RPi)     Disable serial console    (RaZberry, SCC, Enocean)" $optionOne \
  "2"  "(RPi3/4)  Disable Bluetooth module  (RaZberry)"               $optionTwo \
  3>&1 1>&2 2>&3); then echo "OK"; else echo "CANCELED"; return 0; fi


  if [[ $selection == *"1"* ]]; then
    echo -n "$(timestamp) [openHABian] Enabling serial port and disabling serial console... "
    if grep -qs "^[[:space:]]*enable_uart" /boot/config.txt; then
      if ! cond_redirect sed -i 's|^#*.*enable_uart=.*$|enable_uart=1|g' /boot/config.txt; then echo "FAILED (uart)"; return 1; fi
    else
      if ! echo "enable_uart=1" >> /boot/config.txt; then echo "FAILED (uart)"; return 1; fi
    fi
    if ! cond_redirect cp /boot/cmdline.txt /boot/cmdline.txt.bak; then echo "FAILED (backup cmdline.txt)"; return 1; fi
    if ! cond_redirect sed -i 's|console=tty.*console=tty1|console=tty1|g' /boot/cmdline.txt; then echo "FAILED (console)"; return 1; fi
    if ! cond_redirect sed -i 's|console=serial.*console=tty1|console=tty1|g' /boot/cmdline.txt; then echo "FAILED (serial)"; return 1; fi
    cond_echo "Disabling serial-getty service"
    if ! cond_redirect systemctl stop serial-getty@ttyAMA0.service; then echo "FAILED (stop serial-getty@ttyAMA0.service)"; return 1; fi
    if ! cond_redirect systemctl disable serial-getty@ttyAMA0.service; then echo "FAILED (disable serial-getty@ttyAMA0.service)"; return 1; fi
    if ! cond_redirect systemctl stop serial-getty@serial0.service; then echo "FAILED (stop serial-getty@serial0.service)"; return 1; fi
    if ! cond_redirect systemctl disable serial-getty@serial0.service; then echo "FAILED (disable serial-getty@serial0.service)"; return 1; fi
    if ! cond_redirect systemctl stop serial-getty@ttyS0.service; then echo "FAILED (stop serial-getty@ttyS0.service)"; return 1; fi
    if cond_redirect systemctl disable serial-getty@ttyS0.service; then echo "OK (reboot required)"; else echo "FAILED (disable serial-getty@ttyS0.service)"; return 1; fi
  else
    if [[ -f /boot/cmdline.txt.bak ]]; then
      echo -n "$(timestamp) [openHABian] Disabling serial port and enabling serial console... "
      if ! cond_redirect sed -i '/^#*.*enable_uart=.*$/d' /boot/config.txt; then echo "FAILED (uart)"; return 1; fi
      if ! cond_redirect cp /boot/cmdline.txt.bak /boot/cmdline.txt; then echo "FAILED (restore cmdline.txt)"; return 1; fi
      if ! cond_redirect rm -f /boot/cmdline.txt.bak; then echo "FAILED (remove backup)"; return 1; fi
      cond_echo "Enabling serial-getty service"
      if ! cond_redirect systemctl enable serial-getty@ttyAMA0.service; then echo "FAILED (enable serial-getty@ttyAMA0.service)"; return 1; fi
      if ! cond_redirect systemctl restart serial-getty@ttyAMA0.service; then echo "FAILED (restart serial-getty@ttyAMA0.service)"; return 1; fi
      if ! cond_redirect systemctl enable serial-getty@serial0.service; then echo "FAILED (enable serial-getty@serial0.service)"; return 1; fi
      if ! cond_redirect systemctl restart serial-getty@serial0.service; then echo "FAILED (restart serial-getty@serial0.service)"; return 1; fi
      if ! cond_redirect systemctl enable serial-getty@ttyS0.service; then echo "FAILED (enable serial-getty@ttyS0.service)"; return 1; fi
      if cond_redirect systemctl restart serial-getty@ttyS0.service; then echo "OK (reboot required)"; else echo "FAILED (restart serial-getty@ttyS0.service)"; return 1; fi
    fi
  fi

  if [[ $selection == *"2"* ]]; then
    if is_pithree || is_pithreeplus || is_pifour; then
      echo -n "$(timestamp) [openHABian] Making Bluetooth use mini-UART... "
      if ! grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt" /boot/config.txt; then
        if echo "dtoverlay=miniuart-bt" >> /boot/config.txt; then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi
      else
        echo "OK"
      fi
    else
      echo "$(timestamp) [openHABian] Making Bluetooth use mini-UART... SKIPPED"
      return 0
    fi
  else
    if is_pithree || is_pithreeplus || is_pifour && grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt" /boot/config.txt; then
      echo -n "$(timestamp) [openHABian] Making Bluetooth use UART... "
      if cond_redirect sed -i -E '/^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt/d' /boot/config.txt; then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi
    fi
  fi

  whiptail --title "Operation Successful!" --msgbox "$successText" 9 80
}
