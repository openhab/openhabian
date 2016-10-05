#!/usr/bin/env bash

# openHABian - hassle-free openHAB 2 installation and configuration tool
# for the Raspberry Pi and other Linux systems
#
# https://community.openhab.org/t/openhabian-hassle-free-rpi-image/13379
# https://github.com/ThomDietrich/openhabian
#
# 2016 Thomas Dietrich
#

# Find the absolute script location dir
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$SCRIPTDIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Colors for later use
ESC="\033["
COL_DEF=$ESC"39;49;00m"
COL_RED=$ESC"31;01m"
COL_GREEN=$ESC"32;01m"
COL_YELLOW=$ESC"33;01m"
COL_BLUE=$ESC"34;01m"
COL_MAGENTA=$ESC"35;01m"
COL_CYAN=$ESC"36;01m"
COL_LGRAY=$ESC"37;01m"
COL_DGRAY=$ESC"90;01m"

# Trap CTRL+C, CTRL+Z and quit singles
trap '' SIGINT SIGQUIT SIGTSTP

# Make sure only root can run our script
echo -n "[openHABian] Checking for root privileges... "
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
else
  echo "OK"
fi

# script will be called with 'unattended' argument by post-install.txt
if [[ "$1" = "unattended" ]]
then
  UNATTENDED=1
  SILENT=1
else
  INTERACTIVE=1
fi

cond_redirect() {
  if [ -n "$SILENT" ]; then
    "$@" &>/dev/null
    return $?
  else
    echo -e "\n$COL_DGRAY\$ $@ $COL_DEF"
    "$@"
    return $?
  fi
}

cond_echo() {
  if [ -z "$SILENT" ]; then
    echo -e "\n$COL_YELLOW$@$COL_DEF"
  fi
}

hightlight() {
  echo -e "$COL_LGRAY$@$COL_DEF"
}

# Shamelessly taken from https://github.com/RPi-Distro/raspi-config/blob/bd21dedea3c9927814cf4f0438e116c6a31181a9/raspi-config#L11-L66
# SNIP
is_pione() {
  if grep -q "^Revision\s*:\s*00[0-9a-fA-F][0-9a-fA-F]$" /proc/cpuinfo; then
    return 0
  elif  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[0-36][0-9a-fA-F]$" /proc/cpuinfo ; then
    return 0
  else
    return 1
  fi
}
is_pitwo() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]04[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pithree() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]08[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pizero() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]09[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
get_pi_type() {
  if is_pione; then
    echo 1
  elif is_pitwo; then
    echo 2
  elif is_pithree; then
    echo 3
  else
    echo 0
  fi
}
get_init_sys() {
  if command -v systemctl > /dev/null && systemctl | grep -q '\-\.mount'; then
    SYSTEMD=1
  elif [ -f /etc/init.d/cron ] && [ ! -h /etc/init.d/cron ]; then
    SYSTEMD=0
  else
    echo "Unrecognised init system"
    return 1
  fi
}
calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error
  # output from tput. However in this case, tput detects neither stdout or
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=22
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}
# SNAP

locale_timezone_settings() {
  echo -n "[openHABian] Setting timezone (Europe/Berlin) and locale (en_US.UTF-8)... "
  ## timezone
  cond_redirect echo "Europe/Berlin" > /etc/timezone
  cond_redirect rm /etc/localtime
  cond_redirect ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
  ## locale
  sed -i 's/\# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
  sed -i 's/\# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/g' /etc/locale.gen
  cond_redirect /usr/sbin/locale-gen
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect /usr/sbin/update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

first_boot_script() {
  echo -n "[openHABian] Activating first boot script... "
  # make green LED blink as heartbeat on finished first boot
  cp $SCRIPTDIR/includes/rc.local /etc/rc.local
  echo "OK"
}

memory_split() {
  echo -n "[openHABian] Setting the GPU memory split down to 16MB for headless system... "
  if grep -q "gpu_mem" /boot/config.txt; then
    sed -i 's/gpu_mem=.*/gpu_mem=16/g' /boot/config.txt
  else
    echo "gpu_mem=16" >> /boot/config.txt
  fi
  echo "OK"
}

basic_packages() {
  echo -n "[openHABian] Installing basic can't-be-wrong packages (screen, vim, ...)... "
  cond_redirect apt -y install screen vim nano mc vfu bash-completion htop curl wget multitail git bzip2 zip unzip xz-utils software-properties-common
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect wget -O /usr/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

needed_packages() {
  # install raspi-config - configuration tool for the Raspberry Pi + Raspbian
  # install apt-transport-https - update packages through https repository (https://openhab.ci.cloudbees.com/...)
  # install samba - network sharing
  # install bc + sysstat - needed for FireMotD
  # install avahi-daemon - hostname based discovery on local networks
  echo -n "[openHABian] Installing additional needed packages... "
  cond_redirect apt -y install raspi-config oracle-java8-jdk apt-transport-https samba bc sysstat avahi-daemon
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

bashrc_copy() {
  echo -n "[openHABian] Adding slightly tuned bash config files to system... "
  cp $SCRIPTDIR/includes/bash.bashrc /etc/bash.bashrc
  cp $SCRIPTDIR/includes/bashrc-root /root/.bashrc
  cp $SCRIPTDIR/includes/bash_profile /home/pi/.bash_profile
  chown pi:pi /home/pi/.bash_profile
  echo "OK"
}

vimrc_copy() {
  echo -n "[openHABian] Adding slightly tuned vim config file to system... "
  cp $SCRIPTDIR/includes/vimrc /etc/vim/vimrc.local
  echo "OK"
}

java_webupd8_prepare() {
  # prepare (not install) Oracle Java 8 newest revision
  echo -n "[openHABian] Preparing Oracle Java 8 Web Upd8 repository... "
  rm -f /etc/apt/sources.list.d/webupd8team-java.list
  echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list.d/webupd8team-java.list
  echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list.d/webupd8team-java.list
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  cond_redirect apt update
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

java_webupd8_install() {
  # do not execute inside raspbian-ua-netinst chroot environment!
  # FAILS with "readelf: Error: '/proc/self/exe': No such file"
  echo -n "[openHABian] Installing Oracle Java 8 from Web Upd8 repository... "
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
  if [ $? -ne 0 ]; then echo "FAILED (debconf)"; exit 1; fi
  cond_redirect apt -y install oracle-java8-installer
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt -y install oracle-java8-set-default
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

# java_letsencrypt() {
#   # alternative to installing newest java revision through webupd8team repository, which is not working in chroot
#   echo -n "[openHABian] Adding letsencrypt certs to Oracle Java 8 keytool (needed for my.openhab)... "
#   FAILED=0
#   CERTS="isrgrootx1.der
#   lets-encrypt-x1-cross-signed.der
#   lets-encrypt-x2-cross-signed.der
#   lets-encrypt-x3-cross-signed.der
#   lets-encrypt-x4-cross-signed.der
#   letsencryptauthorityx1.der
#   letsencryptauthorityx2.der"
#   for cert in $CERTS
#   do
#     namewoext="${cert%%.*}"
#     wget "https://letsencrypt.org/certs/$cert" || ((FAILED++))
#     /usr/bin/keytool -importcert -keystore /usr/lib/jvm/jdk-8-oracle-arm32-vfp-hflt/jre/lib/security/cacerts \
#     -storepass changeit -noprompt -trustcacerts -alias $namewoext -file $cert || ((FAILED++))
#     rm -f $cert
#   done
#   if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
# }

# openhab2_user() {
#   echo -n "[openHABian] Manually adding openhab user to system (for manual installation?)... "
#   adduser --system --no-create-home --group --disabled-login openhab &>/dev/null
#   echo "OK"
# }

openhab2_addrepo() {
  echo -n "[openHABian] Adding openHAB 2 Snapshot repositories to sources.list.d... "
  rm -f /etc/apt/sources.list.d/openhab2.list
  echo "deb https://openhab.ci.cloudbees.com/job/openHAB-Distribution/ws/distributions/openhab-offline/target/apt-repo/ /" >> /etc/apt/sources.list.d/openhab2.list
  echo "deb https://openhab.ci.cloudbees.com/job/openHAB-Distribution/ws/distributions/openhab-online/target/apt-repo/ /" >> /etc/apt/sources.list.d/openhab2.list
  # out of an unclear reason, this is not working:
  #cond_redirect wget --retry-connrefused --tries=50 -O - http://www.openhab.org/keys/public-key-snapshots.asc | apt-key add -
  cond_redirect wget --retry-connrefused --tries=50 -O openhab-key.asc http://www.openhab.org/keys/public-key-snapshots.asc
  cond_redirect apt-key add openhab-key.asc
  rm -f openhab-key.asc
  cond_redirect apt update
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

openhab2_install() {
  echo -n "[openHABian] Installing openhab2-offline... "
  cond_redirect apt -y install openhab2-offline
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

openhab2_service() {
  echo -n "[openHABian] Activating openHAB... "
  cond_redirect systemctl daemon-reload
  #if [ $? -eq 0 ]; then echo -n "OK "; else echo -n "FAILED "; fi
  cond_redirect systemctl enable openhab2.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

vim_openhab_syntax() {
  echo -n "[openHABian] Adding openHAB syntax to vim editor... "
  # these may go to "/usr/share/vim/vimfiles" ?
  mkdir -p /home/pi/.vim/{ftdetect,syntax}
  cond_redirect wget -O /home/pi/.vim/syntax/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/syntax/openhab.vim
  cond_redirect wget -O /home/pi/.vim/ftdetect/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/ftdetect/openhab.vim
  chown -R pi:pi /home/pi/.vim
  echo "OK"
}

nano_openhab_syntax() {
  # add nano syntax highlighting
  echo -n "[openHABian] Adding openHAB syntax to nano editor... "
  cond_redirect wget -O /usr/share/nano/openhab.nanorc https://raw.githubusercontent.com/airix1/openhabnano/master/openhab.nanorc
  echo -e "\n## openHAB files\ninclude \"/usr/share/nano/openhab.nanorc\"" >> /etc/nanorc
  echo "OK"
}

samba_config() {
  echo -n "[openHABian] Modifying Samba config... "
  cp $SCRIPTDIR/includes/smb.conf /etc/samba/smb.conf
  echo "OK"
}

samba_user() {
  echo -n "[openHABian] Adding openhab as Samba user... "
  ( (echo "habopen"; echo "habopen") | /usr/bin/smbpasswd -s -a openhab > /dev/null )
  #( (echo "raspberry"; echo "raspberry") | /usr/bin/smbpasswd -s -a pi > /dev/null )
  chown -hR openhab:openhab /etc/openhab2
  echo "OK"
}

samba_activate() {
  echo -n "[openHABian] Activating Samba... "
  cond_redirect /bin/systemctl enable smbd.service
  echo "OK"
}

firemotd() {
  echo -n "[openHABian] Downloading FireMotD... "
  #git clone https://github.com/willemdh/FireMotD.git /opt/FireMotD &>/dev/null
  cond_redirect git clone -b issue-15 https://github.com/ThomDietrich/FireMotD.git /opt/FireMotD
  if [ $? -eq 0 ]; then
    # the following is already in there by default
    #echo -e "\necho\n/opt/FireMotD/FireMotD --theme gray \necho" >> /home/pi/.bashrc
    # apt updates check
    cond_redirect /opt/FireMotD/FireMotD -S
    # invoke apt updates check every night
    echo "3 3 * * * root /opt/FireMotD/FireMotD -S &>/dev/null" > /etc/cron.d/firemotd
    # invoke apt update check after "apt upgrade" was called
    # TODO testing needed
    # TODO seems to work but takes a long time that could irritate or annoy the user. run in background?
    echo "DPkg::Post-Invoke { \"if [ -x /opt/FireMotD/FireMotD ]; then echo -n 'Updating FireMotD available updates count... '; /opt/FireMotD/FireMotD -S; echo 'OK'; fi\"; };" > /etc/apt/apt.conf.d/15firemotd
    echo "OK"
  else
    echo "FAILED"
  fi
}

etckeeper() {
  echo -n "[openHABian] Installing etckeeper (git based /etc backup)... "
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

openhab_shell_interfaces() {
  echo -n "[openHABian] Binding the Karaf console on all interfaces... "
  cond_redirect sed -i "s/sshHost = 127.0.0.1/sshHost = 0.0.0.0/g" /usr/share/openhab2/runtime/karaf/etc/org.apache.karaf.shell.cfg
  #cond_redirect sed -i "s/\# keySize = 4096/\# keySize = 4096\nkeySize = 1024/g" /usr/share/openhab2/runtime/karaf/etc/org.apache.karaf.shell.cfg
  #cond_redirect rm -f /usr/share/openhab2/runtime/karaf/etc/host.key
  cond_redirect systemctl restart openhab2.service
  echo "OK"
}

wifi-setup-rpi3() {
  echo -n "[openHABian] Setting up RPi 3 Wifi... "
  if ! is_pithree ; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "Wifi setup: This option is for a Raspberry Pi 3 system only." 10 60
    fi
    echo "FAILED"
    return 1
  fi
  if [ -n "$INTERACTIVE" ]; then
    SSID=$(whiptail --title "Wifi Setup" --inputbox "Which Wifi (SSID) do you want to connect to?" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 1; fi
    PASS=$(whiptail --title "Wifi Setup" --inputbox "What's the password for that Wifi?" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 1; fi
  else
    echo -n "setting default SSID and password in 'wpa_supplicant.conf' "
    SSID="myWifiSSID"
    PASS="myWifiPassword"
  fi
  cond_redirect apt -y install firmware-brcm80211 wpasupplicant wireless-tools # pi-bluetooth
  echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\nnetwork={\n  ssid=\"$SSID\"\n  psk=\"$PASS\"\n}" > /etc/wpa_supplicant/wpa_supplicant.conf
  if grep -q "wlan0" /etc/network/interfaces; then
    cond_echo "Not writing to '/etc/network/interfaces', wlan0 entry already available. You might need to check, adopt or remove these lines."
  else
    echo -e "\nallow-hotplug wlan0\niface wlan0 inet manual\nwpa-roam /etc/wpa_supplicant/wpa_supplicant.conf\niface default inet dhcp" >> /etc/network/interfaces
  fi
  cond_redirect ifdown wlan0
  cond_redirect ifup wlan0
  echo "OK"
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

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 1; fi
  fi

  echo -n "[openHABian] Setting up the Homematic CCU2 emulation software Homegear... "
  cond_redirect wget -O - http://homegear.eu/packages/Release.key | apt-key add -
  echo "deb https://homegear.eu/packages/Raspbian/ jessie/" > /etc/apt/sources.list.d/homegear.list
  cond_redirect apt update
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt -y install homegear homegear-homematicbidcos homegear-homematicwired
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect systemctl enable homegear.service
  cond_redirect systemctl start homegear.service
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
  introtext="The MQTT broker software Mosquitto will be installed through the official repository, as desribed here: https://mosquitto.org/2013/01/mosquitto-debian-repository"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.
Mosquitto is now up and running in the background. You should now be able to make a first connection.
To continue your integration in openHAB 2, please follow the instructions under: https://github.com/openhab/openhab/wiki/MQTT-Binding
"

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 1; fi
  fi

  echo -n "[openHABian] Setting up the MQTT broker software Mosquitto... "
  cond_redirect wget -O - http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | apt-key add -
  echo "deb http://repo.mosquitto.org/debian jessie main" > /etc/apt/sources.list.d/mosquitto-jessie.list
  cond_redirect apt update
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt -y install mosquitto
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect systemctl enable mosquitto.service
  cond_redirect systemctl start mosquitto.service
  echo "OK"

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
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 1; fi
  fi

  echo -n "[openHABian] Setting up EIB/KNX IP Gateway and Router with knxd "
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
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 1; fi
  fi

  echo -n "[openHABian] Installing owserver (1wire)... "
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

influxdb_grafana_setup() {
  echo -n "[openHABian] Setting up InfluxDB and Grafana... "
  #cond_redirect apt update
  #cond_redirect apt -y install bison ruby ruby-dev gcc make
  #echo -n "Go... "
  ##cond_redirect wget -O /root/gvm-installer https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer
  ##cond_redirect /bin/bash /root/gvm-installer
  #cond_redirect bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
  #cond_redirect source /root/.gvm/scripts/gvm
  #cond_redirect gvm install go1.4 --prefer-binary
  #cond_redirect gvm use go1.4
  #export GOROOT_BOOTSTRAP=$GOROOT
  #cond_redirect gvm install go1.7
  #cond_redirect gvm use go1.7 -–default

  echo -n "InfluxDB... "
  # https://docs.influxdata.com/influxdb/v1.0
  curl -L https://dl.influxdata.com/influxdb/releases/influxdb-1.0.0_linux_armhf.tar.gz | tar xvz -C /
  ln -s /usr/lib/influxdb/scripts/influxdb.service /lib/systemd/system/influxdb.service
  adduser --system --no-create-home --group --disabled-login influxdb
  chown -R influxdb:influxdb /var/lib/influxdb
  systemctl daemon-reload
  systemctl enable influxdb.service
  systemctl start influxdb.service

  #https://github.com/fg2it/grafana-on-raspberry/tree/master/wheezy-jessie
  apt update
  apt -y install curl git ca-certificates binutils gcc make libc-dev ruby ruby-dev rpm libfontconfig1 python g++

  if is_pione ; then
    echo -n "Go (ARMv6 architecture)... "
    curl -L https://github.com/hypriot/golang-armbuilds/releases/download/v1.5.2/go1.5.2.linux-armv6.tar.gz | tar xvz -C /usr/local
    curl -L https://nodejs.org/dist/v5.10.1/node-v5.10.1-linux-armv6l.tar.xz | tar xvJ --strip-components=1 -C /usr/local
  else
    echo -n "Go (ARMv7 architecture)... "
    curl -L https://github.com/hypriot/golang-armbuilds/releases/download/v1.5.2/go1.5.2.linux-armv7.tar.gz | tar xvz -C /usr/local
    curl -L https://nodejs.org/dist/v5.10.1/node-v5.10.1-linux-armv7l.tar.xz | tar xvJ --strip-components=1 -C /usr/local
  fi

  export PATH=/usr/local/go/bin:$PATH

  echo -n "fpm... "
  /usr/local/go/bin/gem install fpm

  echo -n "phantomjs... "
  curl -o /opt/phantomjs_armhf.deb -L https://github.com/fg2it/phantomjs-on-raspberry/releases/download/v2.1.1-wheezy-jessie/phantomjs_2.1.1_armhf.deb
  dpkg -i /opt/phantomjs_armhf.deb
  rm /opt/phantomjs_armhf.deb

  echo -n "Grafana... "
  export GOPATH=/opt/graf-build
  mkdir -p $GOPATH
  cd $GOPATH
  go get github.com/grafana/grafana
  cd $GOPATH/src/github.com/grafana/grafana
  #git checkout v3.1.1
  go run build.go setup
  $GOPATH/bin/godep restore
  npm install
  go run build.go build package

  rm -rf $GOPATH
}

openhabian_update() {
  echo -n "[openHABian] Updating myself... "
  cond_redirect git -C $SCRIPTDIR fetch origin
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect git -C $SCRIPTDIR reset --hard origin/master
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

system_upgrade() {
  echo -n "[openHABian] Upgrading system (apt update && apt upgrade)... "
  cond_redirect apt update
  cond_redirect apt --yes upgrade
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

get_git_revision() {
  local branch=`git -C $SCRIPTDIR rev-parse --abbrev-ref HEAD`
  local shorthash=`git -C $SCRIPTDIR log --pretty=format:'%h' -n 1`
  local revcount=`git -C $SCRIPTDIR log --oneline | wc -l`
  local latesttag=`git -C $SCRIPTDIR describe --tags --abbrev=0`
  local revision="[$branch]$latesttag-$revcount($shorthash)"
  echo "$revision"
}

show_about() {
  whiptail --title "openHABian $(get_git_revision)" --msgbox "The hassle-free openHAB 2 installation and configuration tool.\nhttps://github.com/ThomDietrich/openhabian \nhttps://community.openhab.org/t/openhabian-hassle-free-rpi-image/13379" 12 80
}

fresh_raspbian_mods() {
  memory_split
  basic_packages
  needed_packages
  bashrc_copy
  vimrc_copy
}

openhab2_full_setup() {
  openhab2_addrepo
  openhab2_install
  openhab2_service
  vim_openhab_syntax
  nano_openhab_syntax
}

samba_setup() {
  samba_config
  samba_user
  samba_activate
}

show_main_menu() {
  get_init_sys
  calc_wt_size

  choice=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Exit --ok-button Execute \
  "01 | Update"                 "Pull the newest version of the openHABian Configuration Tool from GitHub" \
  "02 | Basic Setup"            "Perform all basic setup steps recommended for openHAB 2 on a new system" \
  "03 | Java 8"                 "Install the newest Revision of Java 8 provided by WebUpd8Team (needed by openHAB 2)" \
  "04 | openHAB 2"              "Prepare and install the latest openHAB 2 snapshot" \
  "05 | Samba"                  "Install the filesharing service Samba and set up openHAB 2 shares" \
  "06 | Karaf Console"          "Bind the Karaf console to all interfaces" \
  "10 | Optional: KNX"          "Set up the KNX daemon knxd" \
  "11 | Optional: Homegear"     "Set up the Homematic CCU2 emulation software Homegear" \
  "12 | Optional: Mosquitto"    "Set up the MQTT broker Mosquitto" \
  "13 | Optional: 1wire"        "Set up owserver and related packages for working with 1wire" \
  "14 | Optional: Grafana"      "(not yet implemented)" \
  "20 | RPi3 Wifi"              "Configure build-in Raspberry Pi 3 Wifi" \
  "99 | About openHABian"       "Information about the openHABian project" \
  3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    echo "We hope you got what you came for! See you again soon ;)"
    exit 0
  elif [ $RET -eq 0 ]; then
    case "$choice" in
      01\ *) openhabian_update && echo -e "\nopenHABian configuration tool successfully updated. Please run again. Exiting..." && exit 0 ;;
      02\ *) fresh_raspbian_mods ;;
      03\ *) java_webupd8_prepare && java_webupd8_install ;;
      04\ *) openhab2_full_setup ;;
      05\ *) samba_setup ;;
      06\ *) openhab_shell_interfaces ;;
      10\ *) knxd_setup ;;
      11\ *) homegear_setup ;;
      12\ *) mqtt_setup ;;
      13\ *) 1wire_setup ;;
      20\ *) wifi-setup-rpi3 ;;
      99\ *) show_about ;;
      *) whiptail --msgbox "Error: unrecognized option" 10 60 ;;
    esac || whiptail --msgbox "There was an error running option \"$choice\"" 10 60
  else
    echo "Bye Bye! :)"
    exit 1
  fi
}

if [[ -n "$UNATTENDED" ]]
then
  #unattended installation (from within raspbian-ua-netinst chroot)
  #locale_timezone_settings
  first_boot_script
  fresh_raspbian_mods
  java_webupd8_prepare
  #java_webupd8_install
  openhab2_full_setup
  samba_setup
  firemotd
  etckeeper
else
  while true; do
    show_main_menu
    echo ""
  done
fi


# vim: filetype=sh
