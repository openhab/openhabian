#!/usr/bin/env bash

# shellcheck disable=SC2120,SC2154

## Function for installing samba for remote access of folders.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    samba_setup()
##
samba_setup() {
  local serviceFile="/lib/systemd/system/smbd.service"

  if ! samba_is_installed; then
    echo -n "$(timestamp) [openHABian] Installing Samba... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" samba; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up Samba network shares... "
  cond_echo "\\nCopying over custom 'smb.conf'... "
  cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/smb.conf /etc/samba/smb.conf
  cond_echo "\\nWriting authentication data to openHABian default... "
  if ! smbpasswd -e "${username:-openhabian}" &> /dev/null; then
    (echo "${userpw:-openhabian}"; echo "${userpw:-openhabian}") | smbpasswd -s -a "${username:-openhabian}" &> /dev/null
  fi
  echo "OK"

  echo -n "$(timestamp) [openHABian] Setting up Samba service... "
  if ! cond_redirect mkdir -p /var/log/samba /run/samba; then echo "FAILED (create directories)"; return 1; fi
  if ! cond_redirect sed -i -E -e '/PIDFile/d; /NotifyAccess/ a PIDFile=smbd.pid\nRuntimeDirectory=samba' "$serviceFile"; then echo "FAILED"; return 1; fi
  if ! cond_redirect zram_dependency install nmbd smbd; then return 1; fi
  if cond_redirect systemctl enable --now smbd.service &> /dev/null; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi
}

## Function for downloading FireMotD to current system
##
##    firemotd_download(String prefix)
##
firemotd_download() {
  echo -n "$(timestamp) [openHABian] Downloading FireMotD... "
  if ! [[ -d "${1}/FireMotD" ]]; then
    cond_echo "\\nFresh Installation... "
    if cond_redirect git clone https://github.com/OutsideIT/FireMotD.git "${1}/FireMotD"; then echo "OK"; else echo "FAILED (git clone)"; return 1; fi
  else
    cond_echo "\\nUpdate... "
    if cond_redirect update_git_repo "${1}/FireMotD" "master"; then echo "OK"; else echo "FAILED (update git repo)"; return 1; fi
  fi
}

## Function for installing FireMotD which displays the system overview on login.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    firemotd_setup()
##
firemotd_setup() {
  if running_in_docker || running_on_github; then return 0; fi

  local firemotdDir="/opt/FireMotD"

  if ! dpkg -s 'bc' 'sysstat' 'jq' 'moreutils' 'make' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing FireMotD required packages (bc, sysstat, jq, moreutils)... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" bc sysstat jq moreutils make; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  if ! firemotd_download /opt; then
    if [[ -z $OFFLINE ]]; then
       return 1
    fi
  fi

  echo -n "$(timestamp) [openHABian] Installing FireMotD... "
  if ! cond_redirect make --always-make --directory="$firemotdDir" install; then echo "FAILED (install FireMotD)"; return 1; fi
  if cond_redirect make --always-make --directory="$firemotdDir" bash_completion; then echo "OK"; else echo "FAILED (install FireMotD bash completion)"; return 1; fi

  echo -n "$(timestamp) [openHABian] Generating FireMotD theme... "
  if ! cond_redirect FireMotD -S -d -D all; then echo "FAILED (generate FireMotD)"; return 1; fi
  if cond_redirect FireMotD -G Gray; then echo "OK"; else echo "FAILED"; return 1; fi

  if ! grep -qs "FireMotD" /home/"${username:-openhabian}"/.bash_profile; then
    echo -n "$(timestamp) [openHABian] Make FireMotD display on login... "
    if echo -e "\\necho\\nFireMotD --theme Gray \\necho" >> /home/"${username:-openhabian}"/.bash_profile; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up FireMotD apt updates count service... "
  cond_echo "\\nMake FireMotD check for new updates every night... "
  if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/firemotd/firemotd.* /etc/systemd/system/; then echo "FAILED (install service/timer)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect systemctl enable --now firemotd.timer &> /dev/null; then echo "FAILED (service enable)"; return 1; fi
  cond_echo "\\nMake FireMotD check for new updates after using apt... "
  if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/firemotd/15firemotd /etc/apt/apt.conf.d/; then echo "FAILED (apt configuration)"; return 1; fi
  cond_echo "\\nInitial FireMotD updates check"
  if cond_redirect FireMotD -S; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Function for installing and configuring Exim4 as MTA to relay mails via public services.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED with configuration provided.
##
##    exim_setup()
##
exim_setup() {
  if [[ -n $UNATTENDED ]] && [[ -z $relayuser ]]; then
    echo "$(timestamp) [openHABian] Beginning Mail Transfer Agent setup... SKIPPED (no configuration provided)"
    return 0
  fi

  local updateEximTemplate="${BASEDIR:-/opt/openhabian}/includes/update-exim4.conf.conf-template"
  local eximConfig="/etc/exim4/update-exim4.conf.conf"
  local eximPasswd="/etc/exim4/passwd.client"
  local interfaces
  local relaynets
  local addresses="/etc/email-addresses"
  local temp
  local logrotateFile="/etc/logrotate.d/exim4"
  local introText

  if ! exim_is_installed; then
    echo -n "$(timestamp) [openHABian] Installing MTA required packages (mailutils, exim4, dnsutils)... "
    if ! cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" exim4 mailutils; then echo "FAILED"; return 1; fi
  fi
  if cond_redirect install_dnsutils; then echo "OK"; else echo "FAILED"; return 1; fi

  interfaces="$(dig +short "$hostname" | tr '\n' ';')127.0.0.1;::1"
  relaynets="$(dig +short "$hostname" | cut -d'.' -f1-3).0/24"
  introText="We will guide you through the install of exim4 as the mail transfer agent on your system and configure it to relay mails through a public service such as Google gmail.\\n\\nThe values you need to enter after closing this window are documented here:\\n\\nhttps://www.openhab.org/docs/installation/openhabian-exim.html\\n\\nOpen that URL in a browser now. Your interface addresses are ${interfaces}.\\nYou will be able to repeat the whole installation if required by selecting the openHABian menu for MTA again."
  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"

  echo -n "$(timestamp) [openHABian] Setting up Mail Transfer Agent ... "
  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "Mail Transfer Agent installation" --yes-button "Begin" --no-button "Cancel" --yesno "$introText" 17 80); then echo "CANCELED"; return 0; fi
    if ! dpkg-reconfigure exim4-config; then echo "CANCELED"; return 0; fi

    if ! smarthost="$(whiptail --title "Enter public mail service smarthost to relay your mails to" --inputbox "\\nEnter the list of smarthost(s) to use your account for. Do not append port numbers." 9 80 "smtp.gmail.com" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! smartport="$(whiptail --title "port number of the smarthost to relay your mails to" --inputbox "\\nEnter the port number of the smarthost to use" 9 80 "587" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! relayuser="$(whiptail --title "Enter your public service mail user" --inputbox "\\nEnter your mail username you use with the public service to relay all outgoing mail to $smarthost" 10 80 "$relayuser" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! relaypass="$(whiptail --title "Enter your public service mail password" --passwordbox "\\nEnter the password to use for mailuser ${relayuser} to relay mail via ${smarthost}" 9 80 "$relaypass" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! adminmail="$(whiptail --title "Enter your administration user's mail address" --inputbox "\\nEnter the address to send system reports to" 9 80 "$adminmail" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    for i in smarthost smartport relayuser relaypass adminmail; do store_in_conf $i; done
  else
    sed -e "s|%INTERFACES|${interfaces}|g" -e "s|%SMARTHOST|${smarthost}|g" -e "s|%SMARTPORT|${smartport}|g" -e "s|%RELAYNETS|${relaynets}|g" "$updateEximTemplate" > "$eximConfig"
    update-exim4.conf
    echo "OK"
  fi
  if ! cond_redirect zram_dependency install exim4; then return 1; fi

  echo -n "$(timestamp) [openHABian] Creating MTA config... "
  if ! cond_redirect mkdir -p /var/log/exim4; then echo "FAILED (logging)"; return 1; fi
  if ! cond_redirect chmod -R u+rw /var/log/exim4; then echo "FAILED (logging chmod)"; return 1; fi
  if ! cond_redirect chown -R Debian-exim /var/log/exim4; then echo "FAILED (logging chown)"; return 1; fi
  if ! grep '^#' "$eximPasswd" > "$temp"; then echo "FAILED (configuration)"; rm -f "$temp"; return 1; fi
  if ! echo "${smarthost}:${relayuser}:${relaypass}" >> "$temp"; then echo "FAILED (configuration)"; rm -f "$temp"; return 1; fi
  if ! cond_redirect cp "$temp" "$eximPasswd"; then echo "FAILED (copy)"; rm -f "$temp"; return 1; fi
  if ! cond_redirect rm -f "$temp"; then echo "FAILED (remove temp)"; return 1; fi
  if cond_redirect chmod o-rwx "$eximPasswd"; then echo "OK"; else echo "FAILED (permissions)"; return 1; fi

  for s in base paniclog; do
    if [[ -f "$logrotateFile-$s" ]]; then
      sed -i 's#Create 640 Debian-exim adm#Create 640 Debian-exim adm\n\tsu Debian-exim adm#g' "$logrotateFile-$s"
    fi
  done

  echo -n "$(timestamp) [openHABian] Adding to $relayuser email to system accounts... "
  sed -i '/^[^#]/d' ${addresses}
  if {
    # shellcheck disable=SC2154
    echo "openhab: $adminmail"; echo "${username:-openhabian}: $adminmail"
    echo "root: $adminmail"; echo "backup: $adminmail"
  } >> "$addresses"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Function for installing etckeeper, a git based /etc backup.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    etckeeper_setup()
##
etckeeper_setup() {
  if ! [[ -x $(command -v etckeeper) ]]; then
    echo -n "$(timestamp) [openHABian] Installing etckeeper (git based /etc backup)... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" etckeeper; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Configuring etckeeper (git based /etc backup)... "
  if ! cond_redirect sed -i -e 's/VCS="bzr"/\#VCS="bzr"/g' /etc/etckeeper/etckeeper.conf; then echo "FAILED"; return 1; fi
  if ! cond_redirect sed -i -e 's/\#VCS="git"/VCS="git"/g' /etc/etckeeper/etckeeper.conf; then echo "FAILED"; return 1; fi
  if cond_redirect bash -c "cd /etc && etckeeper init && git config user.email 'etckeeper@openHABian' && git config user.name 'openhabian' && git commit -m 'initial checkin' && git gc"; then echo "OK"; else echo "FAILED"; return 1; fi
}

## Function for installing Homegear, the Homematic CCU2 emulation software.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    homegear_setup()
##
homegear_setup() {
  local disklistFileAWS="/etc/amanda/openhab-aws/disklist"
  local disklistFileDir="/etc/amanda/openhab-dir/disklist"
  local introText="This will install Homegear, the Homematic CCU2 emulation software, using the latest stable release available from the official repository."
  local keyName="homegear-archive-keyring"
  local myOS
  local myRelease
  local temp
  local successText="Setup was successful.\\n\\nHomegear is now up and running. Next you might want to edit the configuration file '/etc/homegear/families/homematicbidcos.conf' or adopt devices through the homegear console, reachable by 'homegear -r'.\\n\\nPlease read up on the homegear documentation for more details: https://doc.homegear.eu/data/homegear\\n\\nTo continue your integration in openHAB, please follow the instructions under: https://www.openhab.org/addons/bindings/homematic/"

  temp="$(mktemp "${TMPDIR:-/tmp}"/openhabian.XXXXX)"
  myOS="$(lsb_release -si)"
  myRelease="$(lsb_release -sc)"

  if [[ "$myRelease" == "n/a" ]]; then
    myRelease="${osrelease:-bookworm}"
  fi
  # shellcheck disable=SC2078,SC2154
  if [[ "${myOS,,}" == "debian" ]] && [[ is_arm || running_in_docker ]]; then
      # Workaround for CI not actually reporting as Raspberry Pi OS
      myOS="raspberry_pi_os"  # Workaround for Homegear's Raspios APT repo being broken
  fi

  echo -n "$(timestamp) [openHABian] Beginning Homematic CCU2 emulation software Homegear install... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "Homegear installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 8 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  if ! add_keys "https://apt.homegear.eu/Release.key" "$keyName"; then return 1; fi


  # Add Homegear's repository to APT - needed to use testing repo, now needs stable
  if ! is_pi; then
    myRelease=trixie
    # x86:
    echo "deb [signed-by=/usr/share/keyrings/homegear-archive-keyring.gpg] https://apt.homegear.eu/debian/${myRelease}/homegear/stable/ ${myRelease} main" > /etc/apt/sources.list.d/homegear.list
    cat /etc/apt/sources.list.d/homegear.list
  else
    if [[ "$(dpkg --print-architecture)" == 'arm64' ]]; then
      # 64-bit Raspberry Pi OS:
      echo "deb [signed-by=/usr/share/keyrings/homegear-archive-keyring.gpg] https://apt.homegear.eu/debian/${myRelease}/homegear/stable/ ${myRelease} main" > /etc/apt/sources.list.d/homegear.list
    else
      # 32-bit Raspberry Pi OS
      echo "deb [signed-by=/usr/share/keyrings/homegear-archive-keyring.gpg] https://apt.homegear.eu/raspberry_pi_os/${myRelease}/homegear/stable/ ${myRelease} main" > /etc/apt/sources.list.d/homegear.list
    fi
  fi
  echo -n "$(timestamp) [openHABian] Installing Homegear... "
  if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
  if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" homegear homegear-homematicbidcos homegear-homematicwired homegear-max homegear-management; then echo "OK"; else echo "FAILED"; return 1; fi
  echo -n "$(timestamp) [openHABian] Setting up Homegear user account permissions... "
  if ! cond_redirect adduser "${username:-openhabian}" homegear; then echo "FAILED"; return 1; fi
  if cond_redirect adduser openhab homegear; then echo "OK"; else echo "FAILED"; return 1; fi
  echo -n "$(timestamp) [openHABian] Setting up Homegear service... "
  if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/homegear.service /etc/systemd/system/homegear.service; then echo "FAILED (copy service)"; return 1; fi
  if ! cond_redirect install -m 644 "${BASEDIR:-/opt/openhabian}"/includes/homegear-management.service /etc/systemd/system/homegear-management.service; then echo "FAILED (copy service)"; return 1; fi
  if ! cond_redirect install -m 755 "${BASEDIR}/includes/rpi_init" /usr/local/sbin; then echo "FAILED (install rpi_init script)"; return 1; fi
  if ! cond_redirect rm -f /lib/systemd/system/homegear*; then echo "FAILED (clean default service)"; return 1; fi
  if running_in_docker; then sed -i '/RuntimeDirectory/d' /etc/systemd/system/homegear*; fi
  if ! cond_redirect zram_dependency install homegear homegear-management wiringpi; then return 1; fi
  if zram_is_installed && ! mkdir -p /opt/zram/log.bind/homegear /var/log/homegear && chown homegear /opt/zram/log.bind/homegear /var/log/homegear; then echo "FAILED (create zram logdir)"; return 1; fi
  if ! cond_redirect systemctl enable --now homegear.service homegear-management.service; then echo "FAILED (enable service)"; return 1; fi

  if [[ -f $disklistFileDir ]]; then
    echo -n "$(timestamp) [openHABian] Adding Homegear to Amanda local backup... "
    if ! cond_redirect sed -i -e '/homegear/d' "$disklistFileDir"; then echo "FAILED (old config)"; return 1; fi
    if (echo "${hostname}  /var/lib/homegear             comp-user-tar" >> "$disklistFileDir"); then echo "OK"; else echo "FAILED (new config)"; return 1; fi
  fi
  if [[ -f $disklistFileAWS ]]; then
    echo -n "$(timestamp) [openHABian] Adding Homegear to Amanda AWS backup... "
    if ! cond_redirect sed -i -e '/homegear/d' "$disklistFileAWS"; then echo "FAILED (old config)"; return 1; fi
    if (echo "${hostname}  /var/lib/homegear             comp-user-tar" >> "$disklistFileAWS"); then echo "OK"; else echo "FAILED (new config)"; return 1; fi
  fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$successText" 14 80
  fi
}

## Function for installing MQTT Eclipse Mosquitto through the official repository.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    mqtt_setup()
##
mqtt_setup() {
  local mosquittoConf="/etc/mosquitto/mosquitto.conf"
  local mosquittoPasswd="/etc/mosquitto/passwd"
  local mqttPasswd
  local mqttUser
  local mqttDefaultUser="openhabian"
  local introText="\\nThe MQTT broker Eclipse Mosquitto will be installed from the official repository."
  local mqttUserText="\\nSecure your MQTT broker by a username:password combination. Every client will need to provide these upon connection.\\nPlease enter your MQTT-User (default = openhabian):"
  local mqttPasswordText="\\nPlease provide a password (consisting of ASCII printable characters except space). Run setup again to change."

  local successText="Setup was successful.\\n\\nEclipse Mosquitto is now up and running in the background. You should be able to make a first connection.\\n\\nTo continue your integration in openHAB, please follow the instructions under: https://www.openhab.org/addons/bindings/mqtt/"

  echo -n "$(timestamp) [openHABian] Beginning the MQTT broker Eclipse Mosquitto installation... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "MQTT installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 14 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  if ! mosquitto_is_installed; then
    echo -n "$(timestamp) [openHABian] Installing MQTT... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" mosquitto mosquitto-clients; then echo "OK"; else echo "FAILED"; return 1; fi
    apt-get install -o DPkg::Lock::Timeout="$APTTIMEOUT" --fix-broken --yes
  fi

  echo -n "$(timestamp) [openHABian] Configuring MQTT... "
  if [[ -n $INTERACTIVE ]]; then
    if ! mqttUser=$(whiptail --title "MQTT User" --inputbox "$mqttUserText" 10 80 "$mqttDefaultUser" 3>&1 1>&2 2>&3); then return 0; fi
    if ! mqttPasswd="$(whiptail --title "MQTT Authentication" --passwordbox "$mqttPasswordText" 14 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
  fi
  if ! grep -qs "listener" ${mosquittoConf}; then
      printf "\\n\\nlistener 1883" >> ${mosquittoConf}
  fi
  if [[ -n $mqttPasswd ]]; then
    if ! grep -qs password_file ${mosquittoPasswd} ${mosquittoConf}; then
      echo -e "\\npassword_file ${mosquittoPasswd}\\nallow_anonymous false\\n" >> ${mosquittoConf}
    fi
    touch ${mosquittoPasswd}
    chown "mosquitto:${username:-openhabian}" ${mosquittoPasswd}
    chmod 660 ${mosquittoPasswd}
    if cond_redirect mosquitto_passwd -b ${mosquittoPasswd} "$mqttUser" "$mqttPasswd"; then echo "OK"; else echo "FAILED"; return 1; fi
  else
    if ! cond_redirect sed -i -e '/password_file/d' ${mosquittoConf}; then echo "FAILED"; return 1; fi
    if ! cond_redirect sed -i -e '/allow_anonymous/d' ${mosquittoConf}; then echo "FAILED"; return 1; fi
    printf "\\nallow_anonymous true" >> ${mosquittoConf}
    if cond_redirect rm -f ${mosquittoPasswd}; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  if ! cond_redirect zram_dependency install mosquitto; then return 1; fi
  if zram_is_installed && ! mkdir -p /opt/zram/log.bind/mosquitto /var/log/mosquitto && chown mosquitto /opt/zram/log.bind/mosquitto /var/log/mosquitto; then echo "FAILED (create zram logdir)"; return 1; fi
  echo -n "$(timestamp) [openHABian] Setting up MQTT Eclipse Mosquitto broker service... "
  if ! cond_redirect usermod --append --groups mosquitto "${username:-openhabian}"; then echo "FAILED (${username:-openhabian} mosquitto)"; return 1; fi
  if cond_redirect systemctl enable --now mosquitto.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$successText" 13 80
  fi
}

## Function for installing kndx as your EIB/KNX IP gateway and router to support your KNX bus system.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    knxd_setup()
##
knxd_setup() {
  local introText="This will install kndx as your EIB/KNX IP gateway and router to support your KNX bus system.\\n\\nNOTE: Typically, you don't need this if you connect via an IP interface or router to your KNX installation. This package is to turn an USB or serial interface into an IP interface.\\n\\nNOTE: openHABian changed from building and installing latest source to installing the knxd package provided by several distributions."
  local missingText="Setup could not find knxd package.\\n\\nopenHABian changed from building and installing latest source to installing the knxd package provided by several distrubutions. In case you have an installation of openHABian on a custom Linux which does not provide knxd package, you could try to installation routine we used before as described at 'Michels Tech Blog': https://bit.ly/3dzeoKh"
  local errorText="Installation of knxd package failed, see console log for details."
  local successText="Installation was successful.\\n\\nPlease edit '/etc/knxd.conf' to meet your interface requirements. For further information on knxd options, please type 'knxd --help' or see /usr/share/doc/knxd/.\\n\\nSee also the openHAB KNX binding's documentation."

  echo -n "$(timestamp) [openHABian] Beginning setup of knxd package... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "knxd installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 15 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  if ! apt-cache show knxd &>/dev/null; then
    echo "FAILED (install)";
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "knxd install failed" --msgbox "$missingText" 15 80
    fi
    return 1
  fi

  echo -n "$(timestamp) [openHABian] Installing package knxd... "
  if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" knxd; then
    echo "OK";
  else
    echo "FAILED (install)"
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "knxd install failed" --msgbox "$errorText" 15 80
    fi
    return 1
  fi

  # optional package which contains command line tools, it is allowed to fail
  echo -n "$(timestamp) [openHABian] Installing optional package knxd-tools... "
  if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" knxd-tools; then
    echo "OK";
  else
    echo "FAILED (optional install)"
  fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "knxd install sucessful" --msgbox "$successText" 15 80
  fi
}

## Function for installing owserver to support 1wire functionality.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    1wire_setup()
##
1wire_setup() {
  local introText="This will install owserver to support 1wire functionality in general.\\n\\nUse the ow-shell and usbutils tools to check USB (lsusb) and 1wire function (owdir, owread).\\n\\nFor more details, have a look at https://owfs.org"
  local successText="Setup was successful.\\n\\nNext, please configure your system in /etc/owfs.conf.\\nUse # to comment/deactivate a line. All you should have to change is the following:\\nDeactivate\\n  server: FAKE = DS18S20,DS2405\\nand activate one of these most common options (depending on your device):\\n  #server: usb = all\\n  #server: device = /dev/ttyS1\\n  #server: device = /dev/ttyUSB0"

  echo -n "$(timestamp) [openHABian] Beginning setup of owserver (1wire)... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "1wire installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 12 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  if ! dpkg -s 'owserver' 'ow-shell' 'usbutils' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing owserver (1wire)... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" owserver ow-shell usbutils; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$successText" 17 80
  fi
}

## Function for installing miflora-mqtt-daemon - The Xiaomi Mi Flora Plant Sensor MQTT Client/Daemon.
## This function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    miflora_setup()
##
miflora_setup() {
  if ! is_pi_bt; then
    echo "$(timestamp) [openHABian] Beginning setup of miflora-mqtt-daemon... SKIPPED (no Bluetooth support)"
    return 0
  fi

  local introText="This will install or update miflora-mqtt-daemon - The Xiaomi Mi Flora Plant Sensor MQTT Client/Daemon.\\n\\nFor further details see:\\nhttps://github.com/ThomDietrich/miflora-mqtt-daemon"
  local mifloraDir="/opt/miflora-mqtt-daemon"
  local successText="Setup was successful.\\n\\nThe Daemon was installed and the systemd service was set up just as described in it's README. Please add your MQTT broker settings in '${mifloraDir}/config.ini' and add your Mi Flora sensors. After that be sure to restart the daemon to reload it's configuration.\\n\\nAll details can be found under: https://github.com/ThomDietrich/miflora-mqtt-daemon\\nThe article also contains instructions regarding openHAB integration."

  if ! dpkg -s 'git' 'python3' 'python3-pip' 'bluetooth' 'bluez' 'build-essential' 'pkg-config' 'libglib2.0-dev' &> /dev/null; then
    echo -n "$(timestamp) [openHABian] Installing miflora-mqtt-daemon required packages... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" git python3 python3-pip bluetooth bluez build-essential pkg-config libglib2.0-dev; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  echo -n "$(timestamp) [openHABian] Beginning setup of miflora-mqtt-daemon... "
  if [[ -n $INTERACTIVE ]]; then
    if (whiptail --title "miflora-mqtt-daemon installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 11 80); then echo "OK"; else echo "CANCELED"; return 0; fi
  else
    echo "OK"
  fi

  echo -n "$(timestamp) [openHABian] Setting up miflora-mqtt-daemon... "
  if ! [[ -d $mifloraDir ]]; then
    cond_echo "\\nFresh Installation... "
    if ! cond_redirect git clone https://github.com/ThomDietrich/miflora-mqtt-daemon.git "$mifloraDir"; then echo "FAILED (git clone)"; return 1; fi
  else
    cond_echo "\\nUpdate... "
    if ! cond_redirect update_git_repo "$mifloraDir" "master"; then echo "FAILED (update git repo)"; return 1; fi
  fi
  if cond_redirect cp "$mifloraDir"/config.{ini.dist,ini}; then echo "OK"; else echo "FAILED (copy files)"; return 1; fi

  cond_echo "Filesystem permissions corrections... "
  if ! cond_redirect chown -R "openhab:${username:-openhabian}" "$mifloraDir"; then echo "FAILED (permissions)"; return 1; fi
  if ! cond_redirect chmod -R ug+wX "$mifloraDir"; then echo "FAILED (permissons)"; return 1; fi
## For Debian 12 (Bookworm) compatibility we need to make a Python Virtual Enviroment (venv)
  cond_echo "Preparing python virtual enviroment"
  cond_redirect python -m venv --system-site-packages "$mifloraDir"/env
  cond_redirect source "$mifloraDir"/env/bin/activate
## original code from here
  cond_echo "Installing required python packages"
  cond_redirect "$mifloraDir"/env/bin/pip3 install -r "$mifloraDir"/requirements.txt
## deactivate venv to avoid conflicts with other functions
  cond_redirect deactivate
## original code from here
  echo -n "$(timestamp) [openHABian] Setting up miflora-mqtt-daemon service... "
  if ! cond_redirect install -m 644 "$mifloraDir"/template.service /etc/systemd/system/miflora.service; then echo "FAILED (copy service)"; return 1; fi
  if ! cond_redirect sed -i -e "s|^ExecStart=.*|ExecStart=${mifloraDir}/env/bin/python3 ${mifloraDir}/miflora-mqtt-daemon.py|" /etc/systemd/system/miflora.service; then echo "FAILED (service ExecStart)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if cond_redirect systemctl enable --now miflora.service; then echo "OK"; else echo "FAILED (enable service)"; return 1; fi

  if grep -qsE "^[[:space:]]*dtoverlay=(pi3-)?miniuart-bt" "${CONFIGTXT}"; then
    cond_echo "Warning! The internal RPi Bluetooth module is disabled on your system. You need to enable it before the daemon may use it."
  fi

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$successText" 16 80
  fi
}

## Function for installing nginx to allow for secure interaction with openHAB over the network.
## This function can only be invoked in INTERACTIVE with userinterface.
##
##    nginx_setup()
##
nginx_setup() {
  local auth="false"
  local authText
  local certPath
  local confirmText
  local domain
  local domainIP
  local domainText="\\nIf you have a registered domain enter it now, if you have a static public IP enter \"IP\", otherwise leave blank:"
  local httpsText
  local introText="This will enable you to access the openHAB interface through the normal HTTP/HTTPS ports and optionally secure it with username/password and/or an SSL certificate."
  local keyPath
  local logrotateFile="/etc/logrotate.d/nginx"
  local nginxPass
  local nginxPass1
  local nginxPass2
  local nginxUsername
  local portWarning
  local protocol
  local pubIP
  local secure="false"
  local validDomain="false"

  if ! [[ -x $(command -v dig) ]]; then
    echo -n "$(timestamp) [openHABian] Installing nginx required packages (dnsutils)... "
    if cond_redirect install_dnsutils; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  function comment {
    if ! sed -e "/[[:space:]]$1/ s/^#*/#/g" -i "$2"; then echo "FAILED (comment)"; return 1; fi
  }
  function uncomment {
    if ! sed -e "/$1/s/^$1//g" -i "$2"; then echo "FAILED (uncomment)"; return 1; fi
  }

  if [[ -n $INTERACTIVE ]]; then
    #echo "$(timestamp) [openHABian] nginx setup must be run in interactive mode! Canceling nginx setup!"

    echo -n "$(timestamp) [openHABian] Beginning setup of nginx as reverse proxy with authentication... "
    if (whiptail --title "nginx installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 9 80); then echo "OK"; else echo "CANCELED"; return 0; fi

    echo "$(timestamp) [openHABian] Configuring nginx authentication options... "
    if openhab_is_installed || (whiptail --title "Authentication setup" --yesno "Would you like to secure your openHAB interface with username and password?" 7 80); then
      auth="true"
    fi
    if [[ "$auth" == "true" ]]; then
      if nginxUsername="$(whiptail --title "Authentication setup" --inputbox "\\nEnter a username to sign into openHAB:" 9 80 openhab 3>&1 1>&2 2>&3)"; then
        while [[ -z $nginxPass ]]; do
          if ! nginxPass1="$(whiptail --title "Authentication setup" --passwordbox "\\nEnter a password for ${nginxUsername}:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
          if ! nginxPass2="$(whiptail --title "Authentication setup" --passwordbox "\\nPlease confirm the password:" 9 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
          if [[ $nginxPass1 == "$nginxPass2" ]] && [[ ${#nginxPass1} -ge 8 ]] && [[ ${#nginxPass2} -ge 8 ]]; then
            nginxPass="$nginxPass1"
          else
            whiptail --title "Authentication setup" --msgbox "Password mismatched, blank, or less than 8 characters... Please try again!" 7 80
          fi
        done
      else
        echo "CANCELED"
        return 0
      fi
    fi

    if (whiptail --title "Secure certificate setup" --yesno "Would you like to secure your openHAB interface with HTTPS?" 7 80); then secure="true"; echo "OK"; else echo "CANCELED"; fi

    if [[ $auth == "true" ]]; then
      authText="Authentication Enabled\\n- Username: ${nginxUsername}"
    else
      authText="Authentication Disabled"
    fi

    if [[ $secure == "true" ]]; then
      httpsText="Proxy will be secured by HTTPS"
      protocol="HTTPS"
      portWarning="Important! Before you continue, please make sure that port 80 (HTTP) of this machine is reachable from the internet (portforwarding, etc.). Otherwise the certbot connection test will fail.\\n\\n"
    else
      httpsText="Proxy will not be secured by HTTPS"
      protocol="HTTP"
      portWarning=""
    fi

    echo "$(timestamp) [openHABian] Configuring nginx network options... "
    cond_echo "Obtaining public IP address... "
    if ! pubIP="$(get_public_ip)"; then echo "FAILED (public ip)"; return 1; fi

    cond_echo "Configuring domain settings... "
    if ! domain="$(whiptail --title "Domain setup" --inputbox "$domainText" 10 80 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi

    while [[ $validDomain == "false" ]] && [[ -n $domain ]] && [[ $domain != "IP" ]]; do
      cond_echo "Obtaining domain IP address... "
      if ! domainIP="$(get_public_ip "$domain")"; then echo "FAILED (domain IP)"; return 1; fi
      if [[ "$pubIP" == "$domainIP" ]]; then
        validDomain="true"
        cond_echo "Public and domain IP address match."
      else
        cond_echo "Public and domain IP address mismatch!"
        if ! domain=$(whiptail --title "Domain setup" --inputbox "\\nDomain does not resolve to your public IP address. Please enter a valid domain.\\n\\n${domainText}" 14 80 3>&1 1>&2 2>&3); then echo "CANCELED"; return 0; fi
      fi
    done

  fi

  if [[ $validDomain == "false" ]]; then
    if [[ $domain == "IP" ]]; then
      cond_echo "Setting domain to static public IP address $pubIP"
      domain="$pubIP"
    else
      cond_echo "Setting domain to localhost"
      domain="localhost"
    fi
  fi

  confirmText="The following settings have been chosen:\\n\\n- ${authText}\\n- ${httpsText}\\n- Domain: ${domain} (Public IP Address: ${pubIP})\\n\\nYou will be able to connect to openHAB on the default ${protocol} port.\\n\\n${portWarning}Do you wish to continue and setup an nginx server now?"

  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "Confirmation" --yesno "$confirmText" 20 80); then echo "CANCELED"; return 0; fi
  else
    echo "$confirmText"
  fi
#return 1

  echo -n "$(timestamp) [openHABian] Installing nginx... "
  if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" nginx; then echo "OK"; else echo "FAILED"; return 1; fi

  echo -n "$(timestamp) [openHABian] Setting up nginx configuration... "
  if ! cond_redirect rm -rf /etc/nginx/sites-enabled/default; then echo "FAILED (remove default)"; return 1; fi
  if ! cond_redirect cp "${BASEDIR:-/opt/openhabian}"/includes/nginx.conf /etc/nginx/sites-enabled/openhab; then echo "FAILED (copy configuration)"; return 1; fi
  if cond_redirect sed -i -e 's|DOMAINNAME|'"${domain}"'|g' /etc/nginx/sites-enabled/openhab; then echo "OK"; else echo "FAILED (set domain name)"; return 1; fi

  # use Tailscale resolver if up
  ping -c 3 100.100.100.100 && uncomment "#VPN" /etc/nginx/sites-enabled/openhab

  if [[ $auth == "true" ]]; then
    echo -n "$(timestamp) [openHABian] Installing nginx password utilities... "
    if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" apache2-utils; then echo "OK"; else echo "FAILED"; return 1; fi
    if cond_redirect htpasswd -b -c /etc/nginx/.htpasswd "$nginxUsername" "$nginxPass"; then echo "OK"; else echo "FAILED (password file)"; return 1; fi
    cond_echo "Setting up nginx password options..."
    if ! uncomment "#AUTH" /etc/nginx/sites-enabled/openhab; then return 1; fi
  fi

  if [[ $secure == "true" ]]; then
    cond_echo "Setting up nginx security options..."
    if [[ $validDomain == "true" ]]; then
      echo -n "$(timestamp) [openHABian] Installing certbot... "
      if is_ubuntu; then
        if ! dpkg -s 'software-properties-common' &> /dev/null; then
          if ! cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" software-properties-common; then echo "FAILED (Ubuntu prerequsites)"; return 1; fi
        fi
        if ! cond_redirect add-apt-repository universe; then echo "FAILED (add universe repo)"; return 1; fi
        if ! add-apt-repository ppa:certbot/certbot; then echo "FAILED (add certbot repo)"; return 1; fi
        if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
      fi
      if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" certbot python3-certbot-nginx; then echo "OK"; else echo "FAILED"; return 1; fi

      echo -n "$(timestamp) [openHABian] Configuring certbot... "
      mkdir -p /var/www/"$domain"
      if ! uncomment "#WEBROOT" /etc/nginx/sites-enabled/openhab; then return 1; fi
      if ! nginx -t; then echo "FAILED (nginx configuration test)"; return 1; fi
      if ! cond_redirect systemctl -q reload nginx.service &> /dev/null; then echo "FAILED (nginx reload)"; return 1; fi
      if certbot certonly --webroot -w /var/www/"$domain" -d "$domain"; then echo "OK"; else echo "FAILED"; return 1; fi
      certPath="/etc/letsencrypt/live/${domain}/fullchain.pem"
      keyPath="/etc/letsencrypt/live/${domain}/privkey.pem"
    else
      echo -n "$(timestamp) [openHABian] Configuring openSSL... "
      mkdir -p /etc/ssl/certs
      certPath="/etc/ssl/certs/openhab.crt"
      keyPath="/etc/ssl/certs/openhab.key"
      whiptail --title "openSSL key generation" --msgbox "openSSL is about to ask for information in the command line, please fill out each line." 8 80
      if ! openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout "$keyPath" -out "$certPath"; then echo "FAILED (openSSL configuration)"; return 1; fi
    fi
    if ! uncomment "#CERT" /etc/nginx/sites-enabled/openhab; then return 1; fi
    if ! cond_redirect sed -i -e 's|CERTPATH|'"${certPath}"'|g' /etc/nginx/sites-enabled/openhab; then echo "FAILED (certpath config)"; return 1; fi
    if ! cond_redirect sed -i -e 's|KEYPATH|'"${keyPath}"'|g' /etc/nginx/sites-enabled/openhab; then echo "FAILED (keypath config)"; return 1; fi
    if ! uncomment "#REDIR" /etc/nginx/sites-enabled/openhab; then return 1; fi
    if ! comment "listen" /etc/nginx/sites-enabled/openhab; then return 1; fi
    if ! uncomment "#SSL" /etc/nginx/sites-enabled/openhab; then return 1; fi
  fi

  if [[ -f "$logrotateFile" ]]; then
    sed -i 's|daily|daily\n\tsu www-data adm|g' "$logrotateFile"
  fi

  if ! nginx -t; then echo "FAILED (nginx configuration test)"; return 1; fi
  if ! cond_redirect systemctl restart nginx.service; then echo "FAILED (nginx restart)"; return 1; fi

  infoText="Setup successful. Please try entering ${protocol}://${domain} in a browser to test your settings."
  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "Operation successful" --msgbox "$infoText" 8 80
  else
    echo "$infoText"
  fi
}

## Function for installing deCONZ, the companion web app to the popular Conbee/Raspbee Zigbee controller
## The function can be invoked either INTERACTIVE with userinterface or UNATTENDED.
##
##    deconz_setup(int port, int wsPort)
##
## Valid arguments: Phoscon Web UI (HTTP) port, deCONZ WebSocket API port
##
deconz_setup() {
  local defaultPort=8081
  local defaultWsPort=8088
  local port="${1:-$defaultPort}"
  local wsPort="${2:-$defaultWsPort}"
  local keyName="deconz"
  local appData="/var/lib/openhab/persistence/deCONZ"
  local introText="This will install deCONZ to support Dresden Elektronik Conbee and Raspbee Zigbee controllers.\\nThe Phoscon Web UI and the deCONZ WebSocket API are provided by deCONZ.\\nNext step: choose HTTP/WS ports; avoid conflicts with openHAB (default 8080)."
  local successText=""
  local repo="/etc/apt/sources.list.d/deconz.list"

  if [[ -n "$UNATTENDED" ]] && [[ "${deconz_install:-disable}" != "enable" ]]; then
    echo -n "$(timestamp) [openHABian] Skipping deCONZ install as requested."
    return 1
  fi

  if [[ -n $INTERACTIVE ]]; then
    if ! (whiptail --title "deCONZ installation" --yes-button "Continue" --no-button "Cancel" --yesno "$introText" 11 80); then return 0; fi
  fi

  if ! add_keys "https://phoscon.de/apt/deconz.pub.key" "$keyName"; then return 1; fi

  myOS="$(lsb_release -si)"
  myRelease="$(lsb_release -sc | head -1)"
  if [[ "$myRelease" == "n/a" ]] || running_in_docker; then
    myRelease=${osrelease:-bookworm}
  fi

  if is_x86_64; then
    arch=" arch=amd64"
  fi
  echo "deb [signed-by=/usr/share/keyrings/${keyName}.gpg${arch}] http://phoscon.de/apt/deconz generic main" > $repo

  if ! cond_redirect mkdir -p "${appData}" && fix_permissions "${appData}" "${username:-openhabian}:${username:-openhabian}" 664 775 && ln -sf "${appData}" /home/"${username:-openhabian}"/.local; then echo "FAILED (deCONZ database on zram)"; return 1; fi
  echo -n "$(timestamp) [openHABian] Preparing deCONZ repository ... "
  if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; fi
  
  local deconzPkg="deconz"
  if [[ "$myRelease" == "bookworm" || "$myRelease" == "trixie" ]] && apt-cache show deconz-qt6 > /dev/null 2>&1; then
    deconzPkg="deconz-qt6"
  fi

  echo -n "$(timestamp) [openHABian] Installing deCONZ ... "
  if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" "$deconzPkg"; then echo "OK"; else echo "FAILED (install deCONZ package)"; return 1; fi

  if [[ -n $INTERACTIVE ]]; then
    if ! port="$(whiptail --title "Enter Phoscon Web UI (HTTP) port" --inputbox "\\nPlease enter the port you want the Phoscon Web UI to run on:" 11 80 "$port" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
    if ! wsPort="$(whiptail --title "Enter deCONZ WebSocket API port" --inputbox "\\nPlease enter the WebSocket port you want deCONZ to run on:" 11 80 "$wsPort" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
  fi
  if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    echo "$(timestamp) [openHABian] WARN (invalid deCONZ HTTP port: $port, using default ${defaultPort})"
    port="$defaultPort"
  fi
  if ! [[ "$wsPort" =~ ^[0-9]+$ ]] || (( wsPort < 1 || wsPort > 65535 )); then
    echo "$(timestamp) [openHABian] WARN (invalid deCONZ WebSocket port: $wsPort, using default ${defaultWsPort})"
    wsPort="$defaultWsPort"
  fi
  
  # remove unneeded parts so they cannot interfere with openHABian
  cond_redirect systemctl disable --now deconz-gui.service deconz-homebridge.service deconz-homebridge-install.service deconz-init.service deconz-wifi.service
  cond_redirect rm -f "/lib/systemd/system/deconz-{homebridge,homebridge-install,init,wifi}.service"
  cond_redirect systemctl daemon-reload

  # set deCONZ HTTP port and WebSocket API port
  if ! cond_redirect sed -i -e 's|http-port=80$|http-port='"${port}"' --ws-port='"${wsPort}"'|g' /lib/systemd/system/deconz.service; then echo "FAILED (replace port in service start)"; return 1; fi
  if cond_redirect systemctl enable deconz.service && cond_redirect systemctl restart deconz.service; then echo "OK"; else echo "FAILED (service restart with modified port)"; return 1; fi

  successText="deCONZ installed. Phoscon Web UI is available on port ${port} and the deCONZ WebSocket API on port ${wsPort}."
  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "deCONZ install successfull" --msgbox "$successText" 11 80
  fi
}

## Function for (un)installing EVCC, the Electric Vehicle Charge Controller
## The function must be invoked UNATTENDED.
## Valid arguments: "install" or "remove"
##
##   install_evcc(String action)
##
##
install_evcc() {
  local port=7070
  local installText="This will install EVCC, the Electric Vehicle Charge Controller\\nUse the web interface on port $port to access EVCC's own web interface."
  local removeText="This will remove EVCC, the Electric Vehicle Charge Controller."
  local keyName="evcc"
  local repokeyurl="https://dl.cloudsmith.io/public/evcc/stable/gpg.key"
  local repotxt="[signed-by=/etc/apt/trusted.gpg.d/evcc-stable.asc] https://dl.cloudsmith.io/public/evcc/stable/deb/debian any-version main"
  local repo="/etc/apt/sources.list.d/evcc.list"
  local svcdir="/etc/systemd/system/evcc.service.d"
  local sudoersFile="011_evcc"
  local sudoersPath="/etc/sudoers.d"

  if [[ $1 == "remove" ]]; then
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "EVCC removal" --msgbox "$removeText" 7 80
    fi
    echo -n "$(timestamp) [openHABian] Removing EVCC... "
    if ! cond_redirect systemctl disable --now evcc.service; then echo "FAILED (disable evcc.service)"; return 1; fi
    if cond_redirect apt-get purge --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" evcc; then echo "OK"; else echo "FAILED"; return 1; fi
    rm -f "$svcdir/override.conf"
    return;
  fi

  if [[ $1 != "install" ]]; then return 1; fi
  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "EVCC installation" --msgbox "$installText" 8 80
  fi
  if ! cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" debian-keyring debian-archive-keyring; then echo "FAILED"; return 1; fi
  if ! curl -1sLf "$repokeyurl" > /etc/apt/trusted.gpg.d/evcc-stable.asc; then echo -n "FAILED (retrieve EVCC repo key) "; fi
  if ! add_keys "$repokeyurl" "$keyName"; then echo "FAILED (add EVCC repo key)"; return 1; fi
  ( echo "deb ${repotxt}"; echo "deb-src ${repotxt}" ) > $repo
  echo -n "$(timestamp) [openHABian] Installing EVCC... "
  cond_redirect apt update -o DPkg::Lock::Timeout="$APTTIMEOUT"
  if ! cond_redirect apt install -y evcc; then echo "FAILED (EVCC package installation)"; return 1; fi

  mkdir "$svcdir"
  if [[ $(systemctl show -pUser evcc | cut -d= -f2) == "${username:-openhabian}" ]]; then
    sed -e "s|%USER|${username}|g" "${BASEDIR:-/opt/openhabian}"/includes/evcc-override.conf > "$svcdir/override.conf"
  fi

  if ! cond_redirect systemctl enable --now evcc.service; then echo "FAILED (enable evcc.service)"; return 1; fi
  cp "${BASEDIR:-/opt/openhabian}/includes/${sudoersFile}" "${sudoersPath}/"
}


## Function for setting up EVCC, the Electric Vehicle Charge Controller
## The function can be invoked INTERACTIVE only and setup is in German only for now.
##
##    setup_evcc
##
setup_evcc() {
  local evccuser
  local evccdir
  local evccConfig="evcc.yaml"
  local port="${1:-7070}"
  local introText="This will create a configuration for EVCC, the Electric Vehicle Charge Controller\\nUse the web interface on port $port to access EVCC's own web interface."
  local successText="You have successfully created a configuration file for EVCC, the Electric Vehicle Charge Controller\\nIt replaces /etc/evcc.yaml."

  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "EVCC configuration" --msgbox "$introText" 8 80
    evcc configure --advanced	# creates evcc.yaml in current dir
  fi

  evccuser="$(systemctl show -pUser evcc | cut -d= -f2)"
  evccdir=$(eval echo "~${evccuser:-${username:-openhabian}}")
  if [[ -f ${evccConfig} ]]; then
    cond_redirect cp "${evccdir}"/${evccConfig} "${evccdir}"/${evccConfig}.SAVE
    cond_redirect mv "${evccConfig}" "${evccdir}"
  fi
  cond_redirect touch "${evccdir}"/${evccConfig}
  cond_redirect chown "${evccuser}:openhab" "${evccdir}"/${evccConfig}*
  cond_redirect usermod --append --groups evcc openhab
  cond_redirect chmod g+w "${evccdir}"/${evccConfig}*

  echo -n "$(timestamp) [openHABian] Created EVCC config, restarting ... "
  if cond_redirect systemctl restart evcc.service; then echo "OK"; else echo "FAILED"; fi
}

## Function for (un)installing / update ESPHome Device Builder
## The function can be invoked INTERACTIVE only.
## Valid arguments: "install" or "remove"
##
##  setup_esphome_device_builder(String install|remove)
## 

setup_esphome_device_builder() {
   
  # Variables
  local esphomeDir="/opt/esphome_device_builder"
  local esphomeConfigDir="/etc/openhab/ESPHome"
  local serviceTemplate="${BASEDIR:-/opt/openhabian}/includes/esphome-device-builder.service.template"
  local setupMode="$1"
  local port=6052

  # Whiptail / Console messages 
  local whiptailTitle="ESPHome Device Builder - Setup"
  local installStartText="No ESPHome Device Builder service detectet --> start installation"
  local installEndText="ESPHome Device Builder has been completely installed"
  local updateStartText="ESPHome Device Builder service detectet --> start update"
  local updateEndText="ESPHome Device Builder has been completely updated"
  local uninstallStartText="Start uninstalling the ESPHome Device Builder"
  local uninstallEndText="ESPHome Device Builder has been completely uninstalled"
  local errorText="An Error occured!\nFor Details please have a look at the shell messages"
  local portText="Access the webinterface at http://<your-ip>:$port"


  echo "$(timestamp) [openHABian] ##########################################################################################################"
  echo "$(timestamp) [openHABian] ESPHome Setup"
  
  # This Precheck is neccesary to decide if install or update routine is neccesary
  if [ "$setupMode" = "install" ]; then
    echo "$(timestamp) [openHABian] The option installation / update was selected"
    echo "$(timestamp) [openHABian] Check if the esphome-device-builder.service is already running..."
    if systemctl is-active --quiet esphome-device-builder.service; then
      setupMode="update"
    fi
  fi

  if [ "$setupMode" = "install" ]; then
    echo "$(timestamp) [openHABian] $installStartText";
    echo "$(timestamp) [openHABian] Check if Python 3 and pip are already installed..."
    if ! dpkg -s python3-venv &>/dev/null; then
      echo "$(timestamp) [openHABian] Installing Python 3 and pip..."
      if ! cond_redirect apt install -y python3-venv; then
        echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to install Python 3 and pip.${COL_DEF}"
        return 1
      fi   
    else
      echo "$(timestamp) [openHABian] Python 3 and pip are already available --> skip installation"
    fi 
        
    echo "$(timestamp) [openHABian] Creating directory at $esphomeDir and set permissions"
    if ! mkdir -p "$esphomeDir"; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to create $esphomeDir${COL_DEF}"
      return 1
    fi
    if ! chown -R "$LOGNAME:$LOGNAME" "$esphomeDir"; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to set ownership of $esphomeDir to $USER.${COL_DEF}"
      return 1
    fi
    
    echo "$(timestamp) [openHABian] Creating directory at $esphomeConfigDir and set permissions"
    if ! mkdir -p "$esphomeConfigDir"; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to create $esphomeConfigDir${COL_DEF}"
      return 1
    fi
    if ! chown -R "$LOGNAME:$LOGNAME" "$esphomeConfigDir"; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to set ownership of $esphomeConfigDir to $USER.${COL_DEF}"
      return 1
    fi
    
    echo "$(timestamp) [openHABian] Setting up a virtual environment ($esphomeDir) and install ESPHome Device Builder"
    if ! python3 -m venv venv "$esphomeDir/venv"; then
      echo "$(timestamp) [openHABian] ${COL_RED}Error: Failed to create a Python virtual environment ($esphomeDir).${COL_DEF}"
      return 1
    fi
    
    echo "$(timestamp) [openHABian] Activating the virtual environment."
    # the following shellcheck is neccesary because of error SC1091
    # shellcheck source=/dev/null
    if ! source "$esphomeDir/venv/bin/activate"; then
      echo "$(timestamp) [openHABian] ${COL_RED}Error: Failed to activate the Python virtual environment.${COL_DEF}"
      return 1
    fi
    
    echo "$(timestamp) [openHABian] installing ESPHome Device Builder. This could take a few minutes!"
    if ! pip3 install esphome; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to install ESPHome Device Builder.${COL_DEF}"
      return 1
    fi
      
    echo "$(timestamp) [openHABian] Installing systemd service file..."
    if ! SILENT=1 cond_redirect install -m 755 "$serviceTemplate" /etc/systemd/system/esphome-device-builder.service; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to install systemd service file.${COL_DEF}"
      return 1
    fi

    echo "$(timestamp) [openHABian] modifying systemd service file..."
    # Use + as separator in sed instead of / because in the path are / included
    if ! sed -i "s+<username>+$LOGNAME+g; s+<esphome-directory>+$esphomeDir+g; s+<esphome-config-directory>+$esphomeConfigDir+g; s+# dynamically replaced in script++g" /etc/systemd/system/esphome-device-builder.service; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to modify systemd service file.${COL_DEF}"  
      return 1
    fi
    
    echo "$(timestamp) [openHABian] Reloading systemd daemon and starting the ESPHome Device Builder service..."
    if ! SILENT=1 cond_redirect systemctl daemon-reload; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to reload systemd daemon.${COL_DEF}"
      return 1
    fi
    
    echo "$(timestamp) [openHABian] Enabling and starting the ESPHome Device Builder service..."
    if ! SILENT=1 cond_redirect systemctl enable --now esphome-device-builder.service; then
      echo -e"$(timestamp) [openHABian] ${COL_RED}Error: Failed to enable and start ESPHome Device Builder service.${COL_DEF}"
      return 1
    fi
      
    echo -e "$(timestamp) [openHABian] ${COL_GREEN}$installEndText${COL_DEF}"
    echo -e "$(timestamp) [openHABian] ${COL_GREEN}$portText${COL_DEF}";
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "$whiptailTitle" --msgbox "$installEndText\n$portText" 8 60
    fi
  
  elif [ "$setupMode" = "update" ] ; then
    echo "$(timestamp) [openHABian] $updateStartText";
    echo "$(timestamp) [openHABian] Activating the virtual environment."
    # the following shellcheck is neccesary because of error SC1091
    # shellcheck source=/dev/null
    if ! source "$esphomeDir/venv/bin/activate"; then
      echo "$(timestamp) [openHABian] ${COL_RED}Error: Failed to activate thr Python virtual environment.${COL_DEF}"
      return 1
    fi

    echo "$(timestamp) [openHABian] updating ESPHome Device Builder..."
    if ! pip3 install esphome -U; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to update ESPHome Device Builder.${COL_DEF}"
      return 1
    fi

    echo -e "$(timestamp) [openHABian] ${COL_GREEN}$updateEndText${COL_DEF}"
    echo -e "$(timestamp) [openHABian] ${COL_GREEN}$portText${COL_DEF}";
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "$whiptailTitle" --msgbox "$updateEndText\n$portText" 8 60
    fi
  
  elif [ "$setupMode" = "remove" ] ; then
    echo "$(timestamp) [openHABian] $uninstallStartText"
      
    # Check if the esphome-device-builder.service is active. If YES stop and disable the service
    # This check is neccesary to prevent a failure after an unsucsessful instalation
    if systemctl is-active --quiet esphome-device-builder.service; then
      echo "$(timestamp) [openHABian] Stopping the ESPHome Device Builder service."
      if ! SILENT=1 cond_redirect systemctl stop esphome-device-builder.service; then 
        echo "$(timestamp) [openHABian] ${COL_RED}Error: Failed to stop ESPHome Device Builder service.${COL_DEF}"
        return 1
      fi

      echo "$(timestamp) [openHABian] Disabling the ESPHome Device Builder service."
      if ! SILENT=1 cond_redirect systemctl disable esphome-device-builder.service; then
        echo "$(timestamp) [openHABian] ${COL_RED}Error: Failed to disable ESPHome Device Builder service.${COL_DEF}"
        return 1
      fi
    fi

    echo "$(timestamp) [openHABian] Removing the ESPHome Device Builder systemd service file."
    if ! SILENT=1 cond_redirect rm -f /etc/systemd/system/esphome-device-builder.service; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to remove the ESPHome Device Builder systemd service file.${COL_DEF}"
      return 1
    fi

    echo "$(timestamp) [openHABian] Reloading systemd daemon."
    if ! SILENT=1 cond_redirect systemctl daemon-reload; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to reload systemd daemon.${COL_DEF}"
      return 1
    fi

    echo "$(timestamp) [openHABian] Removing ESPHome Device Builder directory at $esphomeDir."
    if ! rm -rf "$esphomeDir"; then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to remove ESPHome Device Builder directory at $esphomeDir.${COL_DEF}"
      return 1
    fi

    echo "$(timestamp) [openHABian] Removing ESPHome Device Builder build directory at $esphomeConfigDir..."
    if ! (rm -rf "$esphomeConfigDir/.esphome/" && rm -f "$esphomeConfigDir/.gitignore"); then
      echo -e "$(timestamp) [openHABian] ${COL_RED}Error: Failed to remove ESPHome Device Builder build folders at $esphomeConfigDir.${COL_DEF}"
      return 1
    fi
    echo "$(timestamp) [openHABian] ESPHome Device Builder config files are still available: $esphomeConfigDir"

    echo -e "$(timestamp) [openHABian] ${COL_GREEN}ESPHome Device Builder uninstallation complete!${COL_DEF}"
      if [[ -n $INTERACTIVE ]]; then
        whiptail --title "$whiptailTitle" --msgbox "$uninstallEndText" 8 60
      fi
  else
    echo "$(timestamp) [openHABian] ${COL_RED}An unknown parameter was sent by menu.bash${COL_DEF}"
    return 1
  fi

  echo "$(timestamp) [openHABian] ##########################################################################################################"
}

## Function for (un)installing Grott proxy server on the current system
## Valid arguments: "install" or "remove"
##
##   install_grott(String install|remove)
##
install_grott() {
  echo "$(timestamp) [openHABian] Setup Grott proxy... "

  # Skip setup if in un-attended mode and openhabian.config grottSetupEnabled is missing or not true
  if [[ -n "$UNATTENDED" ]] && [[ "$grottSetupEnabled" != "true" ]]; then
    echo "SKIPPED (setup not enabled)"
    return 0
  fi

  # Validate install type argument
  if [ "$#" -lt 1 ]; then
    echo "FAILED (missing install type - usage: $0 <install|remove>)"
    return 1
  elif [[ "$1" != "install" && "$1" != "remove" ]]; then
    echo "FAILED (invalid install type $1 - usage: $0 <install|remove>)"
    return 1
  fi
  local installType="$1"

  # Constants for local system
  local grottFolder="/home/${username:-openhabian}/grott"
  local iniName="grott.ini"
  local serviceName="grott.service"
  local iniFile="${grottFolder}/${iniName}"
  local serviceFile="/etc/systemd/system/${serviceName}"
  local iniTemplate="${BASEDIR:-/opt/openhabian}/includes/${iniName}"
  local serviceTemplate="${BASEDIR:-/opt/openhabian}/includes/${serviceName}"
  local runScript="grott.py"

  # Constants for Grott GitHub files
  local grottSourceUrl="https://raw.githubusercontent.com/johanmeijer/grott/master"
  local grottSourceFiles=(
      "grott.py"
      "grottconf.py"
      "grottdata.py"
      "grottproxy.py"
      "grottserver.py"
      "grottsniffer.py"
    )
  local grottExtUrl="${grottSourceUrl}/examples/Extensions"
  local grottExtFile="grottext.py"

  ## Install Grott proxy
  if [[ $installType == "install" ]]; then
    echo "$(timestamp) [openHABian] Installing Grott proxy... "

    # Get default IPv4 address
    local ipAddress
    ipAddress="$(ip route get 8.8.8.8 | awk '{print $7}' | xargs)"
    if ! [[ "$ipAddress" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "FAILED (invalid ip address ${ipAddress})"
        return 1
    fi
    local extUrl="http://${ipAddress}:8080/growatt"

    # Update system and install dependencies. NOTE: paho-mqtt is a required dependency (even if disabled)
    if ! cond_redirect apt-get update; then echo "FAILED (apt update)"; return 1; fi
    if ! cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" python3 python3-pip python3-paho-mqtt python3-requests; then echo "FAILED (install Python or dependencies)"; return 1; fi

    # Prepare Grott folder
    if ! cond_redirect mkdir -p "$grottFolder"; then echo "FAILED (create ${grottFolder})"; return 1; fi
    if ! cond_redirect chown -R "${username:-openhabian}" "$grottFolder"; then echo "FAILED (chown ${grottFolder})"; return 1; fi
    if ! cond_redirect chmod -R 755 "$grottFolder"; then echo "FAILED (chmod ${grottFolder})"; return 1; fi

    # Download Grott Python files into Grott folder
    local src tgt
    for file in "${grottSourceFiles[@]}"; do
      src="${grottSourceUrl}/${file}"
      tgt="${grottFolder}/${file}"
      curl -fsSL "${src}" -o "${tgt}" || {
        echo "FAILED (download ${file})"
        return 1
      }
    done

    # Download Grott extension file into Grott folder
    src="${grottExtUrl}/${grottExtFile}"
    tgt="${grottFolder}/${grottExtFile}"
    curl -fsSL "${src}" -o "${tgt}" || {
      echo "FAILED (download ${grottExtFile})"
      return 1
    }

    # Create grott.ini configuration in Grott folder by modifying the template
    if ! sed \
      -e "s|%URL|$extUrl|g" \
      "$iniTemplate" > "$iniFile"; then
        echo "FAILED (configure ${iniName})"
        return 1
    fi

     # Create grott.service configuration in systemd folder by modifying the template
    if ! sed \
      -e "s|%USERNAME|${username:-openhabian}|g" \
      -e "s|%DIRECTORY|$grottFolder|g" \
      -e "s|%RUNSCRIPT|$runScript|g" \
      "$serviceTemplate" > "$serviceFile"; then
        echo "FAILED (configure ${serviceName})"
        return 1
    fi

    # Enable and start Grott service
    if ! cond_redirect systemctl enable --now "${serviceName}"; then echo "FAILED (enable ${serviceName})"; return 1; fi

    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Grott Proxy Installed" --msgbox "We installed Grott proxy on your system." 7 80
    fi
  fi

  ## Remove Grott proxy
  if [[ $installType == "remove" ]]; then
    echo "$(timestamp) [openHABian] Removing Grott Proxy... "

    # Stop and disable systemd service
    if ! cond_redirect systemctl disable --now "${serviceName}"; then echo "FAILED (disable ${serviceName})"; return 1; fi
    cond_redirect systemctl daemon-reload

    # Remove systemd service file
    if ! cond_redirect rm -f "$serviceFile"; then echo "FAILED (remove ${serviceFile})"; return 1; fi

    # Remove Grott folder
    if ! cond_redirect rm -rf "$grottFolder"; then echo "FAILED (remove ${grottFolder})"; return 1; fi

    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Grott Proxy Removed" --msgbox "We removed Grott proxy from your system." 7 80
    fi
  fi

  echo "OK"
  return 0
}
