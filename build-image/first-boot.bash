#!/usr/bin/env bash
# shellcheck source=/etc/openhabian.conf disable=SC1091

CONFIGFILE="/etc/openhabian.conf"

# apt/dpkg commands will not try interactive dialogs
export DEBIAN_FRONTEND="noninteractive"
export SILENT="1"

# Log everything to file
exec &> >(tee -a "/boot/first-boot.log")

# Log with timestamp
timestamp() { date +"%F_%T_%Z"; }

fail_inprogress() {
  rm -f /opt/openHABian-install-inprogress
  touch /opt/openHABian-install-failed
  echo -e "$(timestamp) [openHABian] Initial setup exiting with an error!\\n\\n"
  exit 1
}

###### start ######
sleep 5
echo -e "\\n\\n$(timestamp) [openHABian] Starting the openHABian initial setup."
rm -f /opt/openHABian-install-failed
touch /opt/openHABian-install-inprogress

echo -n "$(timestamp) [openHABian] Storing configuration... "
if ! cp /boot/openhabian.conf "$CONFIGFILE"; then echo "FAILED (copy)"; fail_inprogress; fi
if ! sed -i 's|\r$||' "$CONFIGFILE"; then echo "FAILED (Unix line endings)"; fail_inprogress; fi
if ! source "$CONFIGFILE"; then echo "FAILED (source config)"; fail_inprogress; fi
if ! source "/opt/openhabian/functions/helpers.bash"; then echo "FAILED (source helpers)"; fail_inprogress; fi
if ! source "/opt/openhabian/functions/wifi.bash"; then echo "FAILED (source wifi)"; fail_inprogress; fi
if source "/opt/openhabian/functions/openhabian.bash"; then echo "OK"; else echo "FAILED (source openhabian)"; fail_inprogress; fi

if [[ "${debugmode:-on}" == "on" ]]; then
  unset SILENT
  unset DEBUGMAX
elif [[ "${debugmode:-on}" == "maximum" ]]; then
  echo "$(timestamp) [openHABian] Enable maximum debugging output"
  export DEBUGMAX=1
  set -x
fi

echo -n "$(timestamp) [openHABian] Starting webserver with installation log... "
if [[ -x $(command -v python3) ]]; then
  bash /boot/webserver.bash "start"
  sleep 5
  isWebRunning="$(ps -ef | pgrep python3)"
  if [[ -n $isWebRunning ]]; then echo "OK"; else echo "FAILED"; fi
else
  echo "SKIPPED (Python not found)"
fi

defaultUserAndGroup="openhabian"
userName="${username:-openhabian}"
groupName="${userName}"
if is_raspbian || is_raspios; then
  defaultUserAndGroup="pi"
  rm -f "/etc/sudoers.d/010_pi-nopasswd"
fi

echo -n "$(timestamp) [openHABian] Changing default username and password... "
# shellcheck disable=SC2154
if [[ -v ${userName} ]] || ! id "$defaultUserAndGroup" &> /dev/null || id "$userName" &> /dev/null; then
  echo "SKIPPED"
else
  usermod -l "$userName" "$defaultUserAndGroup"
  usermod -m -d "/home/$userName" "$userName"
  groupmod -n "$groupName" "$defaultUserAndGroup"
  echo "${userName}:${userpw:-$userName}" | chpasswd
  echo "OK"
fi

# While setup: show log to logged in user, will be overwritten by openhabian-setup.sh
echo "watch cat /boot/first-boot.log" > "$HOME/.bash_profile"

# shellcheck source=/etc/openhabian.conf disable=SC2154
if [[ -z $wifi_ssid ]]; then
  # Actually check if ethernet is working
  echo -n "$(timestamp) [openHABian] Setting up Ethernet connection... "
  if grep -qs "up" /sys/class/net/eth0/operstate; then echo "OK"; else echo "FAILED"; fi

  if ! running_in_docker && tryUntil "ping -c1 8.8.8.8 &> /dev/null || curl --silent --head http://www.openhab.org/docs |& grep -qs 'HTTP/1.1 200 OK'" 5 1; then
    if [[ "$hotspot" == "enable" ]] && ! [[ -x $(command -v comitup) ]]; then
      echo -n "$(timestamp) [openHABian] Installing comitup hotspot (will reboot after)... "
      setup_hotspot "install"
      cp "${BASEDIR:-/opt/openhabian}"/includes/interfaces /etc/network/
      echo "$(timestamp) [openHABian] hotspot software installed. Rebooting your system to make it take effect!"
      reboot
    fi
  fi
elif grep -qs "openHABian" /etc/wpa_supplicant/wpa_supplicant.conf && ! grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?disable-wifi" /boot/config.txt; then
  echo -n "$(timestamp) [openHABian] Checking if WiFi is working... "
  if iwlist wlan0 scan |& grep -qs "Interface doesn't support scanning"; then
    # WiFi might be blocked
    rfkill unblock wifi
    ip link set wlan0 up
    if iwlist wlan0 scan |& grep -qs "Interface doesn't support scanning"; then
      echo "FAILED"
      echo -e "\\nI was not able to turn on the WiFi\\nHere is some more information:\\n"
      rfkill list all
      ip a
      echo -e "FAILED.\\n$(timestamp) [openHABian] Starting hotspot as a desperate last attempt; see if you can connect there...\\n"
    else
      echo "OK"
    fi
  else
    echo "OK"
  fi
  if tryUntil "ping -c1 8.8.8.8 &> /dev/null || curl --silent --head http://www.openhab.org/docs |& grep -qs 'HTTP/1.1 200 OK'" 5 1; then
    if [[ "$hotspot" == "enable" ]] && ! [[ -x $(command -v comitup) ]]; then
      echo -n "$(timestamp) [openHABian] Installing comitup hotspot (will reboot after)... "
      setup_hotspot "install"
      cp "${BASEDIR:-/opt/openhabian}"/includes/interfaces /etc/network/
      echo "$(timestamp) [openHABian] hotspot software installed. Rebooting your system to make it take effect!"
      reboot
    fi
  fi
else
  echo -n "$(timestamp) [openHABian] Setting up Wi-Fi connection... "

  wifiCountry="$wifi_country"
  wifiSSID="$wifi_ssid"
  wifiPassword="$wifi_psk"

  # Check if the country code is valid, valid country codes are followed by spaces in /usr/share/zoneinfo/zone.tab
  if grep -qs "^${wifiCountry^^}[[:space:]]" /usr/share/zoneinfo/zone.tab; then
    wifiCountry="${wifiCountry^^}"
  else
    echo "ERROR (${wifiCountry} is not a valid country code found in '/usr/share/zoneinfo/zone.tab' defaulting to US)"
    wifiCountry="US"
  fi
  if ! wifiConfig="$(wpa_passphrase "${wifiSSID}" "${wifiPassword}")"; then echo "FAILED (wpa_passphrase)"; fail_inprogress; fi

  echo -e "# WiFi configuration generated by openHABian\\ncountry=$wifiCountry\\nctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\\nupdate_config=1\\n# Network configuration was created by wpa_passphrase to ensure correct handling of special characters\\n${wifiConfig//\}/\\tkey_mgmt=WPA-PSK\\n\}}" > /etc/wpa_supplicant/wpa_supplicant.conf

  sed -i 's|REGDOMAIN=.*$|REGDOMAIN='"${wifiCountry}"'|g' /etc/default/crda

  echo -n "$(timestamp) [openHABian] Configuring network... "
  if grep -qs "wlan0" /etc/network/interfaces; then
    cond_echo "\\nNot writing to '/etc/network/interfaces', wlan0 entry already available. You might need to check, adopt or remove these lines."
  else
    echo -e "\\nallow-hotplug wlan0\\niface wlan0 inet manual\\nwpa-roam /etc/wpa_supplicant/wpa_supplicant.conf\\niface default inet dhcp" >> /etc/network/interfaces
  fi

  if is_pi; then
    echo "OK (rebooting)"
    reboot
  else
    wpa_cli reconfigure &> /dev/null
    echo "OK"
  fi
fi

echo -n "$(timestamp) [openHABian] Ensuring network connectivity... "
if ! running_in_docker && tryUntil "ping -c1 8.8.8.8 &> /dev/null || curl --silent --head http://www.openhab.org/docs |& grep -qs 'HTTP/1.1 200 OK'" 5 1; then
  echo "FAILED"
  if grep -qs "openHABian" /etc/wpa_supplicant/wpa_supplicant.conf && iwconfig |& grep -qs "ESSID:off"; then
    echo "$(timestamp) [openHABian] I was not able to connect to the configured Wi-Fi. Please check your signal quality. Reachable Wi-Fi networks are:"
    iwlist wlan0 scanning | grep "ESSID" | sed 's/^\s*ESSID:/\t- /g'
    echo "$(timestamp) [openHABian] Please try again with your correct SSID and password. The following Wi-Fi configuration was used:"
    cat /etc/wpa_supplicant/wpa_supplicant.conf
    rm -f /etc/wpa_supplicant/wpa_supplicant.conf
  fi
  echo "$(timestamp) [openHABian] The public internet is not reachable. Please check your local network environment."
  echo "                          We have launched a publicly accessible hotspot named openHABian-<n>."
  echo "                          Use your mobile to connect and go to http://raspberrypi.local or http://10.42.0.1/"
  echo "                          and select the WiFi network you want to connect your openHABian system to."
  echo "                          After about an hour, we will continue trying to get your system installed,"
  echo "                          but without proper Internet connectivity this is not guaranteed to work."
else
  echo "OK"
fi

echo -n "$(timestamp) [openHABian] Waiting for dpkg/apt to get ready... "
if wait_for_apt_to_be_ready; then echo "OK"; else echo "FAILED"; fi

firmwareBefore="$(dpkg -s raspberrypi-kernel |& grep "Version:[[:space:]]")"
echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
apt-get install --fix-broken --yes &> /dev/null
if [[ $(eval "$(apt-get --yes upgrade &> /dev/null)") -eq 100 ]]; then
  echo -n "CONTINUING... "
  dpkg --configure --pending &> /dev/null
  apt-get install --fix-broken --yes &> /dev/null
  if apt-get upgrade --yes &> /dev/null; then
    if [[ $firmwareBefore != "$(dpkg -s raspberrypi-kernel |& grep "Version:[[:space:]]")" ]]; then
      # Fix for issues with updating kernel during install
      echo "OK (rebooting)"
      reboot
    else
      echo "OK"
    fi
  else
    echo "FAILED"
  fi
else
  if [[ $firmwareBefore != "$(dpkg -s raspberrypi-kernel |& grep "Version:[[:space:]]")" ]]; then
    # Fix for issues with updating kernel during install
    echo "OK (rebooting)"
    reboot
  else
    echo "OK"
  fi
fi

if [[ -x $(command -v python3) ]]; then bash /boot/webserver.bash "reinsure_running"; fi

if ! [[ -x $(command -v git) ]]; then
  echo -n "$(timestamp) [openHABian] Installing git package... "
  if apt-get install --yes git &> /dev/null; then echo "OK"; else echo "FAILED"; fi
fi

# shellcheck disable=SC2154
echo -n "$(timestamp) [openHABian] Updating myself from ${repositoryurl:-https://github.com/openhab/openhabian.git}, ${clonebranch:-stable} branch... "
if [[ $(eval "$(openhabian_update &> /dev/null)") -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED"
  echo "$(timestamp) [openHABian] The git repository on the public internet is not reachable."
  echo "$(timestamp) [openHABian] We will continue trying to get your system installed, but this is not guaranteed to work."
  export OFFLINE="1"
fi
ln -sfn /opt/openhabian/openhabian-setup.sh /usr/local/bin/openhabian-config

# shellcheck disable=SC2154
echo "$(timestamp) [openHABian] Starting execution of 'openhabian-config unattended'... OK"
if (openhabian-config unattended); then
  rm -f /opt/openHABian-install-inprogress
  touch /opt/openHABian-install-successful
else
  echo "$(timestamp) [openHABian] We tried to get your system installed, but without proper internet connectivity this may not have worked properly."
fi
echo "$(timestamp) [openHABian] Execution of 'openhabian-config unattended' completed."
echo "$(timestamp) [openHABian] First time setup successfully finished. Rebooting your system!"
echo "$(timestamp) [openHABian] After rebooting the openHAB dashboard will be available at: http://${HOSTNAME:-openhab}:8080"
echo "$(timestamp) [openHABian] After rebooting to gain access to a console, simply reconnect using ssh."
sleep 12
if [[ -x $(command -v python3) ]]; then bash /boot/webserver.bash "inst_done"; fi
sleep 12
if [[ -x $(command -v python3) ]]; then bash /boot/webserver.bash "cleanup"; fi

if running_in_docker; then
  PID="/var/lib/openhab/tmp/karaf.pid"
  echo -e "\\n${COL_CYAN}Memory usage:" && free -m
  if [[ -f "$PID" ]]; then
    ps -auxq "$(cat "$PID")" | awk '/openhab/ {print "size/res="$5"/"$6" KB"}'
  else
    echo -e "\\n${COL_RED}Karaf PID missing, openHAB process not running (yet?)."
  fi
  echo -e "$COL_DEF"
fi

reboot

# vim: filetype=sh
