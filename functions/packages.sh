#!/usr/bin/env bash

samba_setup() {
  echo -n "$(timestamp) [openHABian] Setting up Samba network shares... "
  if ! command -v samba &>/dev/null; then
    cond_redirect apt update
    cond_redirect apt -y install samba
    if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  fi
  cond_echo "Copying over custom 'smb.conf'... "
  cp $BASEDIR/includes/smb.conf /etc/samba/smb.conf
  cond_echo "Writing authentication data to openHABian default... "
  if ! /usr/bin/smbpasswd -e $username &>/dev/null; then
    ( (echo "$userpw"; echo "$userpw") | /usr/bin/smbpasswd -s -a $username > /dev/null )
  fi
  cond_redirect systemctl enable smbd.service
  cond_redirect systemctl restart smbd.service
  echo "OK"
}

firemotd_setup() {
  echo -n "$(timestamp) [openHABian] Downloading and setting up FireMotD... "
  cond_redirect apt update
  cond_redirect apt -y install bc sysstat jq moreutils
  rm -rf /opt/FireMotD
  cond_redirect git clone https://github.com/willemdh/FireMotD.git /opt/FireMotD
  if [ $? -eq 0 ]; then
    # the following is already in bash_profile by default
    #echo -e "\necho\n/opt/FireMotD/FireMotD -HV --theme gray \necho" >> /home/$username/.bash_profile
    # initial apt updates check
    cond_redirect /bin/bash /opt/FireMotD/FireMotD -S
    # invoke apt updates check every night
    echo "# FireMotD system updates check (randomly execute between 0:00:00 and 5:59:59)" > /etc/cron.d/firemotd
    echo "0 0 * * * root perl -e 'sleep int(rand(21600))' && /bin/bash /opt/FireMotD/FireMotD -S &>/dev/null" >> /etc/cron.d/firemotd
    # invoke apt updates check after every apt action ('apt upgrade', ...)
    echo "DPkg::Post-Invoke { \"if [ -x /opt/FireMotD/FireMotD ]; then echo -n 'Updating FireMotD available updates count ... '; /bin/bash /opt/FireMotD/FireMotD --skiprepoupdate -S; echo ''; fi\"; };" > /etc/apt/apt.conf.d/15firemotd
    echo "OK"
  else
    echo "FAILED"
  fi
}

etckeeper_setup() {
  echo -n "$(timestamp) [openHABian] Installing etckeeper (git based /etc backup)... "
  apt -y install etckeeper &>/dev/null
  if [ $? -eq 0 ]; then
    cond_redirect sed -i 's/VCS="bzr"/\#VCS="bzr"/g' /etc/etckeeper/etckeeper.conf
    cond_redirect sed -i 's/\#VCS="git"/VCS="git"/g' /etc/etckeeper/etckeeper.conf
    cond_redirect bash -c "cd /etc && etckeeper init && git config user.email 'etckeeper@localhost' && git config user.name 'openhabian' && git commit -m 'initial checkin' && git gc"
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
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
To continue your integration in openHAB 2, please follow the instructions under: http://docs.openhab.org/addons/bindings/homematic/readme.html
"

  if is_pine64; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "We are sorry, Homegear is not yet available for your platform." 10 60
    fi
    echo "FAILED (incompatible)"; return 1
  fi

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up the Homematic CCU2 emulation software Homegear... "
  cond_redirect wget -O - http://homegear.eu/packages/Release.key | apt-key add -
  echo "deb https://homegear.eu/packages/Raspbian/ jessie/" > /etc/apt/sources.list.d/homegear.list
  cond_redirect apt update
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt -y install homegear homegear-homematicbidcos homegear-homematicwired
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect systemctl enable homegear.service
  cond_redirect systemctl start homegear.service
  cond_redirect adduser $username homegear
  echo "OK"

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

mqtt_setup() {
  FAILED=0
  introtext="The MQTT broker Eclipse Mosquitto will be installed through the official repository, as desribed at: https://mosquitto.org/2013/01/mosquitto-debian-repository \nAdditionally you can activate username:password authentication."
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.
Eclipse Mosquitto is now up and running in the background. You should be able to make a first connection.
To continue your integration in openHAB 2, please follow the instructions under: http://docs.openhab.org/addons/bindings/mqtt1/readme.html
"
  echo -n "$(timestamp) [openHABian] Setting up the MQTT broker Eclipse Mosquitto... "

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  mqttuser="openhabian"
  question="Do you want to secure your MQTT broker by a username:password combination? Every client will need to provide these upon connection.\nUsername will be '$mqttuser', please provide a password (consisting of ASCII printable characters except space). Leave blank for no authentication, run method again to change."
  mqttpasswd=$(whiptail --title "MQTT Authentication" --inputbox "$question" 15 80 3>&1 1>&2 2>&3)
  if is_jessie; then
    cond_redirect wget -O - http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | apt-key add -
    echo "deb http://repo.mosquitto.org/debian jessie main" > /etc/apt/sources.list.d/mosquitto-jessie.list
  fi
  cond_redirect apt update
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt -y install mosquitto mosquitto-clients
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  if [ "$mqttpasswd" != "" ]; then
    if ! grep -q "password_file /etc/mosquitto/passwd" /etc/mosquitto/mosquitto.conf; then
      echo -e "\npassword_file /etc/mosquitto/passwd\nallow_anonymous false\n" >> /etc/mosquitto/mosquitto.conf
    fi
    echo -n "" > /etc/mosquitto/passwd
    cond_redirect mosquitto_passwd -b /etc/mosquitto/passwd $mqttuser $mqttpasswd
    if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  else
    cond_redirect sed -i "/password_file/d" /etc/mosquitto/mosquitto.conf
    cond_redirect sed -i "/allow_anonymous/d" /etc/mosquitto/mosquitto.conf
    cond_redirect rm -f /etc/mosquitto/passwd
  fi
  cond_redirect systemctl enable mosquitto.service
  cond_redirect systemctl restart mosquitto.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

find_setup() {
  FAILED=0
  introtext="This will install and setup the FIND server system to allow for indoor localization of WiFi devices.\nSee further information at
 http://www.internalpositioning.com/"
  failtext="Sadly there was a problem setting up the selected option.\nPlease report this problem in the openHAB community forum or as a open
HABian GitHub issue."
  successtext="Setup was successful. Please edit '/etc/default/findserver' to meet your interface and server requirements."

  echo -n "$(timestamp) [openHABian] Setting up the Framework for Internal Navigation and Discovery ... "
  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  FIND_RELEASE=2.4.1
  CLIENT_RELEASE=0.6
  if is_arm; then
    ARCH=arm
  else
    ARCH=amd64
  fi
  FIND_SRC=https://github.com/schollz/find/releases/download/v${FIND_RELEASE}/find_${FIND_RELEASE}_linux_${ARCH}.zip
  CLIENT_SRC=https://github.com/schollz/find/releases/download/v${CLIENT_RELEASE}client/fingerprint_${CLIENT_RELEASE}_linux_${ARCH}.zip

  FIND_SYSTEMCTL=/etc/systemd/system/findserver.service
  FIND_DEFAULT=/etc/default/findserver
  FIND_DSTDIR=/var/lib/findserver
  MOSQUITTO_PASSWD=/etc/mosquitto/passwd
  DEFAULTFINDUSER=find
  DEFAULTFINDPASS=cantfind
  FIND_TMP=/tmp/find-latest.$$
  CLIENT_TMP=/tmp/fingerprint-latest.$$

  if [ ! -f ${MOSQUITTO_PASSWD} ]; then
    if ! (whiptail --title "Mosquitto not installed, continue?" --yes-button "Continue" --no-button "Back" --yesno "FIND requires a MQTT broker to run, but Mosquitto is not installed on this box.\nYou can configure FIND to use any existing MQTT broker or you can go back and install Mosquitto from the openHABian menu.\nDo you want to continue with the FIND installation ?" 15 80) then return 0; fi
  fi

  /bin/mkdir -p ${FIND_DSTDIR}
  /usr/bin/wget -O ${FIND_TMP} ${FIND_SRC}
  /usr/bin/wget -O ${CLIENT_TMP} ${CLIENT_SRC}
  /usr/bin/unzip ${CLIENT_TMP} fingerprint -d ${FIND_DSTDIR}
  /usr/bin/unzip ${FIND_TMP} -d ${FIND_DSTDIR}
  /bin/ln -s ${FIND_DSTDIR}/findserver /usr/sbin/findserver
  /bin/ln -s ${FIND_DSTDIR}/fingerprint /usr/sbin/fingerprint

  FINDSERVER=$(whiptail --title "FIND Setup" --inputbox "Enter hostname that your FIND server will be listening to:" 15 80 localhost 3>&1 1>&2 2>&3)
  FINDPORT=$(whiptail --title "FIND Setup" --inputbox "Enter port no. that you want to run FIND server on:" 15 80 8003 3>&1 1>&2 2>&3)
  MQTTSERVER=$(whiptail --title "FIND Setup" --inputbox "Enter hostname that your MQTT broker is running on:" 15 80 localhost 3>&1 1>&2 2>&3)
  MQTTPORT=$(whiptail --title "FIND Setup" --inputbox "Enter port no. that your MQTT broker is running on:" 15 80 1883 3>&1 1>&2 2>&3)

  if [ -f ${MOSQUITTO_PASSWD} ]; then
    FINDADMIN=$(whiptail --title "findserver MQTT Setup" --inputbox "Enter a username for FIND to use as the admin user on your MQTT broker:" 15 80 $DEFAULTFINDUSER 3>&1 1>&2 2>&3)
    FINDADMINPASS=$(whiptail --title "findserver MQTT Setup" --passwordbox "Enter a password for the FIND admin user on your MQTT broker:" 15 80 $DEFAULTFINDPASS 3>&1 1>&2 2>&3)
    cond_redirect /usr/bin/mosquitto_passwd -b ${MOSQUITTO_PASSWD} ${FINDADMIN} ${FINDADMINPASS} || FAILED=1
    if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  fi
  /bin/sed -e "s|%MQTTSERVER|${MQTTSERVER}|g" -e "s|%MQTTPORT|${MQTTPORT}|g" -e "s|%FINDADMIN|${FINDADMIN}|g" -e "s|%FINDADMINPASS|${FINDADMIN_PASS}|g" -e "s|%FINDPORT|${FINDPORT}|g" -e "s|%FINDSERVER|${FINDSERVER}|g" ${BASEDIR}/includes/findserver.service >${FIND_SYSTEMCTL}
  /bin/sed -e "s|%MQTTSERVER|${MQTTSERVER}|g" -e "s|%MQTTPORT|${MQTTPORT}|g" -e "s|%FINDPORT|${FINDPORT}|g" -e "s|%FINDSERVER|${FINDSERVER}|g" ${BASEDIR}/includes/findserver >${FIND_DEFAULT}


  /bin/rm -f ${FIND_TMP} ${CLIENT_TMP}
  cond_redirect /bin/systemctl enable findserver.service || FAILED=1
  cond_redirect /bin/systemctl restart findserver.service || FAILED=1
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
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

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up EIB/KNX IP Gateway and Router with knxd "
  echo -n "(http://michlstechblog.info/blog/raspberry-pi-eibknx-ip-gateway-and-router-with-knxd)... "
  #TODO serve file from the repository
  cond_redirect wget -O /tmp/install_knxd_systemd.sh http://michlstechblog.info/blog/download/electronic/install_knxd_systemd.sh || FAILED=1
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
  introtext="This will install owserver to support 1wire functionality in general, ow-shell and usbutils are helpfull tools to check USB (lsusb) and 1wire function (owdir, owread). For more details, have a look at http://owfs.com"
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

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo -n "$(timestamp) [openHABian] Installing owserver (1wire)... "
  cond_redirect apt -y install owserver ow-shell usbutils || FAILED=1
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
  introtext="This will install or update miflora-mqtt-daemon - The Xiaomi Mi Flora Plant Sensor MQTT Client/Daemon. See for further details:\n\n   https://github.com/ThomDietrich/miflora-mqtt-daemon"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.
The Daemon was installed and the systemd service was set up just as described in it's README. Please add your MQTT broker settings in '$DIRECTORY/config.ini' and add your Mi Flora sensors. After that be sure to restart the daemon to reload it's configuration.
\nAll details can be found under: https://github.com/ThomDietrich/miflora-mqtt-daemon
The article also contains instructions regarding openHAB integration.
"

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up miflora-mqtt-daemon... "
  cond_redirect apt -y install git python3 python3-pip bluetooth bluez
  if [ $FAILED -ne 0 ]; then echo "FAILED (prerequisites)"; exit 1; fi
  if [ ! -d "$DIRECTORY" ]; then
    cond_echo "Fresh Installation... "
    cond_redirect git clone https://github.com/ThomDietrich/miflora-mqtt-daemon.git $DIRECTORY
    cond_redirect cp $DIRECTORY/config.{ini.dist,ini}
    if [ $FAILED -ne 0 ]; then echo "FAILED (git clone)"; exit 1; fi
  else
    cond_echo "Update... "
    cond_redirect git -C $DIRECTORY pull --quiet origin
    if [ $FAILED -ne 0 ]; then echo "FAILED (git pull)"; exit 1; fi
  fi
  cond_redirect chown -R openhab:$username $DIRECTORY
  cond_redirect chmod -R ug+wX $DIRECTORY
  cond_redirect pip3 install -r $DIRECTORY/requirements.txt
  if [ $FAILED -ne 0 ]; then echo "FAILED (requirements)"; exit 1; fi
  cond_redirect cp $DIRECTORY/template.service /etc/systemd/system/miflora.service
  cond_redirect systemctl daemon-reload
  systemctl start miflora.service || true
  cond_redirect systemctl status miflora.service
  cond_redirect systemctl enable miflora.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
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

influxdb_grafana_setup() {
  FAILED=0
  introtext="This will install InfluxDB and Grafana. Soon this procedure will also set up the connection between them and with openHAB. For now, please follow the instructions found here:
  \nhttps://community.openhab.org/t/13761/1"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup successful. Please continue with the instructions you can find here:\n\nhttps://community.openhab.org/t/13761/1"

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  cond_redirect apt -y install apt-transport-https
  echo -n "$(timestamp) [openHABian] Setting up InfluxDB and Grafana... "
  cond_echo ""
  echo -n "InfluxDB... "
  cond_redirect wget -O - https://repos.influxdata.com/influxdb.key | apt-key add - || FAILED=1
  echo "deb https://repos.influxdata.com/debian jessie stable" > /etc/apt/sources.list.d/influxdb.list || FAILED=1
  cond_redirect apt update || FAILED=1
  cond_redirect apt -y install influxdb || FAILED=1
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable influxdb.service
  cond_redirect systemctl start influxdb.service
  if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
  cond_echo ""

  echo -n "Grafana... "
  if is_pi; then
    if is_pione || is_pizero || is_pizerow; then GRAFANA_REPO_PI1="-rpi-1b"; fi
    echo "deb https://dl.bintray.com/fg2it/deb${GRAFANA_REPO_PI1} jessie main" > /etc/apt/sources.list.d/grafana-fg2it.list || FAILED=2
    cond_redirect apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 379CE192D401AB61 || FAILED=2
  else
    cond_redirect wget -O - https://packagecloud.io/gpg.key | apt-key add - || FAILED=2
    echo "deb https://packagecloud.io/grafana/stable/debian/ jessie main" > /etc/apt/sources.list.d/grafana.list || FAILED=2
  fi
  cond_redirect apt update || FAILED=2
  cond_redirect apt -y install grafana || FAILED=2
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable grafana-server.service
  cond_redirect systemctl start grafana-server.service
  if [ $FAILED -eq 2 ]; then echo -n "FAILED "; else echo -n "OK "; fi
  cond_echo ""

  echo -n "Connecting (TODO)... "
  #TODO

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

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  function comment {
    sed -i "$1"' s/^/#/' "$2"
  }
  function uncomment {
    sed -i "$1"' s/^ *#//' "$2"
  }

  echo "Installing DNS utilities..."
  apt -y -q install dnsutils

  AUTH=false
  SECURE=false
  VALIDDOMAIN=false
  matched=false
  canceled=false
  FAILED=false

  if (whiptail --title "Authentication Setup" --yesno "Would you like to secure your openHAB interface with username and password?" 15 80) then
    username=$(whiptail --title "Authentication Setup" --inputbox "Enter a username to sign into openHAB:" 15 80 openhab 3>&1 1>&2 2>&3)
    if [ $? = 0 ]; then
      while [ "$matched" = false ] && [ "$canceled" = false ]; do
        password=$(whiptail --title "Authentication Setup" --passwordbox "Enter a password for $username:" 15 80 3>&1 1>&2 2>&3)
        secondpassword=$(whiptail --title "Authentication Setup" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
        if [ "$password" = "$secondpassword" ] && [ ! -z "$password" ]; then
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

  while [ "$VALIDDOMAIN" = false ] && [ ! -z "$domain" ] && [ "$domain" != "IP" ]; do
    echo -n "Obtaining domain IP address... "
    domainip=$(dig +short $domain |tail -1)
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
    authtext="Authentication Enabled\n- Username: $username"
  else
    authtext="Authentication Disabled"
  fi

  if [ "$SECURE" = true ]; then
    httpstext="Proxy will be secured by HTTPS"
    protocol="HTTPS"
    portwarning="Important! Before you continue, please make sure that port 80 (HTTP) of this machine is reachable from the internet (portforwarding, ...). Otherwise the certbot connection test will fail.\n\n"
  else
    httpstext="Proxy will not be secured by HTTPS"
    protocol="HTTP"
    portwarning=""
  fi

  confirmtext="The following settings have been chosen:\n\n- $authtext\n- $httpstext\n- Domain: $domain (Public IP Address: $wanip)
  \nYou will be able to connect to openHAB on the default $protocol port.
  \n${portwarning}Do you wish to continue and setup an NGINX server now?"

  if (whiptail --title "Confirmation" --yesno "$confirmtext" 22 80) then
    echo "Installing NGINX..."
    apt -y -q install nginx || FAILED=true

    rm -rf /etc/nginx/sites-enabled/default
    cp $BASEDIR/includes/nginx.conf /etc/nginx/sites-enabled/openhab

    sed -i "s/DOMAINNAME/${domain}/g" /etc/nginx/sites-enabled/openhab

    if [ "$AUTH" = true ]; then
      echo "Installing password utilities..."
      apt -y -q install apache2-utils || FAILED=true
      echo "Creating password file..."
      htpasswd -b -c /etc/nginx/.htpasswd $username $password
      uncomment 32,33 /etc/nginx/sites-enabled/openhab
    fi

    if [ "$SECURE" = true ]; then
      if [ "$VALIDDOMAIN" = true ]; then
        echo -e "# This file was added by openHABian to install certbot\ndeb http://ftp.debian.org/debian jessie-backports main" > /etc/apt/sources.list.d/backports.list
        gpg --keyserver pgpkeys.mit.edu --recv-key 8B48AD6246925553
        gpg -a --export 8B48AD6246925553 | apt-key add -
        gpg --keyserver pgpkeys.mit.edu --recv-key 7638D0442B90D010
        gpg -a --export 7638D0442B90D010 | apt-key add -
        apt update
        echo "Installing certbot..."
        apt -y -q --force-yes install certbot -t jessie-backports
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
