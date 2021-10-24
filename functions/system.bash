#!/usr/bin/env bash

## Function for checking for and installing whiptail.
## This enables the display of the interactive menu used by openHABian.
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
  echo "$(timestamp) [openHABian] Updating repositories and upgrading installed packages..."
  export DEBIAN_FRONTEND=noninteractive
  # bad packages may require interactive input despite of this setting so do not mask output (no cond_redirect)
  if ! apt-get upgrade --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"; then echo "FAILED"; return 1; fi
  if java_install_or_update "${java_opt:-Zulu11-32}"; then echo "OK"; else echo "FAILED"; return 1; fi
  unset DEBIAN_FRONTEND
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

  if cond_redirect apt-get install --yes screen vim nano mc vfu bash-completion coreutils \
    htop curl wget multitail git util-linux bzip2 zip unzip xz-utils cpufrequtils lsb-release \
    software-properties-common man-db whiptail acl usbutils dirmngr arping; \
  then echo "OK"; else echo "FAILED"; exit 1; fi
}

## Function for installing additional needed Linux packages.
##
##    needed_packages()
##
needed_packages() {
  local bluetoothPackages="bluez python3-dev libbluetooth-dev raspberrypi-sys-mods pi-bluetooth"

  # Install apt-transport-https - update packages through https repository
  # Install bc/sysstat/jq/moreutils - needed for FireMotD
  # Install avahi-daemon - hostname based discovery on local networks
  # Install python3/python3-pip/python3-wheel/python3-setuptools - for python packages
  echo -n "$(timestamp) [openHABian] Installing additional needed packages... "
  if cond_redirect apt-get install --yes apt-transport-https bc sysstat jq \
    moreutils avahi-daemon python3 python3-pip python3-wheel python3-setuptools \
    avahi-autoipd fontconfig; \
  then echo "OK"; else echo "FAILED"; return 1; fi

  if is_pizerow || is_pithree || is_pithreeplus || is_pifour && [[ -z $PREOFFLINE ]]; then
    echo -n "$(timestamp) [openHABian] Installing python3 serial package... "
    if cond_redirect apt-get install --yes python3-smbus python3-serial; then echo "OK"; else echo "FAILED"; return 1; fi
    echo -n "$(timestamp) [openHABian] Installing pigpio package... "
    if cond_redirect apt-get install --yes pigpio; then echo "OK"; else echo "FAILED"; return 1; fi
    echo -n "$(timestamp) [openHABian] Installing additional bluetooth packages... "
    # phython3-bluez is not available in stretch so only add it if we are running on buster or later
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
    if ! running_in_docker && ! running_on_github; then
      if cond_redirect timedatectl set-timezone "$timezone"; then echo "OK ($(cat /etc/timezone))"; else echo "FAILED"; return 1; fi
    else
      echo "SKIPPED"
    fi
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
  if running_in_docker || (! is_raspios && ! is_raspbian); then
    echo "$(timestamp) [openHABian] Enabling time synchronization using NTP... SKIPPED"
    return 0
  fi

  if [[ $1 == "enable" ]]; then
    echo -n "$(timestamp) [openHABian] Enabling time synchronization using NTP... "
    if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/generic/50-timesyncd.conf /lib/dhcpcd/dhcpcd-hooks/; then echo "FAILED (copy)"; return 1; fi
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
  local syslocale

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

  if ! syslocale="$(grep "^[[:space:]]*LANG=" /etc/default/locale | sed 's|LANG=||g')"; then echo "FAILED"; return 1; fi
  if cond_redirect update-locale LANG="${system_default_locale:-${syslocale:-en_US.UTF-8}}" LC_ALL="${system_default_locale:-${syslocale:-en_US.UTF-8}}" LC_CTYPE="${system_default_locale:-${syslocale:-en_US.UTF-8}}" LANGUAGE="${system_default_locale:-${syslocale:-en_US.UTF-8}}"; then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Change locale" --msgbox "For the locale change to take effect, please reboot your system now." 7 80
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
    if ! newHostname="$(whiptail --title "Change hostname" --inputbox "\\nPlease enter the new system hostname (no special characters, no spaces):" 9 80 3>&1 1>&2 2>&3)"; then echo "FAILED"; return 1; fi
    if [[ -z $newHostname ]] || ( echo "$newHostname" | grep -q ' ' ); then
      whiptail --title "Change hostname" --msgbox "The hostname you have entered is not a valid hostname. Please try again." 7 80
      echo "FAILED"
      return 1
    fi
  else
    echo -n "$(timestamp) [openHABian] Setting hostname of the base system based on openhabian.conf... "
    newHostname="${hostname:-openhabian}"
  fi

  if ! cond_redirect hostnamectl set-hostname "$newHostname"; then echo "FAILED (hostnamectl)"; return 1; fi
  if sed -i 's|127.0.1.1.*$|127.0.1.1 '"${newHostname}"'|g' /etc/hosts; then echo "OK"; else echo "FAILED (edit hosts)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Change hostname" --msgbox "For the hostname change to take effect, please reboot your system now." 7 80
  fi
}

## Function for adding tuned bash configuration files to the current system.
##
##    bashrc_copy()
##
bashrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned bash configuration files to system... "
  if ! cp "${BASEDIR:-/opt/openhabian}"/includes/generic/bash.bashrc /etc/bash.bashrc; then echo "FAILED (user bashrc)"; return 1; fi
  if ! cp "${BASEDIR:-/opt/openhabian}"/includes/generic/bashrc-root /root/.bashrc; then echo "FAILED (root bashrc)"; return 1; fi
  if ! cp "${BASEDIR:-/opt/openhabian}"/includes/generic/bash_profile /home/"${username:-openhabian}"/.bash_profile; then echo "FAILED (user bash_profile)"; return 1; fi
  if ! cp "${BASEDIR:-/opt/openhabian}"/includes/generic/bash_aliases /home/"${username:-openhabian}"/.bash_aliases; then echo "FAILED (user bash_aliases)"; return 1; fi
  if chown "${username:-openhabian}:${username:-openhabian}" /home/"${username:-openhabian}"/.bash_*; then echo "OK"; else echo "FAILED (permissions)"; return 1; fi
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
    echo "$(timestamp) [openHABian] Creating mount $2 in '/srv/openhab-${1}'... SKIPPED"
    return 0
  fi

  local destination
  local mountPoint
  local source

  destination="$2"
  mountPoint="$(systemd-escape --path "/srv/openhab-${destination}" --suffix "mount")"
  source="$1"

  echo -n "$(timestamp) [openHABian] Creating mount $source in '/srv/openhab-${destination}'... "
  if ! sed -e 's|%SRC|'"${source}"'|g; s|%DEST|'"${destination}"'|g' "${BASEDIR:-/opt/openhabian}"/includes/srv_mount_template > /etc/systemd/system/"$mountPoint"; then echo "FAILED (sed)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload &> /dev/null; then echo "FAILED (daemon-reload)"; return 1; fi
  if cond_redirect systemctl enable --now "$mountPoint"; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi
}

## Function for adding openHAB folder mountpoints to the /srv/ folder.
##
##    srv_bind_mounts()
##
srv_bind_mounts() {
  if [[ -f /etc/ztab ]] && [[ $(systemctl is-active zram-config.service) == "active" ]]; then
    echo -n "$(timestamp) [openHABian] Stopping zram service... "
    if cond_redirect zram-config "stop"; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Preparing openHAB folder mounts under '/srv/openhab-*'... "
  cond_redirect umount -q /srv/openhab-{sys,conf,userdata,addons}
  if ! cond_redirect rm -f /etc/systemd/system/srv*.mount; then echo "FAILED (clean mounts)"; return 1; fi
  if ! cond_redirect mkdir -p /srv/openhab-{sys,conf,userdata,addons}; then echo "FAILED (prepare dirs)"; return 1; fi
  if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/srv_readme.txt /srv/README.txt; then echo "FAILED (copy readme)"; return 1; fi
  if ! cond_redirect chmod ugo+w /srv /srv/README.txt; then echo "FAILED (permissions for readme)"; return 1; fi

  if ! cond_redirect create_mount "/usr/share/openhab" "sys"; then echo "FAILED (sys)"; return 1; fi
  if ! cond_redirect create_mount "/etc/openhab" "conf"; then echo "FAILED (conf)"; return 1; fi
  if ! cond_redirect create_mount "/var/lib/openhab" "userdata"; then echo "FAILED (userdata)"; return 1; fi
  if cond_redirect create_mount "/usr/share/openhab/addons" "addons"; then echo "OK"; else echo "FAILED (addons)"; return 1; fi

  if [[ -f /etc/ztab ]]; then
    echo -n "$(timestamp) [openHABian] Restarting zram service... "
    if cond_redirect systemctl restart zram-config.service; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
}

## Function for applying common user account permission settings to system folders.
##
##    permissions_corrections()
##
permissions_corrections() {
  local gpioDir="/sys/devices/platform/soc"
  local groups=("audio" "bluetooth" "dialout" "gpio" "tty")
  local openhabFolders=("/etc/openhab" "/var/lib/openhab" "/var/log/openhab" "/usr/share/openhab")
  local openhabHome="/var/lib/openhab"
  local backupsFolder="${OPENHAB_BACKUPS:-/var/lib/openhab/backups}"
  local retval=0

  echo -n "$(timestamp) [openHABian] Applying file permissions recommendations... "
  if ! openhab_is_installed; then
    echo "FAILED (please execute after openHAB is installed)"
    return 1
  fi

  # Set Java and arping file capabilites
  cond_echo "Setting Java and arping file capabilites"
  if ! cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' "$(realpath "$(command -v java)")"; then echo "FAILED (setcap java)"; fi
  if ! cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' /usr/sbin/arping; then echo "FAILED (setcap arping)"; fi

  for pGroup in "${groups[@]}"; do
    if grep -qs "^[[:space:]]*${pGroup}:" /etc/group; then
      if ! cond_redirect usermod --append --groups "$pGroup" openhab ; then echo "FAILED (openhab ${pGroup})"; retval=1; fi
      if ! cond_redirect usermod --append --groups "$pGroup" "${username:-openhabian}"; then echo "FAILED (${username:-openhabian} ${pGroup})"; retval=1; fi
    fi
  done
  if ! cond_redirect usermod --append --groups openhab "${username:-openhabian}"; then echo "FAILED (${username:-openhabian} openhab)"; retval=1; fi

  cond_redirect chown --silent openhab:openhab /srv /opt
  cond_redirect chmod --silent ugo+w /srv
  if ! cond_redirect chown --recursive openhab:openhab "${openhabFolders[@]}"; then echo "FAILED (openhab folders)"; retval=1; fi
  if ! cond_redirect chmod --recursive u+wX,g+wX /opt "${openhabFolders[@]}"; then echo "FAILED (folders)"; retval=1; fi
  if [[ -d "$openhabHome"/.ssh ]]; then
    if ! cond_redirect chmod --recursive go-rwx "$openhabHome"/.ssh; then echo "FAILED (set .ssh access)"; retval=1; fi
  fi
  if ! [[ -d "$backupsFolder" ]]; then
    mkdir -p "$backupsFolder"
  fi
  if ! cond_redirect chown openhab:openhab "$backupsFolder"; then echo "FAILED (chown backups folder)"; retval=1; fi
  if ! cond_redirect chmod g+s "$backupsFolder ${openhabFolders[*]}"; then echo "FAILED (setgid backups folder)"; retval=1; fi

  if ! cond_redirect fix_permissions  "/home/${username:-openhabian}" "${username:-openhabian}:${username:-openhabian}"; then echo "FAILED (${username:-openhabian} chown $HOME)"; retval=1; fi
  if ! cond_redirect setfacl --recursive --remove-all "${openhabFolders[@]}"; then echo "FAILED (reset file access lists)"; retval=1; fi

  if ! cond_redirect fix_permissions /var/log/unattended-upgrades root:root 644 755; then echo "FAILED (unattended upgrades logdir)"; retval=1; fi
  if ! cond_redirect fix_permissions /var/log/samba root:root 640 750; then echo "FAILED (samba logdir)"; retval=1; fi
  if ! cond_redirect fix_permissions /var/log/openhab "openhab:${username:-openhabian}" 664 775; then echo "FAILED (openhab log)"; retval=1; fi

  if mosquitto_is_installed; then
    if ! cond_redirect fix_permissions /etc/mosquitto/passwd "mosquitto:${username:-openhabian}" 640 750; then echo "FAILED (mosquitto passwd permissions)"; retval=1; fi
    if ! cond_redirect fix_permissions /var/log/mosquitto "mosquitto:${username:-openhabian}" 644 755; then echo "FAILED (mosquitto log permissions)"; retval=1; fi
  fi
  if influxdb_is_installed; then
    chmod +x /usr/lib/influxdb/scripts/influxd-systemd-start.sh
  fi
  if zram_is_installed; then
    if influxdb_is_installed; then
       if ! cond_redirect fix_permissions /opt/zram/influxdb.bind root:root 664 775; then echo "FAILED (InfluxDB storage on zram)"; retval=1; fi
    fi
    if grafana_is_installed; then
      if ! cond_redirect fix_permissions /opt/zram/log.bind/grafana root:root 644 755; then echo "FAILED (grafana logdir on zram)"; retval=1; fi
    fi
    if mosquitto_is_installed; then
      if ! cond_redirect fix_permissions /opt/zram/log.bind/mosquitto "mosquitto:${username:-openhabian}" 644 755; then echo "FAILED (mosquitto log permissions on zram)"; retval=1; fi
    fi
    if ! cond_redirect fix_permissions /opt/zram/log.bind/samba root:root 640 750; then echo "FAILED (samba logdir on zram)"; retval=1; fi
    if ! cond_redirect fix_permissions /opt/zram/log.bind/openhab "openhab:${username:-openhabian}" 664 775; then echo "FAILED (openhab log on zram)"; retval=1; fi
    if ! cond_redirect fix_permissions /opt/zram/persistence.bind "openhab:${username:-openhabian}" 664 775; then echo "FAILED (persistence on zram)"; retval=1; fi
  fi
  echo "OK"

  if homegear_is_installed; then
    echo -n "$(timestamp) [openHABian] Applying additional file permissions recommendations for Homegear... "
    if ! cond_redirect chown --recursive root:root /etc/homegear; then echo "FAILED (chown)"; retval=1; fi
    if ! (find /etc/homegear -type d -print0 | xargs -0 chmod 755); then echo "FAILED (chmod directories)"; retval=1; fi
    if ! (find /etc/homegear -type f -print0 | xargs -0 chmod 644); then echo "FAILED (chmod files)"; retval=1; fi
    if ! (find /etc/homegear -name "*.key" -print0 | xargs -0 chmod 644); then echo "FAILED (chmod *.key)"; retval=1; fi
    if ! (find /etc/homegear -name "*.key" -print0 | xargs -0 chown homegear:homegear); then echo "FAILED (chown *.key)"; retval=1; fi
    if ! cond_redirect chown homegear:homegear /etc/homegear/rpcclients.conf; then echo "FAILED (chown rpcclients)"; retval=1; fi
    if ! cond_redirect chmod 400 /etc/homegear/rpcclients.conf; then echo "FAILED (chmod rpcclients)"; retval=1; fi
    if ! cond_redirect chown --recursive homegear:homegear /var/log/homegear; then echo "FAILED (chown logs)"; retval=1; fi

    # homeMatic/homegear controller HM-MOD-RPI-PCB uses GPIO 18 to reset HW
    if ! [[ -d ${gpioDir}/gpio18 ]]; then
      echo "18" > /sys/class/gpio/export
      echo "out" > /sys/class/gpio/gpio18/direction
      echo "0" > /sys/class/gpio/gpio18/value
    else
      if ! cond_redirect chgrp --silent --recursive gpio "${gpioDir}/gpio18"; then echo "FAILED (set GPIO 18 group)"; retval=1; fi
      if cond_redirect chmod g+rw --silent --recursive "${gpioDir}/gpio18"; then echo "OK"; else echo "FAILED (set GPIO 18 access)"; retval=1; fi
    fi
  fi

  if [[ -d /opt/habapp ]]; then
    echo -n "$(timestamp) [openHABian] Applying additional file permissions recommendations for HABApp... "
    if cond_redirect fix_permissions "/opt/habapp" 775 775; then echo "OK"; else echo "FAILED (HABApp venv permissions)"; retval=1; fi
  fi

  return $retval
}

## Function for applying miscellaneous system settings.
##
##    misc_system_settings()
##
misc_system_settings() {
  echo -n "$(timestamp) [openHABian] Applying miscellaneous system settings... "

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

    # run at full CPU when needed
    echo 'GOVERNOR="ondemand"'> /etc/default/cpufrequtils

    # enable I2C port
    if ! grep -qs "^[[:space:]]*dtparam=i2c_arm=on" /boot/config.txt; then echo "dtparam=i2c_arm=on" >> /boot/config; fi
    cond_redirect install -m 755 "${BASEDIR:-/opt/openhabian}"/includes/INA219.py /usr/local/bin/waveshare_ups
  fi
  # A distinguishable apt User-Agent
  cond_echo "Setting a distinguishable apt User-Agent"
  if echo "Acquire { http::User-Agent \"Debian APT-HTTP/1.3 openHABian\"; };" > /etc/apt/apt.conf.d/02useragent; then echo "OK"; else echo "FAILED (apt User-Agent)"; return 1; fi
}

## Change system swap size dependent on free space on '/swap' on SD
## ('/var/swap' per default) only used after zram swap is full if zram is enabled.
##
##    change_swapsize()
##
change_swapsize() {
  if ! is_pi; then return 0; fi

  local free
  local minFree
  local swap
  local totalMemory

  totalMemory="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  if [[ -z $totalMemory ]]; then return 1; fi
  swap="$((2*totalMemory))"
  minFree="$((2*swap))"
  free="$(df -hk / | awk '/dev/ { print $4 }')"
  if [[ $free -ge "$minFree" ]]; then
    size="$swap"
  elif [[ $free -ge "$swap" ]]; then
    size="$totalMemory"
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

  sed -i '/^dtoverlay=vc4-fkms-v3d/d' /boot/config.txt
}

## disable or enable framebuffer to provide the maximum amount of memory for Linux operations.
##
##    use_framebuffer()
##
use_framebuffer() {
  if ! is_pi; then 
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "Change framebuffer" --msgbox "Frame buffer parameters can only be changed on Raspberry Pi systems." 7 80
    fi
    return 0;
  fi

  sed -i '/^[[:space:]]*max_framebuffers/d' /boot/config.txt
  if [[ ${1:-${framebuffer:-enable}} == "enable" ]]; then
    /usr/bin/tvservice -p   # switches HDMI back on
    echo "max_framebuffers=1" >> /boot/config.txt
  elif [[ ${1:-${framebuffer:-enable}} == "disable" ]]; then
    /usr/bin/tvservice -o   # switches HDMI off
    echo "max_framebuffers=0" >> /boot/config.txt
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

  introText="\\nProceeding with this routine, the serial console normally provided by a Raspberry Pi must be disabled to make serial port become useable by devices like RaZberry, UZB or Busware adapters.\\n\\nOn a Raspberry Pi 3 or 4 the Bluetooth module can be relocated to the mini UART port to allow for proper operation of a RaZberry or other HAT.\\n\\nPlease make your choice:"
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

  echo -n "$(timestamp) [openHABian] Configuring serial port for peripherals... "
  if selection=$(whiptail --title "Prepare serial port" --checklist --separate-output "$introText" 19 75 2 \
  "1"  "(all RPi) Disable serial console to give room for HATs"      $optionOne \
  "2"  "(RPi3/4)  move Bluetooth to mini UART" $optionTwo \
  3>&1 1>&2 2>&3); then echo "OK"; else echo "CANCELED"; return 0; fi


  if [[ $selection == *"1"* ]]; then
    echo -n "$(timestamp) [openHABian] Enabling serial port and disabling serial console... "
    if grep -qs "^[[:space:]]*enable_uart" /boot/config.txt; then
      if ! cond_redirect sed -i -e 's|^#*.*enable_uart=.*$|enable_uart=1|g' /boot/config.txt; then echo "FAILED (uart)"; return 1; fi
    else
      if ! (echo "enable_uart=1" >> /boot/config.txt); then echo "FAILED (uart)"; return 1; fi
    fi
    if ! cond_redirect cp /boot/cmdline.txt /boot/cmdline.txt.bak; then echo "FAILED (backup cmdline.txt)"; return 1; fi
    if ! cond_redirect sed -i -e 's|console=tty.*console=tty1|console=tty1|g' /boot/cmdline.txt; then echo "FAILED (console)"; return 1; fi
    if ! cond_redirect sed -i -e 's|console=serial.*console=tty1|console=tty1|g' /boot/cmdline.txt; then echo "FAILED (serial)"; return 1; fi
    cond_echo "Disabling serial-getty service"
    if ! cond_redirect systemctl disable --now serial-getty@ttyAMA0.service; then echo "FAILED (disable serial-getty@ttyAMA0.service)"; return 1; fi
    if ! cond_redirect systemctl disable --now serial-getty@serial0.service; then echo "FAILED (disable serial-getty@serial0.service)"; return 1; fi
    if cond_redirect systemctl disable --now serial-getty@ttyS0.service; then echo "OK (reboot required)"; else echo "FAILED (disable serial-getty@ttyS0.service)"; return 1; fi
  else
    if [[ -f /boot/cmdline.txt.bak ]]; then
      echo -n "$(timestamp) [openHABian] Disabling serial port and enabling serial console... "
      if ! cond_redirect sed -i -e '/^#*.*enable_uart=.*$/d' /boot/config.txt; then echo "FAILED (uart)"; return 1; fi
      if ! cond_redirect cp /boot/cmdline.txt.bak /boot/cmdline.txt; then echo "FAILED (restore cmdline.txt)"; return 1; fi
      if ! cond_redirect rm -f /boot/cmdline.txt.bak; then echo "FAILED (remove backup)"; return 1; fi
      cond_echo "Enabling serial-getty service"
      if ! cond_redirect systemctl enable --now serial-getty@ttyAMA0.service; then echo "FAILED (enable serial-getty@ttyAMA0.service)"; return 1; fi
      if ! cond_redirect systemctl enable --now serial-getty@serial0.service; then echo "FAILED (enable serial-getty@serial0.service)"; return 1; fi
      if ! cond_redirect systemctl enable --now serial-getty@ttyS0.service; then echo "OK (reboot required)"; else echo "FAILED (enable serial-getty@ttyS0.service)"; return 1; fi
    fi
  fi

  if [[ $selection == *"2"* ]]; then
    if is_pithree || is_pithreeplus || is_pifour; then
      echo -n "$(timestamp) [openHABian] Making Bluetooth use mini-UART... "
      if ! grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt" /boot/config.txt; then
        if (echo "dtoverlay=miniuart-bt" >> /boot/config.txt); then echo "OK (reboot required)"; else echo "FAILED"; return 1; fi
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

  whiptail --title "Operation successful" --msgbox "$successText" 9 80
}


## Function for installing the ELElabs EZSP firmware update utility
## Useful to flash various ZigBee controllers that have an Ember chipset.
##
##    ezspUtility_setup
##
##
ezspUtility_setup() {
  local repo="https://github.com/Elelabs/elelabs-zigbee-ezsp-utility"
  # local emberfwrepo="https://github.com/xsp1989/zigbeeFirmware.git"     # for iTead (Sonoff) sticks
  local destdir="/usr/share/openhab"
  local target="Elelabs_EzspFwUtility.py"
  local successText="The ELElabs python tool to flash Ember chipset ZigBee controllers has been successfully installed as ${destdir}/${target}.\\n\\nSee https://github.com/Elelabs/elelabs-zigbee-ezsp-utility#how-to how to use it."
  local temp


  temp="$(mktemp -d "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo -n "$(timestamp) [openHABian] Installing ELElabs firmware flash tool ... "
  cond_redirect git clone "$repo" "$temp"
  if ! cond_redirect pip3 install -r "${temp}"/requirements.txt; then echo "FAILED (install python requirements)"; return 1; fi
  if cond_redirect install -o openhabian -g openhabian -m 755 "$target" "$destdir"; then echo "OK" else echo "FAILED (install .py)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$successText" 9 80
  fi
}
