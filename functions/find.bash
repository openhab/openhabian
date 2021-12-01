#!/usr/bin/env bash

# shellcheck disable=SC2154

## Function for installing FIND to allow for indoor localization of WiFi devices.
## This function can only be invoked in INTERACTIVE with userinterface.
##
##    find3_setup()
##
find3_setup() {
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] FIND3 setup must be run in interactive mode! Canceling FIND3 setup!"
    return 0
  fi
  if [[ -f /etc/systemd/system/findserver.service ]]; then
    echo "$(timestamp) [openHABian] FIND3 cannot be used with FIND! Canceling FIND3 setup!"
    return 0
  fi

  local brokerText="You've chosen to work with an external MQTT broker.\\n\\nPlease be aware that you might need to add authentication credentials. You can do so after the installation.\\n\\nConsult with the FIND3 documentation or the openHAB community for details."
  local disklistFileAWS="/etc/amanda/openhab-aws/disklist"
  local disklistFileDir="/etc/amanda/openhab-dir/disklist"
  local find3Dir="/opt/find3"
  local find3IncludesDir="${BASEDIR:-/opt/openhabian}/includes/find3"
  local findPass1
  local findPass2
  local introText="Framework for Internal Navigation and Discovery (FIND) version 3 will be installed to allow for the indoor localization of Bluetooth and WiFi devices.\\n\\nThis will install the FIND3 server and 'find3-cli-scanner' which allows for fingerprint collection.\\n\\nYou must manually activate 'find3-cli-scanner', for more information see:\\nhttps://www.internalpositioning.com/doc/cli-scanner.md\\n\\nThere is also an Android app for collecting fingerprints. There is no iOS app for fingerprint collection, for details on why see:\\nhttps://www.internalpositioning.com/doc/faq.md#iphone\\n\\nFor more information see:\\nhttps://www.internalpositioning.com/doc/"
  local MQTT_ADMIN
  local MQTT_PASS
  local MQTT_SERVER
  local mqttMissingText="FIND3 requires an MQTT broker to run, but Mosquitto could not be found on this system.\\n\\nYou can configure FIND to use any existing MQTT broker (in the next step) or you can go back and install Mosquitto from the openHABian menu.\\n\\nDo you want to continue with the FIND3 installation?"
  local mqttPass="/etc/mosquitto/passwd"
  local successText="FIND3 setup was successful.\\n\\nSettings can be configured in '/etc/default/find3server'. Be sure to restart the service after.\\n\\nYou must manually activate 'find3-cli-scanner', for more information see:\\nhttps://www.internalpositioning.com/doc/cli-scanner.md\\n\\nThere is also an Android app for collecting fingerprints. There is no iOS app for fingerprint collection, for details on why see:\\nhttps://www.internalpositioning.com/doc/faq.md#iphone\\n\\nCheck out your FIND3 server's dashboard at: http://${hostname}:8003\\n\\nFor more information see:\\nhttps://www.internalpositioning.com/doc/"

  echo -n "$(timestamp) [openHABian] Beginning setup of FIND3, the Framework for Internal Navigation and Discovery... "

  if ! [[ -f "/etc/mosquitto/mosquitto.conf" ]]; then
    if ! (whiptail --title "Mosquitto not installed" --defaultno --yes-button "Continue" --no-button "Cancel" --yesno "$mqttMissingText" 13 80); then echo "CANCELED"; return 0; fi
  fi

  if (whiptail --title "FIND3 installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 22 80); then echo "OK"; else echo "CANCELED"; return 0; fi

  echo -n "$(timestamp) [openHABian] Configuring FIND3... "
  if ! MQTT_SERVER="$(whiptail --title "FIND3 Setup" --inputbox "\\nPlease enter the hostname and port of the device your MQTT broker is running on:" 10 80 localhost:1883 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
  if [[ $MQTT_SERVER != "localhost:1883" ]]; then
    if ! (whiptail --title "MQTT Broker Notice" --yes-button "Continue" --no-button "Cancel" --yesno "$brokerText" 12 80); then echo "CANCELED"; return 0; fi
  elif [[ -f $mqttPass ]]; then
    if ! MQTT_ADMIN=$(whiptail --title "FIND3 MQTT Setup" --inputbox "\\nEnter a username for FIND3 to connect to your MQTT broker with:" 9 80 find 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
    while [[ -z $MQTT_PASS ]]; do
      if ! findPass1=$(whiptail --title "FIND3 MQTT Setup" --passwordbox "\\nEnter a password for the FIND3 user on your MQTT broker:" 9 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
      if ! findPass2=$(whiptail --title "FIND3 MQTT Setup" --passwordbox "\\nPlease confirm the password for the FIND3 user on your MQTT broker:" 9 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
      if [[ $findPass1 == "$findPass2" ]] && [[ ${#findPass1} -ge 8 ]] && [[ ${#findPass2} -ge 8 ]]; then
        MQTT_PASS="$findPass1"
      else
        whiptail --title "FIND3 MQTT Setup" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
      fi
    done
    if ! cond_redirect systemctl stop mosquitto.service; then echo "FAILED (stop service)"; return 1; fi
    if ! cond_redirect mosquitto_passwd -b "$mqttPass" "$MQTT_ADMIN" "$MQTT_PASS"; then echo "FAILED (mosquitto password)"; return 1; fi
    if ! cond_redirect systemctl restart mosquitto.service; then echo "FAILED (restart service)"; return 1; fi
  fi
  echo "OK"

  echo -n "$(timestamp) [openHABian] Installing required packages for FIND3... "
  if ! cond_redirect apt-get install --yes libc6-dev make pkg-config g++ gcc python3-dev python3-numpy python3-scipy python3-matplotlib libatlas-base-dev gfortran wireless-tools net-tools libpcap-dev bluetooth; then echo "FAILED (apt)"; return 1; fi
  if cond_redirect python3 -m pip install cython --install-option="--no-cython-compile"; then echo "OK"; else echo "FAILED (cython)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Downloading FIND3 source... "
  if ! [[ -d $find3Dir ]]; then
    cond_echo "\\nFresh Installation... "
    if cond_redirect git clone https://github.com/schollz/find3.git $find3Dir; then echo "OK"; else echo "FAILED (git clone)"; return 1; fi
  else
    cond_echo "\\nUpdate... "
    if cond_redirect update_git_repo "$find3Dir" "master"; then echo "OK"; else echo "FAILED (update git repo)"; return 1; fi
  fi

  if ! [[ -x $(command -v go) ]]; then
    echo -n "$(timestamp) [openHABian] Installing Go... "
    if cond_redirect go_setup; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Building FIND3 server... "
  if ! cond_redirect cd $find3Dir/server/main; then echo "FAILED (cd)"; return 1; fi
  if cond_redirect go build -o find3server -v; then echo "OK"; else echo "FAILED (build)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Installing FIND3 server... "
  if cond_redirect ln -sf $find3Dir/server/main/find3server /usr/sbin/find3server; then echo "OK"; else echo "FAILED (link)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Installing FIND3 AI... "
  if ! cond_redirect cd $find3Dir/server/ai; then echo "FAILED (cd)"; return 1; fi
  if cond_redirect python3 -m pip install -r requirements.txt; then echo "OK"; else echo "FAILED (pip)"; return 1; fi

  if ! cond_redirect zram_dependency install find3server find3ai; then return 1; fi
  if [[ -f /etc/ztab ]] && ! grep -qs "/find3.bind" /etc/ztab; then
    echo -n "$(timestamp) [openHABian] Adding FIND3 to zram... "
    if ! cond_redirect sed -i '/^.*persistence.bind$/a dir	zstd		150M		350M		/opt/find3/server/main		/find3.bind' /etc/ztab; then echo "FAILED (sed)"; return 1; fi
    if ! cond_redirect zram-config "start"; then echo "FAILED (start temporary configuration)"; return 1; fi
  fi

  if [[ -f $disklistFileDir ]]; then
    echo -n "$(timestamp) [openHABian] Adding FIND3 to Amanda local backup... "
    if ! cond_redirect sed -i -e '/find3/d' "$disklistFileDir"; then echo "FAILED (old config)"; return 1; fi
    if (echo "${hostname}  /opt/find3/server/main        comp-user-tar" >> "$disklistFileDir"); then echo "OK"; else echo "FAILED (new config)"; return 1; fi
  fi
  if [[ -f $disklistFileAWS ]]; then
    echo -n "$(timestamp) [openHABian] Adding FIND3 to Amanda AWS backup... "
    if ! cond_redirect sed -i -e '/find3/d' "$disklistFileAWS"; then echo "FAILED (old config)"; return 1; fi
    if (echo "${hostname}  /opt/find3/server/main        comp-user-tar" >> "$disklistFileAWS"); then echo "OK"; else echo "FAILED (new config)"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up FIND3 service... "
  if ! (id -u find3 &> /dev/null || cond_redirect useradd --groups openhabian find3); then echo "FAILED (adduser)"; return 1; fi
  if ! cond_redirect chown -R "find3:${username:-openhabian}" /opt/find3; then echo "FAILED (permissions)"; return 1; fi
  if ! cond_redirect install -m 644 "${find3IncludesDir}/find3ai.service" /etc/systemd/system/find3ai.service; then echo "FAILED (copy service)"; return 1; fi
  if ! (sed -e 's|%FIND3_PORT|8003|g' "${find3IncludesDir}/find3server.service" > /etc/systemd/system/find3server.service); then echo "FAILED (service file creation)"; return 1; fi
  if ! cond_redirect chmod 644 /etc/systemd/system/find3server.service; then echo "FAILED (permissions)"; return 1; fi
  if ! (sed -e 's|%MQTT_SERVER|'"${MQTT_SERVER}"'|g; s|%MQTT_ADMIN|'"${MQTT_ADMIN}"'|g; s|%MQTT_PASS|'"${MQTT_PASS}"'|g' "${find3IncludesDir}/find3server" > /etc/default/find3server); then echo "FAILED (service configuration creation)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect systemctl enable --now find3ai.service; then echo "FAILED (enable find3ai)"; return 1; fi
  if cond_redirect systemctl enable --now find3server.service; then echo "OK"; else echo "FAILED (enable find3server)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Installing FIND3 fingerprinting client... "
  GO111MODULE="on"
  GOPATH="$(go env | grep "GOPATH" | sed 's|GOPATH=||g; s|"||g')"
  export GO111MODULE GOPATH
  if ! cond_redirect go get -v github.com/schollz/find3-cli-scanner/v3; then echo "FAILED (get)"; return 1; fi
  if cond_redirect install -m 755 "$GOPATH"/bin/find3-cli-scanner /usr/local/bin/find3-cli-scanner; then echo "OK"; else echo "FAILED"; return 1; fi

  if openhab_is_installed; then
    dashboard_add_tile "find3"
  fi

  whiptail --title "Operation successful" --msgbox "$successText" 22 80
}

## Function to install Go on the current system
##
##    go_setup()
##
go_setup() {
  if [[ -x $(command -v go) ]]; then return 0; fi

  echo -n "$(timestamp) [openHABian] Installing the Go programming language... "

  if is_ubuntu; then
    if is_bionic; then
      if ! cond_redirect add-apt-repository ppa:longsleep/golang-backports; then echo "FAILED (add apt repository)"; return 1; fi
      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
    fi
    if cond_redirect apt-get install --yes golang-go; then echo "OK"; else echo "FAILED"; return 1; fi
  else
    if is_buster; then
      echo "deb http://deb.debian.org/debian buster-backports main" > /etc/apt/sources.list.d/golang.list
      if ! cond_redirect wget -nv -O debian-keyring.deb http://ftp.us.debian.org/debian/pool/main/d/debian-keyring/debian-keyring_2019.02.25_all.deb; then echo "FAILED (get keyring)"; return 1; fi
      if ! cond_redirect wget -nv -O debian-archive-keyring.deb http://ftp.us.debian.org/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2019.1+deb10u1_all.deb; then echo "FAILED (get archive keyring)"; return 1; fi
      if ! cond_redirect dpkg -i debian-keyring.deb; then echo "FAILED (add keyring)"; return 1; fi
      if ! cond_redirect dpkg -i debian-archive-keyring.deb; then echo "FAILED (add archive keyring)"; return 1; fi
      rm -f debian-keyring.deb debian-archive-keyring.deb

      echo -e "Package: *\\nPin: release a=buster-backports\\nPin-Priority: 90\\n" > /etc/apt/preferences.d/limit-buster-backports

      if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      if cond_redirect apt-get install --yes --target-release "buster-backports" golang-go; then echo "OK"; else echo "FAILED"; return 1; fi
    else
      if cond_redirect apt-get install --yes golang-go; then echo "OK"; else echo "FAILED"; return 1; fi
    fi
  fi
}

## Function to enable monitor mode on RPi
##
##    setup_monitor_mode()
##
setup_monitor_mode() {
  if ! is_pi_wlan; then
    echo "$(timestamp) [openHABian] Incompatible hardware detected! Canceling Monitor Mode setup!"
    return 0
  fi
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] Monitor Mode setup must be run in interactive mode! Canceling Monitor Mode setup!"
    return 0
  fi

  local disabledText
  local firmwarePath
  local firmwareVersion
  local introText
  local KERNEL
  local nexmonDir
  local successText
  local version

  disabledText="WiFi is currently disabled on your box.\\n\\nATTENTION:\\nWould you like to enable WiFi and continue setup?"
  firmwarePath="$(modinfo --field=filename brcmfmac | sed -e 's|/brcmfmac.ko||g')"
  introText="This will patch your RPi's WiFi firmware to enable Monitor Mode. This will make regular WiFi use not possible without manual configuration. This is in no way guaranteed to work and may destroy your system!\\n\\nThis is a highly advanced function and should only be used by people who know exactly what they are doing. This will void any warranty on your HW.\\n\\nFor more details on how this works and what to do with it see:\\nhttps://github.com/seemoo-lab/nexmon/blob/master/README.md"
  KERNEL="$(iw dev wlan0 info | awk '/wiphy/ {printf "phy" $2}')"
  nexmonDir="/opt/nexmon"
  successText="Setup completed successfully, however this does not mean it worked correctly.\\n\\nPlease reboot and the Monitor Mode should be available and ready for use on interface 'mon0'!"
  if [[ $(uname -r) == 5.4* ]]; then
    version="brcmfmac_5.4.y-nexmon"
    if is_pizerow || is_pithree; then
      echo "$(timestamp) [openHABian] Monitor Mode patch has not been updated for kernel version 5.4 on your RPi... CANCELED"
      return 0
    elif is_pithreeplus || is_pifour; then
      firmwareVersion="bcm43455c0/7_45_206"
    fi
  elif [[ $(uname -r) == 4.19* ]]; then
    version="brcmfmac_4.19.y-nexmon"
    if is_pizerow || is_pithree; then
      echo "$(timestamp) [openHABian] Monitor Mode patch has not been updated for kernel version 4.19 on your RPi... CANCELED"
      return 0
    elif is_pithreeplus || is_pifour; then
      firmwareVersion="bcm43455c0/7_45_189"
    fi
  elif [[ $(uname -r) == 4.14* ]]; then
    version="brcmfmac_4.14.y-nexmon"
    if is_pizerow || is_pithree; then
      firmwareVersion="bcm43430a1/7_45_41_46"
    elif is_pithreeplus || is_pifour; then
      firmwareVersion="bcm43455c0/7_45_189"
    fi
  fi

  echo -n "$(timestamp) [openHABian] Beginning setup of Monitor Mode... "
  if grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?disable-wifi" /boot/config.txt; then
    if (whiptail --title "WiFi is currently disabled" --yesno "$disabledText" 10 80); then
      cond_redirect enable_disable_wifi "enable"
    else
      echo "CANCELED"
      return 0
    fi
  fi
  if (whiptail --title "Monitor Mode setup" --yes-button "Begin" --no-button "Cancel" --defaultno --yesno "$introText" 15 80); then echo "OK"; else echo "CANCELED"; return 0; fi

  if ! dpkg -s 'firmware-brcm80211' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing WiFi firmware... "
    if cond_redirect apt-get install --yes firmware-brcm80211; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Installing required Monitor Mode packages... "
  if cond_redirect apt-get install --yes raspberrypi-kernel-headers libgmp3-dev gawk qpdf bison flex make automake texinfo libtool-bin; then echo "OK"; else echo "FAILED"; return 1; fi

  echo -n "$(timestamp) [openHABian] Downloading Nexmon... "
  if ! [[ -d $nexmonDir ]]; then
    cond_echo "\\nFresh Installation... "
    if ! cond_redirect git clone https://github.com/seemoo-lab/nexmon.git $nexmonDir; then echo "FAILED (git clone)"; return 1; fi
  else
    cond_echo "\\nUpdate... "
    if ! cond_redirect update_git_repo "$nexmonDir" "master"; then echo "FAILED (update git repo)"; return 1; fi
  fi
  if cond_redirect touch "${nexmonDir}/DISABLE_STATISTICS"; then echo "OK"; else echo "FAILED (disable statistics)"; return 1; fi

  if ! [[ -f /usr/lib/arm-linux-gnueabihf/libisl.so.10 ]]; then
    echo -n "$(timestamp) [openHABian] Compiling ISL from source... "
    if ! cond_redirect cd "${nexmonDir}/buildtools/isl-0.10"; then echo "FAILED (cd)"; return 1; fi
    if ! cond_redirect autoreconf --force --install "${nexmonDir}/buildtools/isl-0.10"; then echo "FAILED (autoreconf)"; return 1; fi
    if ! cond_redirect bash "${nexmonDir}/buildtools/isl-0.10/configure"; then echo "FAILED (configure)"; return 1; fi
    if ! cond_redirect make --directory="${nexmonDir}/buildtools/isl-0.10"; then echo "FAILED (make)"; return 1; fi
    if ! cond_redirect make --directory="${nexmonDir}/buildtools/isl-0.10" install; then echo "FAILED (install)"; return 1; fi
    if cond_redirect ln -sf /usr/local/lib/libisl.so /usr/lib/arm-linux-gnueabihf/libisl.so.10; then echo "OK"; else echo "FAILED (link)"; return 1; fi
  fi

  if ! [[ -f /usr/lib/arm-linux-gnueabihf/libmpfr.so.4 ]]; then
    echo -n "$(timestamp) [openHABian] Compiling MPFR from source... "
    if ! cond_redirect cd "${nexmonDir}/buildtools/mpfr-3.1.4"; then echo "FAILED (cd)"; return 1; fi
    if ! cond_redirect autoreconf --force --install "${nexmonDir}/buildtools/mpfr-3.1.4"; then echo "FAILED (autoreconf)"; return 1; fi
    if ! cond_redirect bash "${nexmonDir}/buildtools/mpfr-3.1.4/configure"; then echo "FAILED (configure)"; return 1; fi
    if ! cond_redirect make --directory="${nexmonDir}/buildtools/mpfr-3.1.4"; then echo "FAILED (make)"; return 1; fi
    if ! cond_redirect make --directory="${nexmonDir}/buildtools/mpfr-3.1.4" install; then echo "FAILED (install)"; return 1; fi
    if cond_redirect ln -sf /usr/local/lib/libmpfr.so /usr/lib/arm-linux-gnueabihf/libmpfr.so.4; then echo "OK"; else echo "FAILED (link)"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Prepare for firmware patches... "
  if ! cond_redirect cd "$nexmonDir"; then echo "FAILED (cd)"; return 1; fi
  if ! cond_redirect source "${nexmonDir}/setup_env.sh"; then echo "FAILED (configure)"; return 1; fi
  if cond_redirect make --directory="$nexmonDir"; then echo "OK"; else echo "FAILED (make)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Creating firmware patches... "
  if ! cond_redirect cd "${nexmonDir}/patches/${firmwareVersion}/nexmon"; then echo "FAILED (cd)"; return 1; fi
  if ! cond_redirect make --directory="${nexmonDir}/patches/${firmwareVersion}/nexmon"; then echo "FAILED (make)"; return 1; fi
  if ! cond_redirect make --directory="${nexmonDir}/patches/${firmwareVersion}/nexmon" backup-firmware; then echo "FAILED (backup-firmware)"; return 1; fi
  if ! cond_redirect make --directory="${nexmonDir}/patches/${firmwareVersion}/nexmon" install-firmware; then echo "FAILED (install-firmware)"; return 1; fi
  if ! cond_redirect mv "${firmwarePath}/brcmfmac.ko" "${firmwarePath}/brcmfmac.ko.orig"; then echo "FAILED (backup)"; return 1; fi
  if cond_redirect cp "${nexmonDir}/patches/${firmwareVersion}/nexmon/${version}/brcmfmac.ko" "${firmwarePath}/"; then echo "OK"; else echo "FAILED (copy)"; return 1; fi


  echo -n "$(timestamp) [openHABian] Making firmware patches persistent... "
  if ! cond_redirect depmod --all; then echo "FAILED (depmod)"; return 1; fi
  if (sed -e 's|%KERNEL|'"${KERNEL}"'|g' "${BASEDIR:-/opt/openhabian}"/includes/90-wireless.rules > /etc/udev/rules.d/90-wireless.rules); then echo "OK"; else echo "FAILED (udev file creation)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Installing nexutil... "
  if ! cond_redirect cd "${nexmonDir}/utilities/nexutil"; then echo "FAILED (cd)"; return 1; fi
  if ! cond_redirect make --directory="${nexmonDir}/utilities/nexutil"; then echo "FAILED (make)"; return 1; fi
  if cond_redirect make --directory="${nexmonDir}/utilities/nexutil" install; then echo "OK"; else echo "FAILED (install)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$successText" 11 80
  fi
}
