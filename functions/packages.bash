#!/usr/bin/env bash

samba_setup() {
  echo -n "$(timestamp) [openHABian] Setting up Samba network shares... "
  if ! command -v samba &>/dev/null; then
  if ! cond_redirect apt-get -y install samba; then echo "FAILED"; exit 1; fi
  fi
  cond_echo "Copying over custom 'smb.conf'... "
  cp "$BASEDIR"/includes/smb.conf /etc/samba/smb.conf
  cond_echo "Writing authentication data to openHABian default... "
  if ! /usr/bin/smbpasswd -e "$username" &>/dev/null; then
    # shellcheck disable=SC2154
    ( (echo "${userpw}"; echo "${userpw}") | /usr/bin/smbpasswd -s -a "${username}" > /dev/null )
  fi
  cond_redirect systemctl enable smbd.service
  cond_redirect systemctl restart smbd.service
  echo "OK"
}

firemotd_setup() {
  FAILED=0
  echo -n "$(timestamp) [openHABian] Downloading and setting up FireMotD... "
  cond_redirect apt-get -y install bc sysstat jq moreutils

  # fetch and install
  cond_redirect curl -s https://raw.githubusercontent.com/OutsideIT/FireMotD/master/FireMotD -o /tmp/FireMotD || FAILED=1
  chmod 755 /tmp/FireMotD
  cond_redirect /tmp/FireMotD -I || FAILED=1
  # generate theme
  cond_redirect FireMotD -G Gray
  # initial apt updates check
  cond_redirect FireMotD -S
  # the following is already in bash_profile by default
  if ! grep -q "FireMotD" /home/"$username"/.bash_profile; then
    echo -e "\\necho\\nFireMotD --theme Gray \\necho" >> /home/"$username"/.bash_profile
  fi

  # invoke apt updates check every night
  echo "# FireMotD system updates check (randomly execute between 0:00:00 and 5:59:59)" > /etc/cron.d/firemotd
  echo "0 0 * * * root perl -e 'sleep int(rand(21600))' && /bin/bash /usr/local/bin/FireMotD -S &>/dev/null" >> /etc/cron.d/firemotd
  # invoke apt updates check after every apt action ('apt-get upgrade', ...)
  echo "DPkg::Post-Invoke { \"if [ -x /usr/local/bin/FireMotD ]; then echo -n 'Updating FireMotD available updates count ... '; /bin/bash /usr/local/bin/FireMotD --skiprepoupdate -S; echo ''; fi\"; };" > /etc/apt/apt.conf.d/15firemotd
  if [ $FAILED -eq 1 ]; then echo "FAILED "; else echo "OK "; fi
}

create_mta_config() {
  TMP="$(mktemp /tmp/.XXXXXXXXXX)"
  HOSTNAME=$(/bin/hostname)
  INTERFACES="$(/usr/bin/dig +short "$HOSTNAME" | /usr/bin/tr '\n' ';');127.0.0.1;::1"
  EXIM_CLIENTCONFIG=/etc/exim4/passwd.client

  introtext1="We will guide you through the install of exim4 as the mail transfer agent on your system and configure it to relay mails through a public service such as Google gmail.\\nPlease
enter the data shown in the next window when being asked for. You will be able to repeat the whole installation if required by selecting the openHABian menu for MTA again."
  introtext2="Mail server type: mail sent by smarthost; received via SMTP or fetchmail\\nSystem mail name: FQDN (your full hostname including the domain part)\\nIPs should be allowed by the se
rver: $INTERFACES\\nOther destinations for which mail is accepted: $HOSTNAME\\nMachines to relay mail for: Leave empty\\nIP address or host name of outgoing smarthost: smtp.gmail.com::587\\nHide
 local mail name in outgoing mail: No\\nKeep number of DNS-queries minimal: No\\nDelivery method: Select: Maildir format in home directory\\nMinimize number of DNS queries: No\\nSplit configurat
ion into small files: Yes\\n"
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Mail Transfer Agent installation" --yes-button "Start" --no-button "don't change MTA" --yesno "$introtext1" 12 78) then echo "CANCELED"; return 0; fi
    if ! (whiptail --title "Mail Transfer Agent installation" --msgbox "$introtext2" 18 78) then echo "CANCELED"; return 0; fi
  else
    echo "Ignoring MTA config creation in unattended install mode."
    return 0
  fi

  dpkg-reconfigure exim4-config
  if ! SMARTHOST=$(whiptail --title "Enter public mail service smarthost to relay your mails to" --inputbox "\\nEnter the list of smarthost(s) to use your account for" 9 78 "*.google.com" 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  if ! RELAYUSER=$(whiptail --title "Enter your public service mail user" --inputbox "\\nEnter the mail username of the public service to relay all outgoing mail to ${SMARTHOST}" 9 78 "yourname@gmail.com" 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  if ! RELAYPASS=$(whiptail --title "Enter your public service mail password" --passwordbox "\\nEnter the password used to relay mail as ${RELAYUSER}@${SMARTHOST}" 9 78 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi

  grep '^#' "${EXIM_CLIENTCONFIG}" > "$TMP"
  echo "${SMARTHOST}:${RELAYUSER}:${RELAYPASS}" >> "$TMP"
  cp "$TMP" "${EXIM_CLIENTCONFIG}"
  /bin/chmod o-rwx "${EXIM_CLIENTCONFIG}"
  rm -f "$TMP"
}

exim_setup() {
  if apt-get -y install exim4 dnsutils mailutils &>/dev/null; then
    echo "OK"
  else
    echo "FAILED"
  fi
  create_mta_config
}

etckeeper_setup() {
  echo -n "$(timestamp) [openHABian] Installing etckeeper (git based /etc backup)... "
  if apt-get -y install etckeeper &>/dev/null; then
    cond_redirect sed -i 's/VCS="bzr"/\#VCS="bzr"/g' /etc/etckeeper/etckeeper.conf
    cond_redirect sed -i 's/\#VCS="git"/VCS="git"/g' /etc/etckeeper/etckeeper.conf
    if cond_redirect bash -c "cd /etc && etckeeper init && git config user.email 'etckeeper@localhost' && git config user.name 'openhabian' && git commit -m 'initial checkin' && git gc"; then echo "OK"; else echo "FAILED"; fi
  else
    echo "FAILED";
  fi
}

homegear_setup() {
  FAILED=0
  introtext="This will install Homegear, the Homematic CCU2 emulation software, in the latest stable release from the official repository."
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.
Homegear is now up and running. Next you might want to edit the configuration file '/etc/homegear/families/homematicbidcos.conf' or adopt devices through the homegear console, reachable by 'sudo homegear -r'.
Please read up on the homegear documentation for more details: https://doc.homegear.eu/data/homegear
To continue your integration in openHAB 2, please follow the instructions under: https://www.openhab.org/addons/bindings/homematic/
"

  echo -n "$(timestamp) [openHABian] Setting up the Homematic CCU2 emulation software Homegear... "
  if is_pine64; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "We are sorry, Homegear is not yet available for your platform." 10 60
    fi
    echo "FAILED (incompatible)"; return 1
  fi

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
  fi

  cond_redirect wget -O - http://homegear.eu/packages/Release.key | apt-key add -

  distro="$(lsb_release -si)-$(lsb_release -sc)"
  case "$distro" in
    Debian-jessie)
      echo 'deb https://apt.homegear.eu/Debian/ jessie/' > /etc/apt/sources.list.d/homegear.list
      ;;
    Debian-stretch)
      echo 'deb https://apt.homegear.eu/Debian/ stretch/' > /etc/apt/sources.list.d/homegear.list
      ;;
    Debian-buster)
      echo 'deb https://apt.homegear.eu/Debian/ buster/' > /etc/apt/sources.list.d/homegear.list
      ;;
    Raspbian-jessie)
      echo 'deb https://apt.homegear.eu/Raspbian/ jessie/' > /etc/apt/sources.list.d/homegear.list
      ;;
    Raspbian-stretch)
      echo 'deb https://apt.homegear.eu/Raspbian/ stretch/' > /etc/apt/sources.list.d/homegear.list
      ;;
    Raspbian-buster)
      echo 'deb https://apt.homegear.eu/Raspbian/ buster/' > /etc/apt/sources.list.d/homegear.list
      ;;
    Ubuntu-trusty)
      echo 'deb https://apt.homegear.eu/Ubuntu/ trusty/' > /etc/apt/sources.list.d/homegear.list
      ;;
    Ubuntu-xenial)
      echo 'deb https://apt.homegear.eu/Ubuntu/ xenial/' > /etc/apt/sources.list.d/homegear.list
      ;;
    Ubuntu-bionic)
      echo 'deb https://apt.homegear.eu/Ubuntu/ bionic/' > /etc/apt/sources.list.d/homegear.list
      ;;
    *)
      cond_echo "Your OS is not supported"
      exit 1
      ;;
  esac

  if ! cond_redirect apt-get update; then echo "FAILED"; exit 1; fi
  if ! cond_redirect apt-get -y install homegear homegear-homematicbidcos homegear-homematicwired; then echo "FAILED"; exit 1; fi
  cond_redirect systemctl enable homegear.service
  cond_redirect systemctl start homegear.service
  cond_redirect adduser "${username:-openhabian}" homegear
  cond_redirect adduser openhab homegear
  echo "OK"

  if [ -n "$INTERACTIVE" ]; then
    if [ "$FAILED" -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

mqtt_setup() {
  FAILED=0
  introtext="The MQTT broker Eclipse Mosquitto will be installed through the official repository, as desribed in: https://mosquitto.org/2013/01/mosquitto-debian-repository\\nAdditionally you can activate username:password authentication.\\n\\nHEADS UP: Only proceed when you are aware that this will be in conflict with use of the MQTTv2 binding which will also be using the same ports."
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.\\nEclipse Mosquitto is now up and running in the background. You should be able to make a first connection.
To continue your integration in openHAB 2, please follow the instructions under: https://www.openhab.org/addons/bindings/mqtt/
"
  echo -n "$(timestamp) [openHABian] Setting up the MQTT broker Eclipse Mosquitto... "

  mqttuser="openhabian"
  question1="Do you really want to install a separate MQTT broker?\\nNote that openHAB version 2.5M1 or higher comes with a new OHv2 MQTT binding that if you choose to enable it by default will use thus occupy the same ports as mosquitto here would try to use."
  question2="Do you want to secure your MQTT broker by a username:password combination? Every client will need to provide these upon connection.\\nUsername will be '$mqttuser', please provide a password (consisting of ASCII printable characters except space). Leave blank for no authentication, run method again to change."
  if ! (whiptail --title "MQTT Broker installation" --yes-button "Install Mosquitto" --no-button "Use MQTTv2 binding" --yesno "$question1" 12 78) then echo "CANCELED"; return 0; fi
  mqttpasswd=$(whiptail --title "MQTT Authentication" --inputbox "$question2" 15 80 3>&1 1>&2 2>&3)
  if is_jessie; then
    cond_redirect wget -O - http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | apt-key add -
    echo "deb http://repo.mosquitto.org/debian jessie main" > /etc/apt/sources.list.d/mosquitto-jessie.list
  fi
  if ! cond_redirect apt-get -y install mosquitto mosquitto-clients; then echo "FAILED"; exit 1; fi
  if [ "$mqttpasswd" != "" ]; then
    if ! grep -q password_file /etc/mosquitto/passwd /etc/mosquitto/mosquitto.conf; then
      echo -e "\\npassword_file /etc/mosquitto/passwd\\nallow_anonymous false\\n" >> /etc/mosquitto/mosquitto.conf
    fi
    echo -n "" > /etc/mosquitto/passwd
    if ! cond_redirect mosquitto_passwd -b /etc/mosquitto/passwd $mqttuser $mqttpasswd; then echo "FAILED"; exit 1; fi
  else
    cond_redirect sed -i "/password_file/d" /etc/mosquitto/mosquitto.conf
    cond_redirect sed -i "/allow_anonymous/d" /etc/mosquitto/mosquitto.conf
    cond_redirect rm -f /etc/mosquitto/passwd
  fi
  cond_redirect systemctl enable mosquitto.service
  if cond_redirect systemctl restart mosquitto.service; then echo "OK"; else echo "FAILED"; exit 1; fi

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

find_setup() {
  introtext="Install and setup the FIND server system to allow for indoor localization of WiFi devices. Please note that FIND will run together with an app that's available on Android ONLY. See further information at http://www.internalpositioning.com"
  failtext="Sadly there was a problem setting up the selected option.\\nPlease report this problem in the openHAB community forum or as an openHABian GitHub issue."
  successtext="FIND setup was successful. Settings can be configured in '/etc/default/findserver'. Be sure to restart the service after.\\nObtain the FIND app for Android through the Play Store. Check out your FIND server's dashboard at: http://${HOSTNAME}:8003\\nFor further information: http://www.internalpositioning.com"

  matched=false

  echo -n "$(timestamp) [openHABian] Setting up FIND, the Framework for Internal Navigation and Discovery... "
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
  fi

  # Check for updated versions: https://github.com/schollz/find/releases
  FIND_RELEASE="2.4.1"
  CLIENT_RELEASE="0.6"
  if is_arm; then
    ARCH="arm"
  else
    ARCH="amd64"
  fi
  FIND_SRC="https://github.com/schollz/find/releases/download/v${FIND_RELEASE}/find_${FIND_RELEASE}_linux_${ARCH}.zip"
  CLIENT_SRC="https://github.com/schollz/find/releases/download/v${CLIENT_RELEASE}client/fingerprint_${CLIENT_RELEASE}_linux_${ARCH}.zip"

  FIND_SYSTEMCTL="/etc/systemd/system/findserver.service"
  FIND_DEFAULT="/etc/default/findserver"
  FIND_DSTDIR="/var/lib/findserver"
  MOSQUITTO_CONF="/etc/mosquitto/mosquitto.conf"
  MOSQUITTO_PASSWD="/etc/mosquitto/passwd"
  DEFAULTFINDUSER="find"
  FINDSERVER="localhost"
  FINDPORT=8003
  FIND_TMP="/tmp/find-latest.$$"
  CLIENT_TMP="/tmp/fingerprint-latest.$$"

  if [ ! -f "${MOSQUITTO_CONF}" ]; then
    mqttservermessage="FIND requires an MQTT broker to run, but Mosquitto is not installed on this system.\\nYou can configure FIND to use any existing MQTT broker (in the next step) or you can go back and install Mosquitto from the openHABian menu.\\nDo you want to continue with the FIND installation?"
    if ! (whiptail --title "Mosquitto not installed, continue?" --yes-button "Continue" --no-button "Back" --yesno "$mqttservermessage" 15 80) then echo "CANCELED"; return 0; fi
  fi

  if ! MQTTSERVER=$(whiptail --title "FIND Setup" --inputbox "Please enter the hostname of the device your MQTT broker is running on:" 15 80 localhost 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  if ! MQTTPORT=$(whiptail --title "FIND Setup" --inputbox "Please enter the port number the MQTT broker is listening on:" 15 80 1883 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi

  if [ "$MQTTSERVER" != "localhost" ]; then
    brokermessage="You've chosen to work with an external MQTT broker. Please be aware that you might need to add authentication credentials. You can do so after the installation. Consult with the FIND documentation or the openHAB community for details."
    whiptail --title "MQTT Broker Notice" --msgbox "$brokermessage" 15 80
  fi

  if [ -f ${MOSQUITTO_PASSWD} ]; then
    if ! FINDADMIN=$(whiptail --title "findserver MQTT Setup" --inputbox "Enter a username for FIND to connect with on your MQTT broker:" 15 80 $DEFAULTFINDUSER 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
    if ! FINDADMINPASS=$(whiptail --title "findserver MQTT Setup" --passwordbox "Enter a password for the FIND user on your MQTT broker:" 15 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
    if ! secondpassword=$(whiptail --title "findserver MQTT Setup" --passwordbox "Please confirm the password for the FIND user on your MQTT broker:" 15 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
    if [ "$FINDADMINPASS" = "$secondpassword" ] && [ -n "$FINDADMINPASS" ]; then
      matched=true
    else
      echo "FAILED (password)"
      return 1
    fi
    if ! cond_redirect /usr/bin/mosquitto_passwd -b $MOSQUITTO_PASSWD "$FINDADMIN" "$FINDADMINPASS"; then echo "FAILED (mosquitto)"; return 1; fi
    cond_redirect systemctl restart mosquitto.service || true
  fi

  if ! cond_redirect apt-get -y install libsvm-tools; then echo "FAILED (SVM)"; return 1; fi

  cond_redirect mkdir -p ${FIND_DSTDIR}
  cond_redirect wget -O ${FIND_TMP} ${FIND_SRC}
  cond_redirect wget -O ${CLIENT_TMP} ${CLIENT_SRC}
  cond_redirect unzip -qo ${CLIENT_TMP} fingerprint -d ${FIND_DSTDIR}
  cond_redirect unzip -qo ${FIND_TMP} -d ${FIND_DSTDIR}
  cond_redirect ln -sf ${FIND_DSTDIR}/findserver /usr/sbin/findserver
  cond_redirect ln -sf ${FIND_DSTDIR}/fingerprint /usr/sbin/fingerprint

  cond_echo "Writing service file '$FIND_SYSTEMCTL'"
  sed -e "s|%MQTTSERVER|$MQTTSERVER|g" -e "s|%MQTTPORT|$MQTTPORT|g" -e "s|%FINDADMINPASS|$FINDADMINPASS|g" -e "s|%FINDADMIN|$FINDADMIN|g" -e "s|%FINDPORT|$FINDPORT|g" -e "s|%FINDSERVER|$FINDSERVER|g" "${BASEDIR}/includes/findserver.service" > $FIND_SYSTEMCTL
  cond_echo "Writing service config file '$FIND_DEFAULT'"
  sed -e "s|%MQTTSERVER|$MQTTSERVER|g" -e "s|%MQTTPORT|$MQTTPORT|g" -e "s|%FINDADMINPASS|$FINDADMINPASS|g" -e "s|%FINDADMIN|$FINDADMIN|g" -e "s|%FINDPORT|$FINDPORT|g" -e "s|%FINDSERVER|$FINDSERVER|g" "${BASEDIR}/includes/findserver" > $FIND_DEFAULT

  cond_redirect rm -f ${FIND_TMP} ${CLIENT_TMP}
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl restart findserver.service
  cond_redirect systemctl status findserver.service
  if ! cond_redirect systemctl enable findserver.service; then echo "FAILED (service)"; return 1; fi

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
  echo "OK"
  dashboard_add_tile find
}

knxd_setup() {
  FAILED=0
  introtext="This will install and setup kndx (successor to eibd) as your EIB/KNX IP gateway and router to support your KNX bus system. This routine was provided by 'Michels Tech Blog': https://goo.gl/qN2t0H"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.
Please edit '/etc/default/knxd' to meet your interface requirements. For further information on knxd options, please type 'knxd --help'
Further details can be found unter: https://goo.gl/qN2t0H
Integration into openHAB 2 is described here: https://github.com/openhab/openhab/wiki/KNX-Binding
"

  echo -n "$(timestamp) [openHABian] Setting up EIB/KNX IP Gateway and Router with knxd "
  echo -n "(http://michlstechblog.info/blog/raspberry-pi-eibknx-ip-gateway-and-router-with-knxd)... "
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
  fi

  #TODO serve file from the repository
  cond_redirect wget -O /tmp/install_knxd_systemd.sh http://michlstechblog.info/blog/download/electronic/install_knxd_systemd.sh || FAILED=1

  #hotfix for #651: switch to newer libfmt
  cond_redirect sed -i 's#git checkout tags/3.0.0#git checkout tags/5.0.0#' /tmp/install_knxd_systemd.sh || FAILED=1
  #shellcheck disable=SC2016
  cond_redirect sed -i 's#cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX fmt/#cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX .#' /tmp/install_knxd_systemd.sh || FAILED=1
  #/hotfix

  #NOTE install_knxd_systemd.sh currently does not give proper exit status for errors, so installer claims success...
  cond_redirect bash /tmp/install_knxd_systemd.sh || FAILED=1
  if [ $FAILED -eq 0 ]; then echo "OK. Please restart your system now..."; else echo "FAILED"; fi
  #systemctl start knxd.service
  #if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

1wire_setup() {
  FAILED=0
  introtext="This will install owserver to support 1wire functionality in general, ow-shell and usbutils are helpfull tools to check USB (lsusb) and 1wire function (owdir, owread). For more details, have a look at http://owfs.org"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.
Next, please configure your system in /etc/owfs.conf.
Use # to comment/deactivate a line. All you should have to change is the following. Deactivate
  server: FAKE = DS18S20,DS2405
and activate one of these most common options (depending on your device):
  #server: usb = all
  #server: device = /dev/ttyS1
  #server: device = /dev/ttyUSB0
"

  echo -n "$(timestamp) [openHABian] Installing owserver (1wire)... "
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
  fi

  cond_redirect apt-get -y install owserver ow-shell usbutils || FAILED=1
  if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

miflora_setup() {
  FAILED=0
  DIRECTORY="/opt/miflora-mqtt-daemon"
  introtext="[CURRENTLY BROKEN] This will install or update miflora-mqtt-daemon - The Xiaomi Mi Flora Plant Sensor MQTT Client/Daemon. See for further details:\\n\\n   https://github.com/ThomDietrich/miflora-mqtt-daemon"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.
The Daemon was installed and the systemd service was set up just as described in it's README. Please add your MQTT broker settings in '$DIRECTORY/config.ini' and add your Mi Flora sensors. After that be sure to restart the daemon to reload it's configuration.
\\nAll details can be found under: https://github.com/ThomDietrich/miflora-mqtt-daemon
The article also contains instructions regarding openHAB integration.
"

  echo -n "$(timestamp) [openHABian] Setting up miflora-mqtt-daemon... "
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
  fi

  if ! cond_redirect apt-get -y install git python3 python3-pip bluetooth bluez; then echo "FAILED (prerequisites)"; exit 1; fi
  if [ ! -d "$DIRECTORY" ]; then
    cond_echo "Fresh Installation... "
    cond_redirect git clone https://github.com/ThomDietrich/miflora-mqtt-daemon.git $DIRECTORY
    if ! cond_redirect cp "$DIRECTORY"/config.{ini.dist,ini}; then echo "FAILED (git clone)"; exit 1; fi
  else
    cond_echo "Update... "
    if ! cond_redirect git -C "$DIRECTORY" pull --quiet origin; then echo "FAILED (git pull)"; exit 1; fi
  fi
  cond_redirect chown -R "openhab:$username" "$DIRECTORY"
  cond_redirect chmod -R ug+wX "$DIRECTORY"
  if ! cond_redirect pip3 install -r "$DIRECTORY"/requirements.txt; then echo "FAILED (requirements)"; exit 1; fi
  cond_redirect cp "$DIRECTORY"/template.service /etc/systemd/system/miflora.service
  cond_redirect systemctl daemon-reload
  systemctl start miflora.service || true
  cond_redirect systemctl status miflora.service
  if cond_redirect systemctl enable miflora.service; then echo "OK"; else echo "FAILED"; exit 1; fi
  if grep -q "dtoverlay=pi3-miniuart-bt" /boot/config.txt; then
    cond_echo "Warning! The internal RPi3 Bluetooth module is disabled on your system. You need to enable it before the daemon may use it."
  fi
  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

nginx_setup() {
  introtext="This will enable you to access the openHAB interface through the normal HTTP/HTTPS ports and optionally secure it with username/password and/or an SSL certificate."
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."

  echo "$(timestamp) [openHABian] Setting up Nginx as reverse proxy with authentication... "
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
  fi

  function comment {
    sed -i "$1"' s/^/#/' "$2"
  }
  function uncomment {
    sed -i "$1"' s/^ *#//' "$2"
  }

  echo "Installing DNS utilities..."
  apt-get -y -q install dnsutils

  AUTH=false
  SECURE=false
  VALIDDOMAIN=false
  matched=false
  canceled=false
  FAILED=false

  if (whiptail --title "Authentication Setup" --yesno "Would you like to secure your openHAB interface with username and password?" 15 80) then
    if username=$(whiptail --title "Authentication Setup" --inputbox "Enter a username to sign into openHAB:" 15 80 openhab 3>&1 1>&2 2>&3); then
      while [ "$matched" = false ] && [ "$canceled" = false ]; do
        password=$(whiptail --title "Authentication Setup" --passwordbox "Enter a password for $username:" 15 80 3>&1 1>&2 2>&3)
        secondpassword=$(whiptail --title "Authentication Setup" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ "$password" = "$secondpassword" ] && [ -n "$password" ]; then
          matched=true
          AUTH=true
        else
          password=$(whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3)
        fi
      done
    else
      canceled=true
    fi
  fi

  if (whiptail --title "Secure Certificate Setup" --yesno "Would you like to secure your openHAB interface with HTTPS?" 15 80) then
    SECURE=true
  fi

  echo -n "Obtaining public IP address... "
  wanip=$(dig +short myip.opendns.com @resolver1.opendns.com |tail -1)
  echo "$wanip"

  domain=$(whiptail --title "Domain Setup" --inputbox "If you have a registered domain enter it now, if you have a static public IP enter \"IP\", otherwise leave blank:" 15 80 3>&1 1>&2 2>&3)

  while [ "$VALIDDOMAIN" = false ] && [ -n "$domain" ] && [ "$domain" != "IP" ]; do
    echo -n "Obtaining domain IP address... "
    domainip=$(dig +short "$domain" @resolver1.opendns.com |tail -1)
    echo "$domainip"
    if [ "$wanip" = "$domainip" ]; then
      VALIDDOMAIN=true
      echo "Public and domain IP address match"
    else
      echo "Public and domain IP address mismatch!"
      domain=$(whiptail --title "Domain Setup" --inputbox "Domain does not resolve to your public IP address. Please enter a valid domain, if you have a static public IP enter \"IP\",leave blank to not use a domain name:" 15 80 3>&1 1>&2 2>&3)
    fi
  done

  if [ "$VALIDDOMAIN" = false ]; then
    if [ "$domain" == "IP" ]; then
      echo "Setting domain to static public IP address $wanip"
      domain=$wanip
    else
      echo "Setting no domain nor static public IP address"
      domain="localhost"
    fi
  fi

  if [ "$AUTH" = true ]; then
    authtext="Authentication Enabled\\n- Username: $username"
  else
    authtext="Authentication Disabled"
  fi

  if [ "$SECURE" = true ]; then
    httpstext="Proxy will be secured by HTTPS"
    protocol="HTTPS"
    portwarning="Important! Before you continue, please make sure that port 80 (HTTP) of this machine is reachable from the internet (portforwarding, ...). Otherwise the certbot connection test will fail.\\n\\n"
  else
    httpstext="Proxy will not be secured by HTTPS"
    protocol="HTTP"
    portwarning=""
  fi

  confirmtext="The following settings have been chosen:\\n\\n- $authtext\\n- $httpstext\\n- Domain: $domain (Public IP Address: $wanip)
  \\nYou will be able to connect to openHAB on the default $protocol port.
  \\n${portwarning}Do you wish to continue and setup an NGINX server now?"

  if (whiptail --title "Confirmation" --yesno "$confirmtext" 22 80) then
    echo "Installing NGINX..."
    apt-get -y -q install nginx || FAILED=true

    rm -rf /etc/nginx/sites-enabled/default
    cp "$BASEDIR"/includes/nginx.conf /etc/nginx/sites-enabled/openhab

    sed -i "s/DOMAINNAME/${domain}/g" /etc/nginx/sites-enabled/openhab

    if [ "$AUTH" = true ]; then
      echo "Installing password utilities..."
      apt-get -y -q install apache2-utils || FAILED=true
      echo "Creating password file..."
      htpasswd -b -c /etc/nginx/.htpasswd "$username" "$password"
      uncomment 32,33 /etc/nginx/sites-enabled/openhab
    fi

    if [ "$SECURE" = true ]; then
      if [ "$VALIDDOMAIN" = true ]; then
        certbotpackage="python-certbot-nginx"
        if is_debian || is_raspbian; then
          gpg --keyserver pgpkeys.mit.edu --recv-key 8B48AD6246925553
          gpg -a --export 8B48AD6246925553 | apt-key add -
          gpg --keyserver pgpkeys.mit.edu --recv-key 7638D0442B90D010
          gpg -a --export 7638D0442B90D010 | apt-key add -
          if is_jessie; then
            certbotrepo="jessie-backports"
            certbotpackage="certbot"
          elif is_stretch; then
            certbotrepo="stretch-backports"
          fi
          certbotoption="-t"
          if [ ! -z "$certbotrepo" ]; then
            echo -e "# This file was added by openHABian to install certbot\\ndeb http://ftp.debian.org/debian ${certbotrepo} main" > /etc/apt/sources.list.d/backports.list
          fi
        elif is_ubuntu; then
          apt -get -y -q --force-yes install software-properties-common
          add-apt-repository ppa:certbot/certbot
        fi
        echo "Installing certbot..."
        apt-get -y -q --force-yes install "${certbotpackage}" "${certbotoption}" "${certbotrepo}"
        mkdir -p /var/www/$domain
        uncomment 37,39 /etc/nginx/sites-enabled/openhab
        nginx -t && service nginx reload
        echo "Creating Let's Encrypt certificate..."
        certbot certonly --webroot -w /var/www/$domain -d $domain || FAILED=true #This will cause a prompt
        if [ "$FAILED" = false ]; then
          certpath="/etc/letsencrypt/live/$domain/fullchain.pem"
          keypath="/etc/letsencrypt/live/$domain/privkey.pem"
        fi
      else
        mkdir -p /etc/ssl/certs
        certpath="/etc/ssl/certs/openhab.crt"
        keypath="/etc/ssl/certs/openhab.key"
        password=$(whiptail --title "openSSL Key Generation" --msgbox "openSSL is about to ask for information in the command line, please fill out each line." 15 80 3>&1 1>&2 2>&3)
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout $keypath -out $certpath || FAILED=true #This will cause a prompt
      fi
      if [ "$FAILED" = false ]; then
        uncomment 20,21 /etc/nginx/sites-enabled/openhab
        sed -i "s|CERTPATH|${certpath}|g" /etc/nginx/sites-enabled/openhab
        sed -i "s|KEYPATH|${keypath}|g" /etc/nginx/sites-enabled/openhab
        uncomment 6,10 /etc/nginx/sites-enabled/openhab
        uncomment 15,17 /etc/nginx/sites-enabled/openhab
        comment 14 /etc/nginx/sites-enabled/openhab
      fi
    fi
    nginx -t && systemctl reload nginx.service || FAILED=true
    if [ "$FAILED" = true ]; then
      whiptail --title "Operation Failed!" --msgbox "$failtext" 15 80
    else
      whiptail --title "Operation Successful!" --msgbox "Setup successful. Please try entering $protocol://$domain in a browser to test your settings." 15 80
    fi
  else
    whiptail --title "Operation Canceled!" --msgbox "Setup was canceled, no changes were made." 15 80
  fi
}

## Function for installing Telldus Core service for Tellstick USB devices.
## The function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    tellstick_core_setup()
##

tellstick_core_setup() {
  FAILED=0
  introtext="This will install tellstick core services to enable support for USB connected Tellstick and Tellstick duo. For more details, have a look at http://developer.telldus.se/"
  failtext="Sadly there was a problem setting up tellstick core. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Success, please reboot your system to complete the installation.

Next, add your devices in /etc/tellstick.conf.
To detect device IDs use commanline tool: tdtool-improved --event
When devices are added restart telldusd.service by using: sudo systemctl restart telldusd
or just reboot the system.
"
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then echo "CANCELED"; return 0; fi
  fi
  echo -n "$(timestamp) [openHABian] Installing tellstick-core... "

  if is_aarch64 ; then
    dpkg --add-architecture armhf
  fi

  # Maybe add new repository to be able to install libconfuse1
  if is_xenial ; then
    echo 'APT::Default-Release "xenial";' > /etc/apt/apt.conf.d/01release
    echo "deb http://archive.ubuntu.com/ubuntu/ bionic universe" > /etc/apt/sources.list.d/ubuntu-artful.list
    cond_redirect apt-get update
    cond_redirect apt-get -y -t=bionic install libconfuse1
  fi
  if is_jessie ; then
    echo 'APT::Default-Release "jessie";' > /etc/apt/apt.conf.d/01release
    echo "deb http://deb.debian.org/debian stretch main" > /etc/apt/sources.list.d/debian-stretch.list
    cond_redirect apt-get update
    cond_redirect apt-get -y -t=stretch install libconfuse1
  fi
  # libconfuse1 is only available from old stretch repos, but currently still needed
  if is_buster ; then
    echo 'APT::Default-Release "buster";' > /etc/apt/apt.conf.d/01release
    if is_raspbian ; then
      echo "deb http://raspbian.raspberrypi.org/raspbian/ stretch main" > /etc/apt/sources.list.d/raspbian-stretch.list
    else
      echo "deb http://deb.debian.org/debian stretch main" > /etc/apt/sources.list.d/debian-stretch.list
    fi
    cond_redirect apt-get update || FAILED=1
    cond_redirect apt-get -y -t=stretch install libconfuse1 || FAILED=1
    if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
  fi

  cond_redirect wget -O - https://s3.eu-central-1.amazonaws.com/download.telldus.com/debian/telldus-public.key | apt-key add -
  echo "deb https://s3.eu-central-1.amazonaws.com/download.telldus.com unstable main" > /etc/apt/sources.list.d/telldus-unstable.list
  cond_redirect apt-get update
  cond_redirect apt-get -y install libjna-java telldus-core || FAILED=1
  if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi

  echo -n "$(timestamp) [openHABian] Setting up systemd service for telldusd... "
  cond_redirect cp "${BASEDIR}"/includes/tellstick-core/telldusd.service /lib/systemd/system/telldusd.service
  cond_redirect systemctl daemon-reload || FAILED=1
  cond_redirect systemctl enable telldusd || FAILED=1
  cond_redirect systemctl start telldusd.service || FAILED=1
  if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi

  echo -n "$(timestamp) [openHABian] Setting up tdtool-improved... "
  cond_redirect git clone https://github.com/EliasGabrielsson/tdtool-improved.py.git /opt/tdtool-improved
  cond_redirect chmod +x /opt/tdtool-improved/tdtool-improved.py
  cond_redirect ln -sf /opt/tdtool-improved/tdtool-improved.py /usr/bin/tdtool-improved
  echo "OK"

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}
