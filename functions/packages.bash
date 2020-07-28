#!/usr/bin/env bash

## Function for installing samba for remote access of folders.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    samba_setup()
##
samba_setup() {
  if ! [[ -x $(command -v samba) ]]; then
    echo -n "$(timestamp) [openHABian] Installing Samba... "
    if cond_redirect apt-get install --yes samba; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up Samba network shares... "
  cond_echo "\nCopying over custom 'smb.conf'... "
  cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/smb.conf /etc/samba/smb.conf
  cond_echo "\nWriting authentication data to openHABian default... "
  if ! smbpasswd -e "${username:-openhabian}" &> /dev/null; then
    # shellcheck disable=SC2154
    (echo "$userpw"; echo "$userpw") | smbpasswd -s -a "${username:-openhabian}" &> /dev/null
  fi
  echo "OK"

  echo -n "$(timestamp) [openHABian] Setting up Samba service... "
  cond_redirect systemctl -q daemon-reload &> /dev/null
  if ! cond_redirect systemctl enable smbd.service; then echo "FAILED (enable service)"; return 1; fi
  if cond_redirect systemctl restart smbd.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi
}

## Function for installing FireMotD which displays the system overview on login.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    firemotd_setup()
##
firemotd_setup() {
  local temp

  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  if ! dpkg -s 'bc' 'sysstat' 'jq' 'moreutils' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing FireMotD required packages (bc, sysstat, jq, moreutils)... "
    if cond_redirect apt-get install --yes bc sysstat jq moreutils; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Downloading FireMotD... "
  if cond_redirect wget -O "$temp" https://raw.githubusercontent.com/OutsideIT/FireMotD/master/FireMotD; then
     echo "OK"
  else
    echo "FAILED"
    rm -f "$temp"
    return 1
  fi

  echo -n "$(timestamp) [openHABian] Setting up FireMotD... "
  chmod 755 "$temp"
  if cond_redirect "$temp" -I; then echo "OK"; rm -f "$temp"; else echo "FAILED"; rm -f "$temp"; return 1; fi

  echo -n "$(timestamp) [openHABian] Generating FireMotD theme... "
  if cond_redirect FireMotD -G Gray; then echo "OK"; else echo "FAILED"; return 1; fi

  if ! grep -q "FireMotD" /home/"${username:-openhabian}"/.bash_profile; then
    echo -n "$(timestamp) [openHABian] Make FireMotD display on login... "
    if echo -e "\\necho\\nFireMotD --theme Gray \\necho" >> /home/"${username:-openhabian}"/.bash_profile; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up FireMotD apt updates count service... "
  cond_echo "\nMake FireMotD check for new updates every night... "
  echo "# FireMotD system updates check (randomly execute between 0:00:00 and 5:59:59)" > /etc/cron.d/firemotd
  echo "0 0 * * * root perl -e 'sleep int(rand(21600))' && /bin/bash /usr/local/bin/FireMotD -S &> /dev/null" >> /etc/cron.d/firemotd
  cond_echo "\nMake FireMotD check for new updates after using apt... "
  echo "DPkg::Post-Invoke { \"if [ -x /usr/local/bin/FireMotD ]; then echo -n 'Updating FireMotD available updates count ... '; /bin/bash /usr/local/bin/FireMotD --skiprepoupdate -S; echo ''; fi\"; };" > /etc/apt/apt.conf.d/15firemotd
  cond_echo "\nInitial FireMotD updates check"
  if cond_redirect FireMotD -S; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Function for installing and configuring Exim4 as MTA to relay mails via public services.
## This function can only be invoked in INTERACTIVE with userinterface.
##
##    exim_setup()
##
exim_setup() {
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] MTA setup must be run in interactive mode! Canceling MTA setup!"
    return 0
  fi

  local eximConfig
  local interfaces
  local introtext
  local relayPass
  local relayUser
  local smartHost
  local temp
  local logrotateFile

  if ! dpkg -s 'mailutils' 'exim4' 'dnsutils' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing MTA required packages (mailutils, exim4, dnsutils,)... "
    if cond_redirect apt-get install --yes exim4 dnsutils mailutils; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  eximConfig="/etc/exim4/passwd.client"
  interfaces="$(dig +short "$HOSTNAME" | tr '\n' ';');127.0.0.1;::1"
  introtext="We will guide you through the install of exim4 as the mail transfer agent on your system and configure it to relay mails through a public service such as Google gmail.\\n\\nThe values you need to enter after closing this window are documented here:\\n\\nhttps://github.com/openhab/openhabian/tree/master/docs/exim.md\\n\\nOpen that URL in a browser now. Your interface addresses are ${interfaces}.\\nYou will be able to repeat the whole installation if required by selecting the openHABian menu for MTA again."
  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo -n "$(timestamp) [openHABian] Beginning Mail Transfer Agent install and setup... "
  if (whiptail --title "Mail Transfer Agent installation" --yes-button "Begin" --no-button "Cancel" --yesno "$introtext" 17 80); then echo "OK"; else echo "CANCELED"; return 0; fi

  echo "$(timestamp) [openHABian] Reconfiguring exim4-config... "
  whiptail --title "exim4 Configuration" --msgbox "exim4-config is about to ask for information, please fill out each line." 7 80
  if dpkg-reconfigure exim4-config; then echo "OK"; else echo "CANCELED"; return 0; fi

  if ! smartHost=$(whiptail --title "Enter public mail service smarthost to relay your mails to" --inputbox "\\nEnter the list of smarthost(s) to use your account for" 9 80 "*.google.com" 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  if ! relayUser=$(whiptail --title "Enter your public service mail user" --inputbox "\\nEnter the mail username of the public service to relay all outgoing mail to $smartHost" 9 80 "yourname@gmail.com" 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  if ! relayPass=$(whiptail --title "Enter your public service mail password" --passwordbox "\\nEnter the password used to relay mail as ${relayUser}@${smartHost}" 9 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  logrotateFile=/etc/logrotate.d/exim4

  echo "$(timestamp) [openHABian] Creating MTA config... "
  if ! grep '^#' "$eximConfig" > "$temp"; then echo "FAILED (configuration)"; rm -f "$temp"; return 1; fi
  if ! echo "${smartHost}:${relayUser}:${relayPass}" >> "$temp"; then echo "FAILED (configuration)"; rm -f "$temp"; return 1; fi
  if ! cond_redirect cp "$temp" "$eximConfig"; then echo "FAILED (copy)"; rm -f "$temp"; return 1; fi
  cond_redirect rm -f "$temp"
  if cond_redirect chmod o-rwx "$eximConfig"; then echo "OK"; else echo "FAILED (permissions)"; return 1; fi
  for s in base paniclog; do
    if [[ -f "$logrotateFile-$s" ]]; then
      sed -i 's#Create 640 Debian-exim adm#Create 640 Debian-exim adm\n\tsu Debian-exim adm#g' "$logrotateFile-$s"
    fi
  done

  echo "$(timestamp) [openHABian] Adding to $relayUser email to system accounts... "
  if {
    echo "openhab: $relayUser"; echo "openhabian: $relayUser"
    echo "root: $relayUser"; echo "backup: $relayUser"
  } >> /etc/email-addresses; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Function for installing etckeeper, a git based /etc backup.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    etckeeper_setup()
##
etckeeper_setup() {
  if ! [[ -x $(command -v etckeeper) ]]; then
    echo -n "$(timestamp) [openHABian] Installing etckeeper (git based /etc backup)... "
    if cond_redirect apt-get install --yes etckeeper; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Configuring etckeeper (git based /etc backup)... "
  if ! cond_redirect sed -i 's/VCS="bzr"/\#VCS="bzr"/g' /etc/etckeeper/etckeeper.conf; then echo "FAILED"; return 1; fi
  if ! cond_redirect sed -i 's/\#VCS="git"/VCS="git"/g' /etc/etckeeper/etckeeper.conf; then echo "FAILED"; return 1; fi
  if cond_redirect bash -c "cd /etc && etckeeper init && git config user.email 'etckeeper@openHABian' && git config user.name 'openhabian' && git commit -m 'initial checkin' && git gc"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Function for installing Homegear, the Homematic CCU2 emulation software.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    homegear_setup()
##
homegear_setup() {
  local introtext
  local myOS
  local myRelease
  local successtext
  local disklistFile

  if ! [[ -x $(command -v lsb_release) ]]; then
    echo -n "$(timestamp) [openHABian] Installing Homegear required packages (lsb-release)... "
    if cond_redirect apt-get install --yes lsb-release; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  introtext="This will install Homegear, the Homematic CCU2 emulation software, using the latest stable release available from the official repository."
  myOS="$(lsb_release -si)"
  myRelease="$(lsb_release -sc)"
  successtext="Setup was successful.\\n\\nHomegear is now up and running. Next you might want to edit the configuration file '/etc/homegear/families/homematicbidcos.conf' or adopt devices through the homegear console, reachable by 'sudo homegear -r'.\\n\\nPlease read up on the homegear documentation for more details: https://doc.homegear.eu/data/homegear\\n\\nTo continue your integration in openHAB 2, please follow the instructions under: https://www.openhab.org/addons/bindings/homematic/"

  echo -n "$(timestamp) [openHABian] Beginning Homematic CCU2 emulation software Homegear install... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "Homegear installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 8 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  fi

  if ! add_keys "https://apt.homegear.eu/Release.key"; then return 1; fi

  echo "deb https://apt.homegear.eu/${myOS}/ ${myRelease}/" > /etc/apt/sources.list.d/homegear.list

  echo -n "$(timestamp) [openHABian] Installing Homegear... "
  if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
  if cond_redirect apt-get install --yes homegear homegear-homematicbidcos homegear-homematicwired homegear-max homegear-management; then echo "OK"; else echo "FAILED"; return 1; fi
  echo -n "$(timestamp) [openHABian] Setting up Homegear user account permisions... "
  if ! cond_redirect adduser "${username:-openhabian}" homegear; then echo "FAILED"; return 1; fi
  if cond_redirect adduser openhab homegear; then echo "OK"; else echo "FAILED"; return 1; fi
  echo -n "$(timestamp) [openHABian] Setting up Homegear service... "
  if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/homegear.service /etc/systemd/system/homegear.service; then echo "FAILED (copy service)"; return 1; fi
  if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/homegear-management.service /etc/systemd/system/homegear-management.service; then echo "FAILED (copy service)"; return 1; fi
  if running_in_docker; then sed -i '/RuntimeDirectory/d' /etc/systemd/system/homegear*; fi
  cond_redirect systemctl -q daemon-reload &> /dev/null
  if ! cond_redirect systemctl enable --now homegear.service homegear-management.service; then echo "FAILED (enable service)"; return 1; fi
  disklistFile=/etc/amanda/openhab-dir/disklist
  if [[ -f "$disklistFile" ]]; then
    sed -i '/homegear/d' $disklistFile
    grep -E '/var/lib/openhab2[[:space:]]' $disklistFile | sed -e 's#openhab2#homegear#g' > ${disklistFile}.tmp
    cond_redirect cat ${disklistFile}.tmp >> $disklistFile && rm -f ${disklistFile}.tmp
  fi
  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 14 80
  fi
}

## Function for installing MQTT Eclipse Mosquitto through the official repository.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    mqtt_setup()
##
mqtt_setup() {
  local introtext
  local mqttpasswd
  local mqttuser
  local questiontext
  local successtext

  introtext="The MQTT broker Eclipse Mosquitto will be installed through the official repository, as desribed in: https://mosquitto.org/2013/01/mosquitto-debian-repository\\n\\nAdditionally you can activate username:password authentication.\\n\\nHEADS UP: Only proceed when you are aware that this will be in conflict with use of the MQTTv2 binding which will also be using the same ports."
  mqttuser="openhabian"
  questiontext="\\nDo you want to secure your MQTT broker by a username:password combination? Every client will need to provide these upon connection.\\n\\nUsername will be '$mqttuser', please provide a password (consisting of ASCII printable characters except space). Leave blank for no authentication, run setup again to change."
  successtext="Setup was successful.\\n\\nEclipse Mosquitto is now up and running in the background. You should be able to make a first connection.\\n\\nTo continue your integration in openHAB, please follow the instructions under: https://www.openhab.org/addons/bindings/mqtt/"

  echo -n "$(timestamp) [openHABian] Beginning the MQTT broker Eclipse Mosquitto installation... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "MQTT installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 14 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  fi

  if ! dpkg -s 'mosquitto' 'mosquitto-clients' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing MQTT... "
    if cond_redirect apt-get install --yes mosquitto mosquitto-clients; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Configuring MQTT... "
  if [[ -n $INTERACTIVE ]]; then
    if ! mqttpasswd=$(whiptail --title "MQTT Authentication?" --passwordbox "$questiontext" 14 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  fi
  if [[ -n $mqttpasswd ]]; then
    if ! grep -qs password_file /etc/mosquitto/passwd /etc/mosquitto/mosquitto.conf; then
      echo -e "\\npassword_file /etc/mosquitto/passwd\\nallow_anonymous false\\n" >> /etc/mosquitto/mosquitto.conf
    fi
    echo -n "" > /etc/mosquitto/passwd
    if cond_redirect mosquitto_passwd -b /etc/mosquitto/passwd "$mqttuser" "$mqttpasswd"; then echo "OK"; else echo "FAILED"; return 1; fi
  else
    if ! cond_redirect sed -i "/password_file/d" /etc/mosquitto/mosquitto.conf; then echo "FAILED"; return 1; fi
    if ! cond_redirect sed -i "/allow_anonymous/d" /etc/mosquitto/mosquitto.conf; then echo "FAILED"; return 1; fi
    if cond_redirect rm -f /etc/mosquitto/passwd; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up MQTT service... "
  cond_redirect systemctl -q daemon-reload &> /dev/null
  if ! cond_redirect systemctl enable mosquitto.service; then echo "FAILED (enable service)"; return 1; fi
  if cond_redirect systemctl restart mosquitto.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 13 80
  fi
}

## Function for installing FIND to allow for indoor localization of WiFi devices.
## This function can only be invoked in INTERACTIVE with userinterface.
##
##    find_setup()
##
find_setup() {
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] FIND setup must be run in interactive mode! Canceling FIND setup!"
    return 0
  fi
  if [[ -f /etc/systemd/system/find3server.service ]]; then
    echo "$(timestamp) [openHABian] FIND cannot be used with FIND3! Canceling FIND setup!"
    return 0
  fi

  local brokertext
  local FINDADMIN
  local FINDADMINPASS
  local findArch
  local findClient
  local findDist
  local findPass1
  local findPass2
  local findRelease
  local introtext
  local mqttmissingtext
  local mqttpasswd
  local MQTTPORT
  local MQTTSERVER
  local successtext
  local temp

  if ! dpkg -s 'libsvm-tools' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing FIND required packages... "
    if cond_redirect apt-get install --yes libsvm-tools; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  brokertext="You've chosen to work with an external MQTT broker.\\n\\nPlease be aware that you might need to add authentication credentials. You can do so after the installation.\\n\\nConsult with the FIND documentation or the openHAB community for details."
  if is_arm; then
    findArch="arm"
  else
    findArch="amd64"
  fi
  findRelease="https://github.com/schollz/find/releases/download/v2.4.1/find_2.4.1_linux_${findArch}.zip"
  findClient="https://github.com/schollz/find/releases/download/v0.6client/fingerprint_0.6_linux_${findArch}.zip"
  findDist="/var/lib/findserver"
  introtext="Install and setup the FIND server system to allow for indoor localization of WiFi devices.\\n\\nPlease note that FIND will run together with an app that is only available on Android.\\n\\nThere is no iOS app available, for more information see: https://www.internalpositioning.com/faq/#can-i-use-an-iphone"
  mqttmissingtext="FIND requires an MQTT broker to run, but Mosquitto could not be found on this system.\\n\\nYou can configure FIND to use any existing MQTT broker (in the next step) or you can go back and install Mosquitto from the openHABian menu.\\n\\nDo you want to continue with the FIND installation?"
  mqttpasswd="/etc/mosquitto/passwd"
  successtext="FIND setup was successful.\\n\\nSettings can be configured in '/etc/default/findserver'. Be sure to restart the service after.\\n\\nYou can obtain the FIND app for Android through the Play Store. There is no iOS app available, for more information see: https://www.internalpositioning.com/faq/#can-i-use-an-iphone\\n\\nCheck out your FIND server's dashboard at: http://${HOSTNAME}:8003\\n\\nFor further information: https://www.internalpositioning.com"
  temp="$(mktemp -d "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo "$(timestamp) [openHABian] Beginning setup of FIND, the Framework for Internal Navigation and Discovery... "

  if [ ! -f "/etc/mosquitto/mosquitto.conf" ]; then
    if ! (whiptail --defaultno --title "Mosquitto not installed, continue?" --yes-button "Continue" --no-button "Cancel" --yesno "$mqttmissingtext" 13 80); then echo "CANCELED"; return 0; fi
  fi

  if (whiptail --title "FIND installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 14 80); then echo "OK"; else echo "CANCELED"; return 0; fi

  echo -n "$(timestamp) [openHABian] Configuring FIND... "
  if ! MQTTSERVER=$(whiptail --title "FIND Setup" --inputbox "\\nPlease enter the hostname of the device your MQTT broker is running on:" 9 80 localhost 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  if [[ $MQTTSERVER != "localhost" ]]; then
    if ! (whiptail --title "MQTT Broker Notice" --yes-button "Continue" --no-button "Cancel" --yesno "$brokertext" 12 80); then echo "CANCELED"; return 0; fi
  fi
  if ! MQTTPORT=$(whiptail --title "FIND Setup" --inputbox "\\nPlease enter the port number the MQTT broker is listening on:" 9 80 1883 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
  if [[ -f $mqttpasswd ]]; then
    if ! FINDADMIN=$(whiptail --title "findserver MQTT Setup" --inputbox "\\nEnter a username for FIND to connect with on your MQTT broker:" 9 80 find 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
    while [[ -z $FINDADMINPASS ]]; do
      if ! findPass1=$(whiptail --title "findserver MQTT Setup" --passwordbox "\\nEnter a password for the FIND user on your MQTT broker:" 9 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
      if ! findPass2=$(whiptail --title "findserver MQTT Setup" --passwordbox "\\nPlease confirm the password for the FIND user on your MQTT broker:" 9 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
      if [[ $findPass1 == "$findPass2" ]] && [[ ${#findPass1} -ge 8 ]] && [[ ${#findPass2} -ge 8 ]]; then
        FINDADMINPASS="$findPass1"
      else
        whiptail --title "findserver MQTT Setup" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
      fi
    done
    if ! cond_redirect mosquitto_passwd -b $mqttpasswd "$FINDADMIN" "$FINDADMINPASS"; then echo "FAILED (mosquitto password)"; return 1; fi
    if ! cond_redirect systemctl restart mosquitto.service; then echo "FAILED (restart service)"; return 1; fi
  fi
  echo "OK"

  echo -n "$(timestamp) [openHABian] Installing FIND... "
  if ! cond_redirect mkdir -p "$findDist"; then echo "FAILED (create directory)"; return 1; fi
  if ! cond_redirect wget -qO "${temp}/find.zip" "$findRelease"; then echo "FAILED (fetch FIND)"; return 1; fi
  if ! cond_redirect wget -qO "${temp}/client.zip" "$findClient"; then echo "FAILED (fetch client)"; return 1; fi
  if ! cond_redirect unzip -qo "${temp}/find.zip" -d "$findDist"; then echo "FAILED (unzip FIND)"; return 1; fi
  if ! cond_redirect unzip -qo "${temp}/client.zip" fingerprint -d "$findDist"; then echo "FAILED (unzip client)"; return 1; fi
  if ! cond_redirect ln -sf "$findDist"/findserver /usr/sbin/findserver; then echo "FAILED (link findserver)"; return 1; fi
  if ! cond_redirect ln -sf "$findDist"/fingerprint /usr/sbin/fingerprint; then echo "FAILED (link fingerprint)"; return 1; fi
  if cond_redirect rm -rf "$temp"; then echo "OK"; else echo "FAILED"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up FIND service... "
  if ! (sed -e 's|%MQTTSERVER|'"${MQTTSERVER}"'|g; s|%MQTTPORT|'"${MQTTPORT}"'|g; s|%FINDADMINPASS|'"${FINDADMINPASS}"'|g; s|%FINDADMIN|'"${FINDADMIN}"'|g; s|%FINDPORT|8003|g; s|%FINDSERVER|localhost|g' "${BASEDIR:-/opt/openhabian}"/includes/findserver.service > /etc/systemd/system/findserver.service); then echo "FAILED (service file creation)"; return 1; fi
  if ! cond_redirect chmod 644 /etc/systemd/system/findserver.service; then echo "FAILED (permissions)"; return 1; fi
  if ! (sed -e 's|%MQTTSERVER|'"${MQTTSERVER}"'|g; s|%MQTTPORT|'"${MQTTPORT}"'|g; s|%FINDADMINPASS|'"${FINDADMINPASS}"'|g; s|%FINDADMIN|'"${FINDADMIN}"'|g; s|%FINDPORT|8003|g; s|%FINDSERVER|localhost|g' "${BASEDIR:-/opt/openhabian}"/includes/findserver > /etc/default/findserver); then echo "FAILED (service configuration creation)"; return 1; fi
  cond_redirect systemctl -q daemon-reload &> /dev/null
  if ! cond_redirect systemctl enable findserver.service; then echo "FAILED (enable service)"; return 1; fi
  if cond_redirect systemctl restart findserver.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi

  whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80

  if dpkg -s 'openhab2' &> /dev/null; then
    dashboard_add_tile find
  fi
}

## Function for installing kndx as your EIB/KNX IP gateway and router to support your KNX bus system.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    knxd_setup()
##
knxd_setup() {
  local introtext
  local successtext
  local temp

  introtext="This will install and setup kndx (successor to eibd) as your EIB/KNX IP gateway and router to support your KNX bus system.\\n\\nThis routine was provided by 'Michels Tech Blog': https://bit.ly/3dzeoKh"
  successtext="Setup was successful.\\n\\nPlease edit '/etc/default/knxd' to meet your interface requirements. For further information on knxd options, please type 'knxd --help'\\n\\nFurther details can be found under: https://bit.ly/3dzeoKh\\n\\nIntegration into openHAB 2 is described here: https://github.com/openhab/openhab/wiki/KNX-Binding"
  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo -n "$(timestamp) [openHABian] Beginning setup of EIB/KNX IP Gateway and Router with knxd (https://bit.ly/3dzeoKh)... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "knxd installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 10 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  echo -n "$(timestamp) [openHABian] Installing knxd... "
  # TODO: serve file from the repository
  if ! cond_redirect wget -O "$temp" https://michlstechblog.info/blog/download/electronic/install_knxd_systemd.sh; then echo "FAILED (fetch installer)"; return 1; fi
  # NOTE: install_knxd_systemd.sh currently does not give proper exit status for errors, so installer claims success...
  if cond_redirect bash "$temp"; then rm -f "$temp"; echo "OK (Reboot needed)"; else echo "FAILED (install)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
}

## Function for installing owserver to support 1wire functionality.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    1wire_setup()
##
1wire_setup() {
  local introtext
  local successtext

  introtext="This will install owserver to support 1wire functionality in general.\\n\\nUse the ow-shell and usbutils tools to check USB (lsusb) and 1wire function (owdir, owread).\\n\\nFor more details, have a look at https://owfs.org"
  successtext="Setup was successful.\\n\\nNext, please configure your system in /etc/owfs.conf.\\nUse # to comment/deactivate a line. All you should have to change is the following:\\nDeactivate\\n  server: FAKE = DS18S20,DS2405\\nand activate one of these most common options (depending on your device):\\n  #server: usb = all\\n  #server: device = /dev/ttyS1\\n  #server: device = /dev/ttyUSB0"

  echo -n "$(timestamp) [openHABian] Beginning setup of owserver (1wire)... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "1wire installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 12 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  if ! dpkg -s 'owserver' 'ow-shell' 'usbutils' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing owserver (1wire)... "
    if cond_redirect apt-get install --yes owserver ow-shell usbutils; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 17 80
  fi
}

## Function for installing miflora-mqtt-daemon - The Xiaomi Mi Flora Plant Sensor MQTT Client/Daemon.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    miflora_setup()
##
miflora_setup() {
  if ! is_pizerow && ! is_pithree && ! is_pithreeplus && ! is_pifour; then
    echo "$(timestamp) [openHABian] Beginning setup of miflora-mqtt-daemon... SKIPPED (no Bluetooth support)"
    return 0
  fi

  local introtext
  local mifloraDir
  local successtext

  if ! dpkg -s 'git' 'python3' 'python3-pip' 'bluetooth' 'bluez' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing miflora-mqtt-daemon required packages... "
    if cond_redirect apt-get install --yes git python3 python3-pip bluetooth bluez; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  introtext="[CURRENTLY BROKEN] This will install or update miflora-mqtt-daemon - The Xiaomi Mi Flora Plant Sensor MQTT Client/Daemon.\\n\\nFor further details see:\\nhttps://github.com/ThomDietrich/miflora-mqtt-daemon"
  mifloraDir="/opt/miflora-mqtt-daemon"
  successtext="Setup was successful.\\n\\nThe Daemon was installed and the systemd service was set up just as described in it's README. Please add your MQTT broker settings in '$mifloraDir/config.ini' and add your Mi Flora sensors. After that be sure to restart the daemon to reload it's configuration.\\n\\nAll details can be found under: https://github.com/ThomDietrich/miflora-mqtt-daemon\\nThe article also contains instructions regarding openHAB integration."

  echo -n "$(timestamp) [openHABian] Beginning setup of miflora-mqtt-daemon... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "miflora-mqtt-daemon installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 11 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  echo -n "$(timestamp) [openHABian] Setting up miflora-mqtt-daemon... "
  if ! [[ -d $mifloraDir ]]; then
    cond_echo "\nFresh Installation... "
    if ! cond_redirect git clone https://github.com/ThomDietrich/miflora-mqtt-daemon.git $mifloraDir; then echo "FAILED (git clone)"; return 1; fi
  else
    cond_echo "\nUpdate... "
    if ! cond_redirect update_git_repo "$mifloraDir" "master"; then echo "FAILED (update git repo)"; return 1; fi
  fi
  if cond_redirect cp "$mifloraDir"/config.{ini.dist,ini}; then echo "OK"; else echo "FAILED (copy files)"; return 1; fi

  cond_echo "Filesystem permissions corrections... "
  if ! cond_redirect chown -R "openhab:${username:-openhabian}" "$mifloraDir"; then echo "FAILED (permissions)"; return 1; fi
  if ! cond_redirect chmod -R ug+wX "$mifloraDir"; then echo "FAILED (permissons)"; return 1; fi

  cond_echo "Installing required python packages"
  if ! cond_redirect pip3 install -r "$mifloraDir"/requirements.txt; then echo "OK"; else echo "FAILED (python packages)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up miflora-mqtt-daemon service... "
  if ! cond_redirect install -m 644 "$mifloraDir"/template.service /etc/systemd/system/miflora.service; then echo "FAILED (copy service)"; return 1; fi
  cond_redirect systemctl -q daemon-reload &> /dev/null
  if ! cond_redirect systemctl enable miflora.service; then echo "FAILED (enable service)"; return 1; fi
  if cond_redirect systemctl restart miflora.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi

  if grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt" /boot/config.txt; then
    cond_echo "Warning! The internal RPi Bluetooth module is disabled on your system. You need to enable it before the daemon may use it."
  fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 16 80
  fi
}

## Function for installing nginx to allow for secure interaction with openHAB over the network.
## This function can only be invoked in INTERACTIVE with userinterface.
##
##    nginx_setup()
##
nginx_setup() {
  if [[ -z $INTERACTIVE ]]; then
    echo "$(timestamp) [openHABian] nginx setup must be run in interactive mode! Canceling nginx setup!"
    return 0
  fi

  local auth
  local authtext
  local domain
  local domainIP
  local domaintext
  local httpstext
  local introtext
  local nginxPass
  local nginxPass1
  local nginxPass2
  local nginxUsername
  local portwarning
  local protocol
  local pubIP
  local secure
  local validDomain
  local logrotateFile

  if ! [[ -x $(command -v dig) ]]; then
    echo -n "$(timestamp) [openHABian] Installing nginx required packages (dnsutils)... "
    if cond_redirect apt-get install --yes dnsutils; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  auth="false"
  domaintext="\\nIf you have a registered domain enter it now, if you have a static public IP enter \"IP\", otherwise leave blank:"
  introtext="This will enable you to access the openHAB interface through the normal HTTP/HTTPS ports and optionally secure it with username/password and/or an SSL certificate."
  secure="false"
  validDomain="false"
  logrotateFile=/etc/logrotate.d/nginx

  function comment {
    if ! sed -e "/[[:space:]]$1/ s/^#*/#/g" -i "$2"; then echo "FAILED (comment)"; return 1; fi
  }
  function uncomment {
    if ! sed -e "/$1/s/^$1//g" -i "$2"; then echo "FAILED (uncomment)"; return 1; fi
  }

  echo -n "$(timestamp) [openHABian] Beginning setup of nginx as reverse proxy with authentication... "
  if (whiptail --title "nginx installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 9 80); then echo "OK"; else echo "CANCELED"; return 0; fi

  echo "$(timestamp) [openHABian] Configuring nginx authentication options... "
  if (whiptail --title "Authentication Setup" --yesno "Would you like to secure your openHAB interface with username and password?" 7 80); then
    if nginxUsername=$(whiptail --title "Authentication Setup" --inputbox "\\nEnter a username to sign into openHAB:" 9 80 openhab 3>&1 1>&2 2>&3); then
      while [[ -z $nginxPass ]]; do
        if ! nginxPass1=$(whiptail --title "Authentication Setup" --passwordbox "\\nEnter a password for ${nginxUsername}:" 9 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
        if ! nginxPass2=$(whiptail --title "Authentication Setup" --passwordbox "\\nPlease confirm the password:" 9 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
        if [[ $nginxPass1 == "$nginxPass2" ]] && [[ ${#nginxPass1} -ge 8 ]] && [[ ${#nginxPass2} -ge 8 ]]; then
          nginxPass="$nginxPass1"
        else
          whiptail --title "Authentication Setup" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
        fi
      done
    else
      echo "CANCELED"
      return 0
    fi
    auth="true"
  fi

  if (whiptail --title "Secure Certificate Setup" --yesno "Would you like to secure your openHAB interface with HTTPS?" 7 80); then secure="true"; echo "OK"; else echo "CANCELED"; return 0; fi

  if [[ $auth == "true" ]]; then
    authtext="Authentication Enabled\\n- Username: $nginxUsername"
  else
    authtext="Authentication Disabled"
  fi

  if [[ $secure == "true" ]]; then
    httpstext="Proxy will be secured by HTTPS"
    protocol="HTTPS"
    portwarning="Important! Before you continue, please make sure that port 80 (HTTP) of this machine is reachable from the internet (portforwarding, etc.). Otherwise the certbot connection test will fail.\\n\\n"
  else
    httpstext="Proxy will not be secured by HTTPS"
    protocol="HTTP"
    portwarning=""
  fi

  echo "$(timestamp) [openHABian] Configuring nginx network options... "
  cond_echo "Obtaining public IP address... "
  if ! pubIP="$(get_public_ip)"; then echo "FAILED (public ip)"; return 1; fi

  cond_echo "Configuring domain settings... "
  if ! domain="$(whiptail --title "Domain Setup" --inputbox "$domaintext" 10 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi

  while [[ $validDomain == "false" ]] && [[ -n $domain ]] && [[ $domain != "IP" ]]; do
    cond_echo "Obtaining domain IP address... "
    if domainIP="$(dig -4 +short "$domain" @resolver1.opendns.com | tail -1)"; then echo "$domainIP"; else echo "FAILED"; return 1; fi
    if [[ $pubIP = "$domainIP" ]]; then
      validDomain="true"
      cond_echo "Public and domain IP address match"
    else
      cond_echo "Public and domain IP address mismatch!"
      if ! domain=$(whiptail --title "Domain Setup" --inputbox "\\nDomain does not resolve to your public IP address. Please enter a valid domain.\\n\\n$domaintext" 14 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
    fi
  done

  if [[ $validDomain == "false" ]]; then
    if [[ $domain == "IP" ]]; then
      cond_echo "Setting domain to static public IP address $pubIP"
      domain="$pubIP"
    else
      cond_echo "Setting domain to localhost"
      domain="localhost"
    fi
    validDomain="true"
  fi

  confirmtext="The following settings have been chosen:\\n\\n- $authtext\\n- $httpstext\\n- Domain: $domain (Public IP Address: $pubIP)\\n\\nYou will be able to connect to openHAB on the default $protocol port.\\n\\n${portwarning}Do you wish to continue and setup an nginx server now?"

  if ! (whiptail --title "Confirmation" --yesno "$confirmtext" 20 80); then echo "CANCELED"; return 0; fi
  echo -n "$(timestamp) [openHABian] Installing nginx... "
  if cond_redirect apt-get install --yes nginx; then echo "OK"; else echo "FAILED"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up nginx configuration... "
  if ! cond_redirect rm -rf /etc/nginx/sites-enabled/default; then echo "FAILED (remove default)"; return 1; fi
  if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/nginx.conf /etc/nginx/sites-enabled/openhab; then echo "FAILED (copy configuration)"; return 1; fi
  if cond_redirect sed -i 's|DOMAINNAME|'"${domain}"'|g' /etc/nginx/sites-enabled/openhab; then echo "OK"; else echo "FAILED (set domain name)"; return 1; fi

  if [[ $auth == "true" ]]; then
    cond_echo "Setting up nginx password options..."
    echo -n "$(timestamp) [openHABian] Installing nginx password utilities... "
    if cond_redirect apt-get install --yes apache2-utils; then echo "OK"; else echo "FAILED"; return 1; fi
    if cond_redirect htpasswd -b -c /etc/nginx/.htpasswd "$nginxUsername" "$nginxPass"; then echo "OK"; else echo "FAILED (password file)"; return 1; fi
    uncomment "#AUTH" /etc/nginx/sites-enabled/openhab
  fi

  if [[ $secure == "true" ]]; then
    cond_echo "Setting up nginx security options..."
    if [[ $validDomain == "true" ]]; then
      echo -n "$(timestamp) [openHABian] Installing certbot... "
      if is_ubuntu; then
        if ! dpkg -s 'software-properties-common' &> /dev/null; then
          if ! cond_redirect apt-get install --yes software-properties-common; then echo "FAILED (Ubuntu prerequsites)"; return 1; fi
        fi
        if ! cond_redirect add-apt-repository universe; then echo "FAILED (add universe repo)"; return 1; fi
        if ! add-apt-repository ppa:certbot/certbot; then echo "FAILED (add certbot repo)"; return 1; fi
        if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      fi
      if cond_redirect apt-get install --yes certbot python3-certbot-nginx; then echo "OK"; else echo "FAILED"; return 1; fi

      echo -n "$(timestamp) [openHABian] Configuring certbot... "
      mkdir -p /var/www/"$domain"
      uncomment "#WEBROOT" /etc/nginx/sites-enabled/openhab
      if ! nginx -t; then echo "FAILED (nginx configuration test)"; return 1; fi
      if ! cond_redirect systemctl -q reload nginx.service &> /dev/null; then echo "FAILED (nginx reload)"; return 1; fi
      if cond_redirect certbot certonly --webroot -w /var/www/"$domain" -d "$domain"; then echo "OK"; else echo "FAILED"; return 1; fi
      certpath="/etc/letsencrypt/live/${domain}/fullchain.pem"
      keypath="/etc/letsencrypt/live/${domain}/privkey.pem"
    else
      echo -n "$(timestamp) [openHABian] Configuring openSSL... "
      mkdir -p /etc/ssl/certs
      certpath="/etc/ssl/certs/openhab.crt"
      keypath="/etc/ssl/certs/openhab.key"
      whiptail --title "openSSL Key Generation" --msgbox "openSSL is about to ask for information in the command line, please fill out each line." 8 80
      if ! openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout $keypath -out $certpath; then echo "FAILED (openSSL configuration)"; return 1; fi
    fi
    uncomment "#CERT" /etc/nginx/sites-enabled/openhab
    if ! cond_redirect sed -i "s|CERTPATH|${certpath}|g" /etc/nginx/sites-enabled/openhab; then echo "FAILED (certpath config)"; return 1; fi
    if ! cond_redirect sed -i "s|KEYPATH|${keypath}|g" /etc/nginx/sites-enabled/openhab; then echo "FAILED (keypath config)"; return 1; fi
    uncomment "#REDIR" /etc/nginx/sites-enabled/openhab
    comment "listen" /etc/nginx/sites-enabled/openhab
    uncomment "#SSL" /etc/nginx/sites-enabled/openhab
  fi

  if [[ -f "$logrotateFile" ]]; then
    sed -i 's#daily#daily\n\tsu www-data adm#g' "$logrotateFile"
  fi
  if ! nginx -t; then echo "FAILED (nginx configuration test)"; return 1; fi
  if ! cond_redirect systemctl restart nginx.service; then echo "FAILED (nginx restart)"; return 1; fi

  whiptail --title "Operation Successful!" --msgbox "Setup successful. Please try entering $protocol://$domain in a browser to test your settings." 8 80
}

## Function for installing Telldus Core service for Tellstick USB devices.
## The function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    telldus_core_setup()
##
telldus_core_setup() {
  local introtext
  local successtext
  local telldusDir

  introtext="This will install Telldus Core services to enable support for USB devices connected Tellstick and Tellstick duo."
  successtext="Success, please reboot your system to complete the installation.\\n\\nNext, add your devices in /etc/tellstick.conf.\\n\\nTo detect device IDs issue the command:\\n- tdtool-improved --event\\n\\nWhen devices are added, restart telldusd.service by rebooting the system or using:\\n- sudo systemctl restart telldusd.service"
  telldusDir="/opt/tdtool-improved"

  echo -n "$(timestamp) [openHABian] Beginning setup of Telldus Core... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "Telldus Core installation?" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 8 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  if is_arm; then
    dpkg --add-architecture armhf
  fi

  # Maybe add new repository to be able to install libconfuse1
  # libconfuse1 is only available from old stretch repos, but currently still needed
  if is_buster; then
    echo -n "$(timestamp) [openHABian] Adding libconfuse1 repository to apt... "
    echo 'APT::Default-Release "buster";' > /etc/apt/apt.conf.d/01release
    if is_raspbian ; then
      echo "deb http://raspbian.raspberrypi.org/raspbian/ stretch main" > /etc/apt/sources.list.d/raspbian-stretch.list
    else
      echo "deb http://deb.debian.org/debian stretch main" > /etc/apt/sources.list.d/debian-stretch.list
    fi
    echo "OK"
  fi
  echo -n "$(timestamp) [openHABian] Installing libconfuse1... "
  if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
  if cond_redirect apt-get install --yes --target-release "stretch" libconfuse1; then echo "OK"; else echo "FAILED"; return 1; fi

  if ! add_keys "https://s3.eu-central-1.amazonaws.com/download.telldus.com/debian/telldus-public.key"; then return 1; fi

  echo -n "$(timestamp) [openHABian] Adding telldus repository to apt... "
  echo "deb https://s3.eu-central-1.amazonaws.com/download.telldus.com unstable main" > /etc/apt/sources.list.d/telldus-unstable.list
  if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Installing telldus-core... "
  if cond_redirect apt-get install --yes libjna-java telldus-core; then echo "OK"; else echo "FAILED"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up telldus-core service... "
  if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/telldusd.service /etc/systemd/system/telldusd.service; then echo "FAILED (copy service)"; return 1; fi
  cond_redirect systemctl -q daemon-reload &> /dev/null
  if ! cond_redirect systemctl enable telldusd.service; then echo "FAILED (enable service)"; return 1; fi
  if cond_redirect systemctl restart telldusd.service; then echo "OK"; else echo "FAILED (restart service)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up tdtool-improved... "
  if ! [[ -d $telldusDir ]]; then
    cond_echo "\nFresh Installation... "
    if ! cond_redirect git clone https://github.com/EliasGabrielsson/tdtool-improved.py.git $telldusDir; then echo "FAILED (git clone)"; return 1; fi
  else
    cond_echo "\nUpdate... "
    if ! cond_redirect update_git_repo "$telldusDir" "master"; then echo "FAILED (update git repo)"; return 1; fi
  fi
  cond_redirect chmod +x /opt/tdtool-improved/tdtool-improved.py
  if cond_redirect ln -sf /opt/tdtool-improved/tdtool-improved.py /usr/bin/tdtool-improved; then echo "OK"; else echo "FAILED (link)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 16 80
  fi
}
