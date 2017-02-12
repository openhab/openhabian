#!/usr/bin/env bash

# openHABian - hassle-free openHAB 2 installation and configuration tool
# for the Raspberry Pi and other Linux systems
#
# Documentation: http://docs.openhab.org/installation/openhabian.html
# Development: http://github.com/openhab/openhabian
# Discussion: https://community.openhab.org/t/13379
#
# 2016 Thomas Dietrich
#

#
REPOSITORYURL="https://github.com/openhab/openhabian"
CONFIGFILE="/etc/openhabian.conf"

# Find the absolute script location dir (e.g. SCRIPTDIR=/opt/openhabian)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$SCRIPTDIR/$SOURCE"
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
if [[ "$1" = "unattended" ]]; then
  UNATTENDED=1
  SILENT=1
elif [[ "$1" = "unattended_debug" ]]; then
  UNATTENDED=1
else
  INTERACTIVE=1
fi

# Load configuration
if [ -f "$CONFIGFILE" ]; then
  echo -n "[openHABian] Loading configuration file '$CONFIGFILE'... "
elif [ ! -f "$CONFIGFILE" ] && [ -f /boot/installer-config.txt ]; then
  echo -n "[openHABian] Copying and loading configuration file '$CONFIGFILE'... "
  cp /boot/installer-config.txt $CONFIGFILE
elif [ ! -f "$CONFIGFILE" ] && [ -n "$UNATTENDED" ]; then
  echo "[openHABian] Error in unattended mode: Configuration file '$CONFIGFILE' not found... FAILED" 1>&2
  exit 1
else
  echo -n "[openHABian] Setting up and loading configuration file '$CONFIGFILE' in manual setup... "
  question="Welcome to openHABian!\n\nPlease provide the name of your Linux user i.e. the account you normally log in with.\nTypical user names are 'pi' or 'ubuntu'."
  input=$(whiptail --title "openHABian Configuration Tool - Manual Setup" --inputbox "$question" 15 80 3>&1 1>&2 2>&3)
  if ! id -u "$input" &>/dev/null ; then
    echo "FAILED"
    echo "[openHABian] Error: The provided user name is not a valid system user. Please try again. Exiting ..." 1>&2
    exit 1
  fi
  cp $SCRIPTDIR/openhabian.conf.dist $CONFIGFILE
  sed -i "s/username=.*/username=$input/g" $CONFIGFILE
fi
# shellcheck source=/etc/openhabian.conf
source "$CONFIGFILE"
echo "OK"

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
    echo -e "$COL_YELLOW$@$COL_DEF"
  fi
}

is_pizero() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]09[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
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
is_pi() {
  if [ "$hostname" == "openHABianPi" ]; then return 0; fi
  if is_pizero || is_pione || is_pitwo || is_pithree; then return 0; fi
  return 1
}
is_pine64() {
  [[ $(uname -r) =~ "pine64-longsleep" ]]
  return $?
}

calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error
  # output from tput. However in this case, tput detects neither stdout or
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=24
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

locale_timezone_settings() {
  echo -n "[openHABian] Setting timezone (Europe/Berlin) and locale (en_US.UTF-8)... "
  # source "$CONFIGFILE"
  cond_redirect timedatectl set-timezone $timezone
  cond_redirect /usr/sbin/locale-gen $locales
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  LANG=$system_default_locale
  cond_redirect /usr/sbin/update-locale LANG=$system_default_locale
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

#TODO: Remove, will be taken care of outside
first_boot_script() {
  echo -n "[openHABian] Activating first boot script... "
  cp $SCRIPTDIR/raspbian-ua-netinst/rc.local /etc/rc.local
  echo "OK"
}

memory_split() {
  echo -n "[openHABian] Setting the GPU memory split down to 16MB for headless system... "
  if grep -q "gpu_mem" /boot/config.txt; then
    sed -i 's/gpu_mem=.*/gpu_mem=16/g' /boot/config.txt
  else
    echo "gpu_mem=16" >> /boot/config.txt
  fi
  if ! grep -q "dtparam=audio" /boot/config.txt; then
    echo "dtparam=audio=on" >> /boot/config.txt
  fi
  echo "OK"
}

basic_packages() {
  echo -n "[openHABian] Installing basic can't-be-wrong packages (screen, vim, ...)... "
  if is_pi; then
    cond_redirect wget -O /usr/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update
    cond_redirect chmod +x /usr/bin/rpi-update
  fi
  cond_redirect apt update
  cond_redirect apt -y install screen vim nano mc vfu bash-completion htop curl wget multitail git bzip2 zip unzip xz-utils software-properties-common
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

needed_packages() {
  # Conditional: Install raspi-config - configuration tool for the Raspberry Pi + Raspbian
  # Install apt-transport-https - update packages through https repository
  # Install samba - network sharing
  # Install bc + sysstat - needed for FireMotD
  # Install avahi-daemon - hostname based discovery on local networks
  echo -n "[openHABian] Installing additional needed packages... "
  cond_redirect apt update
  if is_pi; then cond_redirect apt -y install raspi-config; fi
  cond_redirect apt -y install apt-transport-https samba bc sysstat avahi-daemon
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

bashrc_copy() {
  echo -n "[openHABian] Adding slightly tuned bash config files to system... "
  cp $SCRIPTDIR/includes/bash.bashrc /etc/bash.bashrc
  cp $SCRIPTDIR/includes/bashrc-root /root/.bashrc
  cp $SCRIPTDIR/includes/bash_profile /home/$username/.bash_profile
  chown $username:$username /home/$username/.bash_profile
  echo "OK"
}

vimrc_copy() {
  echo -n "[openHABian] Adding slightly tuned vim config file to system... "
  cp $SCRIPTDIR/includes/vimrc /etc/vim/vimrc
  echo "OK"
}

java_webupd8() {
  echo -n "[openHABian] Preparing and Installing Oracle Java 8 Web Upd8 repository... "
  rm -f /etc/apt/sources.list.d/webupd8team-java.list
  echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list.d/webupd8team-java.list
  echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list.d/webupd8team-java.list
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
  if [ $? -ne 0 ]; then echo "FAILED (debconf)"; exit 1; fi
  cond_redirect apt update
  cond_redirect apt -y install oracle-java8-installer
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt -y install oracle-java8-set-default
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

java_zulu_embedded() {
  echo -n "[openHABian] Installing Zulu Embedded OpenJDK ARM build (archive)... "
  cond_redirect wget -O ezdk.tar.gz http://cdn.azul.com/zulu-embedded/bin/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf.tar.gz
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect mkdir /opt/zulu-embedded
  cond_redirect tar xvfz ezdk.tar.gz -C /opt/zulu-embedded
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect rm -f ezdk.tar.gz
  cond_redirect chown -R 0:0 /opt/zulu-embedded
  cond_redirect update-alternatives --auto java
  cond_redirect update-alternatives --auto javac
  cond_redirect update-alternatives --install /usr/bin/java java /opt/zulu-embedded/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf/bin/java 2162
  cond_redirect update-alternatives --install /usr/bin/javac javac /opt/zulu-embedded/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf/bin/javac 2162
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

# openhab2_user() {
#   echo -n "[openHABian] Manually adding openhab user to system (for manual installation?)... "
#   adduser --system --no-create-home --group --disabled-login openhab &>/dev/null
#   echo "OK"
# }

openhab2_addrepo() {
  echo -n "[openHABian] Adding openHAB 2 repository to sources.list.d... "
  echo "deb http://dl.bintray.com/openhab/apt-repo2 stable main" > /etc/apt/sources.list.d/openhab2.list
  #echo "deb http://dl.bintray.com/openhab/apt-repo2 testing main" > /etc/apt/sources.list.d/openhab2.list
  #echo "deb http://dl.bintray.com/openhab/apt-repo2 unstable main" > /etc/apt/sources.list.d/openhab2.list
  cond_redirect wget -O openhab-key.asc 'https://bintray.com/user/downloadSubjectPublicKey?username=openhab'
  cond_redirect apt-key add openhab-key.asc
  rm -f openhab-key.asc
  cond_redirect apt update
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

openhab2_install() {
  echo -n "[openHABian] Installing openhab2... "
  cond_redirect apt -y install openhab2
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
}

openhab2_service() {
  echo -n "[openHABian] Activating openHAB... "
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable openhab2.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

vim_openhab_syntax() {
  echo -n "[openHABian] Adding openHAB syntax to vim editor... "
  # these may go to "/usr/share/vim/vimfiles" ?
  mkdir -p /home/$username/.vim/{ftdetect,syntax}
  cond_redirect wget -O /home/$username/.vim/syntax/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/syntax/openhab.vim
  cond_redirect wget -O /home/$username/.vim/ftdetect/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/ftdetect/openhab.vim
  chown -R $username:$username /home/$username/.vim
  echo "OK"
}

nano_openhab_syntax() {
  # add nano syntax highlighting
  echo -n "[openHABian] Adding openHAB syntax to nano editor... "
  cond_redirect wget -O /usr/share/nano/openhab.nanorc https://raw.githubusercontent.com/airix1/openhabnano/master/openhab.nanorc
  echo -e "\n## openHAB files\ninclude \"/usr/share/nano/openhab.nanorc\"" >> /etc/nanorc
  echo "OK"
}

samba_setup() {
  echo -n "[openHABian] Setting up Samba... "
  cp $SCRIPTDIR/includes/smb.conf /etc/samba/smb.conf
  ( (echo "habopen"; echo "habopen") | /usr/bin/smbpasswd -s -a openhab > /dev/null )
  ( (echo "raspberry"; echo "raspberry") | /usr/bin/smbpasswd -s -a $username > /dev/null )
  cond_redirect chown -R openhab:$username /opt /etc/openhab2
  cond_redirect chmod -R g+w /opt /etc/openhab2
  cond_redirect /bin/systemctl enable smbd.service
  cond_redirect /bin/systemctl restart smbd.service
  echo "OK"
}

firemotd() {
  echo -n "[openHABian] Downloading and setting up FireMotD... "
  rm -rf /opt/FireMotD
  cond_redirect git clone https://github.com/willemdh/FireMotD.git /opt/FireMotD
  if [ $? -eq 0 ]; then
    # the following is already in bash_profile by default
    #echo -e "\necho\n/opt/FireMotD/FireMotD --theme gray \necho" >> /home/$username/.bash_profile
    # initial apt updates check
    cond_redirect /bin/bash /opt/FireMotD/FireMotD -S
    # invoke apt updates check every night
    echo "3 3 * * * root /bin/bash /opt/FireMotD/FireMotD -S &>/dev/null" > /etc/cron.d/firemotd
    # invoke apt updates check after every apt action ('apt upgrade', ...)
    echo "DPkg::Post-Invoke { \"if [ -x /opt/FireMotD/FireMotD ]; then echo -n 'Updating FireMotD available updates count ... '; /bin/bash /opt/FireMotD/FireMotD -S; echo ''; fi\"; };" > /etc/apt/apt.conf.d/15firemotd
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

misc_system_settings() {
  echo -n "[openHABian] Applying multiple useful system settings (permissions, ...)... "
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect adduser $username openhab
  cond_redirect adduser $username dialout
  cond_redirect adduser $username tty
  cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' $(realpath /usr/bin/java)
  cond_redirect chown -R openhab:$username /opt /etc/openhab2
  cond_redirect chmod -R g+w /opt /etc/openhab2
  echo "OK"
}

openhab_shell_interfaces() {
  introtext="The Karaf console is a powerful tool for every openHAB user. It allows you too have a deeper insight into the internals of your setup. Further details: http://docs.openhab.org/administration/console.html
\nThis routine will bind the console to all interfaces and thereby make it available to other devices in your network. Please provide a secure password for this connection (letters and numbers only! default: habopen):"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="The Karaf console was successfully opened on all interfaces. openHAB has been restarted. You should be able to reach the console via:
\n'ssh://openhab:<password>@<openhabian-IP> -p 8101'\n
Please be aware, that the first connection attempt may take a few minutes or may result in a timeout."

  echo -n "[openHABian] Binding the Karaf console on all interfaces... "
  if [ -n "$INTERACTIVE" ]; then
    sshPassword=$(whiptail --title "Bind Karaf Console, Password?" --inputbox "$introtext" 20 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus -ne 0 ]; then
      echo "aborted"
      return 0
    fi
  fi
  [[ -z "${sshPassword// }" ]] && sshPassword="habopen"

  cond_redirect sed -i "s/sshHost = 127.0.0.1/sshHost = 0.0.0.0/g" /var/lib/openhab2/etc/org.apache.karaf.shell.cfg
  cond_redirect sed -i "s/openhab = .*,/openhab = $sshPassword,/g" /var/lib/openhab2/etc/users.properties
  cond_redirect systemctl restart openhab2.service

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
  echo "OK"
}

prepare_serial_port() {
  introtext="Proceeding with this routine, the serial console normally provided by a Raspberry Pi can be disabled for the sake of a usable serial port. The provided port can henceforth be used by devices like Razberry, UZB or Busware SCC.
On a Raspberry Pi 3 the Bluetooth module can additionally be disabled, ensuring the operation of a Razberry (mutually exclusive).
Finally, all common serial ports can be made accessible to the openHAB java virtual machine.
\nPlease make your choice:"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="All done. After a reboot the serial console will be available via /dev/ttyAMA0 or /dev/ttyS0. For stability reasons please update your Raspberry Pi firmware now and reboot afterwards.\n
  sudo rpi-update
  sudo reboot"

  echo -n "[openHABian] Configuring serial console for serial port peripherals... "
  if ! is_pi ; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "Serial Port Setup: This option is for the Raspberry Pi only." 10 60
    fi
    echo "FAILED"; return 1
  fi
  if [ -n "$INTERACTIVE" ]; then
    selection=$(whiptail --title "Prepare Serial Port" --checklist --separate-output "$introtext" 20 78 3 \
    "1"  "Disable serial console                 (Razberry, SCC, Enocean)" ON \
    "2"  "Disable the RPi3 Bluetooth module      (Razberry)" OFF \
    "3"  "Add common serial ports to openHAB JVM (Razberry, Enocean)" ON \
    3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 0; fi
  else
    selection="1 3"
  fi

  if [[ $selection == *"1"* ]]; then
    cond_echo ""
    cond_echo "Adding 'enable_uart=1' to /boot/config.txt"
    if grep -q "enable_uart" /boot/config.txt; then
      sed -i 's/^.*enable_uart=.*$/enable_uart=1/g' /boot/config.txt
    else
      echo "enable_uart=1" >> /boot/config.txt
    fi
    cond_echo "Removing serial console and login shell from /boot/cmdline.txt and /etc/inittab"
    sed -i 's/console=tty.*console=tty1/console=tty1/g' /boot/cmdline.txt
    sed -i 's/^T0/\#T0/g' /etc/inittab
  #else
  #TODO this needs to be implemented when someone actually cares...
  fi

  if [[ $selection == *"2"* ]]; then
    if is_pithree; then
      cond_echo "Adding 'dtoverlay=pi3-miniuart-bt' to /boot/config.txt (RPi3)"
      systemctl disable hciuart &>/dev/null
      if ! grep -q "dtoverlay=pi3-miniuart-bt" /boot/config.txt; then
        echo "dtoverlay=pi3-miniuart-bt" >> /boot/config.txt
      fi
    fi
  else
    cond_echo "Removing 'dtoverlay=pi3-miniuart-bt' from /boot/config.txt"
    sed -i '/dtoverlay=pi3-miniuart-bt/d' /boot/config.txt
  fi

  if [[ $selection == *"3"* ]]; then
    cond_echo "Adding serial ports to openHAB java virtual machine in /etc/default/openhab2"
    sed -i 's#EXTRA_JAVA_OPTS=.*#EXTRA_JAVA_OPTS="-Dgnu.io.rxtx.SerialPorts=/dev/ttyUSB0:/dev/ttyS0:/dev/ttyAMA0"#g' /etc/default/openhab2
  else
    cond_echo "Removing serial ports from openHAB java virtual machine in /etc/default/openhab2"
    sed -i 's#EXTRA_JAVA_OPTS=.*#EXTRA_JAVA_OPTS=""#g' /etc/default/openhab2
  fi

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
  echo "OK (Reboot needed)"
}

wifi_setup_rpi3() {
  echo -n "[openHABian] Setting up RPi 3 Wifi... "
  if ! is_pithree ; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "Wifi setup: This option is for a Raspberry Pi 3 system only." 10 60
    fi
    echo "FAILED"; return 1
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
  cond_redirect apt -y install firmware-brcm80211 wpasupplicant wireless-tools
  echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1\nnetwork={\n  ssid=\"$SSID\"\n  psk=\"$PASS\"\n}" > /etc/wpa_supplicant/wpa_supplicant.conf
  if grep -q "wlan0" /etc/network/interfaces; then
    cond_echo ""
    cond_echo "Not writing to '/etc/network/interfaces', wlan0 entry already available. You might need to check, adopt or remove these lines."
    cond_echo ""
  else
    echo -e "\nallow-hotplug wlan0\niface wlan0 inet manual\nwpa-roam /etc/wpa_supplicant/wpa_supplicant.conf\niface default inet dhcp" >> /etc/network/interfaces
  fi
  cond_redirect ifdown wlan0
  cond_redirect ifup wlan0

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "Setup was successful. Your Wifi credentials were NOT tested. Please reboot now." 15 80
  fi

  echo "OK (Reboot needed)"
}

move_root2usb() {
  NEWROOTDEV=/dev/sda
  NEWROOTPART=/dev/sda1

  infotext="DANGEROUS OPERATION, USE WITH PRECAUTION!\n
This will move your system root from your SD card to a USB device like an SSD or a USB stick to reduce wear and failure or the SD card.\n
1.) Make a backup of your SD card
2.) Remove all USB massstorage devices from your Pi
3.) Insert the USB device to be used for the new system root.
    THIS DEVICE WILL BE FULLY DELETED\n\n
Do you want to continue on your own risk?"

  if ! is_pi ; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "Move root to USB: This option is for the Raspberry Pi only." 10 60
    fi
    echo "FAILED"; return 1
  fi

  if ! (whiptail --title "Move system root to '$NEWROOTPART'" --yes-button "Continue" --no-button "Back" --yesno "$infotext" 18 78) then
    return 0
  fi

  #check if system root is on partion 2 of the SD card
  if ! grep -q "root=/dev/mmcblk0p2" /boot/cmdline.txt; then
    infotext="It seems as if your system root is not on the SD card.
       ***Aborting, process cant be started***"
    whiptail --title "System root not on SD card?" --msgbox "$infotext" 8 78
    return
  fi

  #check if USB power is already set to 1A, otherwise set it there
  if grep -q -F 'max_usb_current=1' /boot/config.txt; then
     echo "max_usb_current already set, ok"
  else
     echo 'max_usb_current=1' >> /boot/config.txt

     echo
     echo "********************************************************************************"
     echo "REBOOT, run openhabian-setup.sh again and recall menu item 'Move root to USB'"
     echo "********************************************************************************"
     whiptail --title "Reboot needed!" --msgbox "USB had to be set to high power (1A) first. Please REBOOT and RECALL this menu item" 15 78
     exit
  fi

  #inform user to be patient ...
  infotext="After confirming with OK, system root will be moved.
Please be patient. This will take 5 to 15 minutes, depending mainly on the speed of your USB device.
When the process is finished, you will be informed via message box..."

  whiptail --title "Moving system root ..." --msgbox "$infotext" 14 78

  echo "stopping openHAB"
  systemctl stop openhab2

  #delete all old partitions
  #http://www.cyberciti.biz/faq/linux-remove-all-partitions-data-empty-disk
  dd if=/dev/zero of=$NEWROOTDEV  bs=512 count=1

  #https://suntong.github.io/blogs/2015/12/25/use-sfdisk-to-partition-disks
  echo "partitioning on '$NEWROOTDEV'"
  #create one big new partition
  echo ';' | /sbin/sfdisk $NEWROOTDEV


  echo "creating filesys on '$NEWROOTPART'"
  #create new filesystem on partion 1
  mkfs.ext4 -F -L oh_usb $NEWROOTPART

  echo "mounting new root '$NEWROOTPART'"
  mount $NEWROOTPART /mnt

  echo
  echo "**********************************************************************************************************"
  echo "copying root sys, please be patient. Depending on the speed of your USB device, this can take 10 to 15 min"
  echo "**********************************************************************************************************"

  #tar cf - --one-file-system --exclude=/mnt/* --exclude=/proc/* --exclude=/lost+found/* --exclude=/sys/* --exclude=/media/* --exclude=/dev/* --exclude=/tmp/* --exclude=/boot/* --exclude=/run/* / | ( cd /mnt; sudo tar xfp -)
  rsync -aAXH --info=progress2 --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/boot/*"} / /mnt

  echo
  echo "adjusting fstab on new root"
  #adjust system root in fstab
  sed -i "s#/dev/mmcblk0p2 /#$NEWROOTPART /#" /mnt/etc/fstab

  echo "adjusting system root in kernel bootline"
  #make a copy of the original cmdline
  cp /boot/cmdline.txt /boot/cmdline.txt.sdcard
  #adjust system root in kernel bootline
  sed -i "s#root=/dev/mmcblk0p2#root=$NEWROOTPART#" /boot/cmdline.txt

  echo
  echo "*************************************************************"
  echo "OK, moving system root finished you're all set, PLEASE REBOOT"
  echo
  echo "In the unlikely case that the reboot does not suceed,"
  echo "please put the SD card into another device and copy back"
  echo "/boot/cmdline.txt.sdcard to /boot/cmdline.txt"
  echo "*************************************************************"

  infotext="OK, moving system root finished. PLEASE REBOOT\n
In the unlikely case that the reboot does not suceed,
please put the SD card into another device and copy back
/boot/cmdline.txt.sdcard to /boot/cmdline.txt"
  whiptail --title "Moving system root finished ...." --msgbox "$infotext" 12 78
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
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
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
  introtext="The MQTT broker software Mosquitto will be installed through the official repository, as desribed here: https://mosquitto.org/2013/01/mosquitto-debian-repository"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful.
Mosquitto is now up and running in the background. You should now be able to make a first connection.
To continue your integration in openHAB 2, please follow the instructions under: https://github.com/openhab/openhab/wiki/MQTT-Binding
"

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo -n "[openHABian] Setting up the MQTT broker software Mosquitto... "
  cond_redirect wget -O - http://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | apt-key add -
  echo "deb http://repo.mosquitto.org/debian jessie main" > /etc/apt/sources.list.d/mosquitto-jessie.list
  cond_redirect apt update
  if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  cond_redirect apt -y install mosquitto mosquitto-clients
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
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
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
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
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
  FAILED=0
  introtext="This will install InfluxDB and Grafana. Soon this procedure will also set up the connection between them and with openHAB. For now, please follow the instructions found here:
  \nhttps://community.openhab.org/t/13761/1"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup successful. Please continue with the instructions you can find here:\n\nhttps://community.openhab.org/t/13761/1"

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo -n "[openHABian] Setting up InfluxDB and Grafana... "

  if is_pione; then
    GRAFANA_REPO_PI1="-rpi-1b"
  else
    GRAFANA_REPO_PI1=""
  fi

  cond_redirect apt -y install apt-transport-https

  cond_echo ""
  echo -n "InfluxDB... "
  cond_redirect wget -O - https://repos.influxdata.com/influxdb.key | apt-key add - || FAILED=1
  echo "deb https://repos.influxdata.com/debian jessie stable" > /etc/apt/sources.list.d/influxdb.list || FAILED=1
  cond_redirect apt update || FAILED=1
  cond_redirect apt -y install influxdb || FAILED=1
  # manual setup
  #cond_redirect wget -O /tmp/download.tar.gz https://dl.influxdata.com/influxdb/releases/influxdb-1.0.0_linux_armhf.tar.gz || FAILED=1
  #cond_redirect tar xvzf /tmp/download.tar.gz -C / --strip 2 || FAILED=1
  #cond_redirect cp /usr/lib/influxdb/scripts/influxdb.service /lib/systemd/system/influxdb.service || FAILED=1
  #cond_redirect adduser --system --no-create-home --group --disabled-login influxdb || FAILED=1
  #cond_redirect chown -R influxdb:influxdb /var/lib/influxdb || FAILED=1
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable influxdb.service
  cond_redirect systemctl start influxdb.service
  if [ $FAILED -eq 1 ]; then echo -n "FAILED "; else echo -n "OK "; fi
  cond_echo ""

  echo -n "Grafana (fg2it)... "
  echo "deb https://dl.bintray.com/fg2it/deb${GRAFANA_REPO_PI1} jessie main" > /etc/apt/sources.list.d/grafana-fg2it.list || FAILED=2
  cond_redirect apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 379CE192D401AB61 || FAILED=2
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
    cp $SCRIPTDIR/includes/nginx.conf /etc/nginx/sites-enabled/openhab

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

openhabian_update() {
  FAILED=0
  #TODO: Remove after 2017-03
  if git -C $SCRIPTDIR remote -v | grep -q "ThomDietrich"; then
    cond_echo ""
    cond_echo "Old origin URL found. Replacing with the new URL under the openHAB organization (https://github.com/openhab/openhabian.git)..."
    cond_echo ""
    git -C $SCRIPTDIR remote set-url origin https://github.com/openhab/openhabian.git
  fi
  echo -n "[openHABian] Updating myself... "
  shorthash_before=$(git -C $SCRIPTDIR log --pretty=format:'%h' -n 1)
  git -C $SCRIPTDIR fetch --quiet origin || FAILED=1
  git -C $SCRIPTDIR reset --quiet --hard origin/master || FAILED=1
  git -C $SCRIPTDIR clean --quiet --force -x -d || FAILED=1
  git -C $SCRIPTDIR checkout --quiet master || FAILED=1
  if [ $FAILED -eq 1 ]; then
    echo "FAILED - There was a problem fetching the latest changes for the openHABian configuration tool. Please check your internet connection and try again later..."
    return 1
  fi
  shorthash_after=$(git -C $SCRIPTDIR log --pretty=format:'%h' -n 1)
  if [ "$shorthash_before" == "$shorthash_after" ]; then
    echo "OK - No remote changes detected. You are up to date!"
    return 0
  else
    echo "OK - Commit history (oldest to newest):"
    echo -e "\n"
    git -C $SCRIPTDIR log --pretty=format:'%Cred%h%Creset - %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --reverse --abbrev-commit --stat $shorthash_before..$shorthash_after
    echo -e "\n"
    echo "openHABian configuration tool successfully updated."
    echo "Visit the development repository for more details: $REPOSITORYURL"
    echo "You need to restart the tool. Exiting now... "
    exit 0
  fi
  git -C $SCRIPTDIR config user.email 'openhabian@openHABianPi'
  git -C $SCRIPTDIR config user.name 'openhabian'
}

system_check_default_password() {
  introtext="The default password was detected on your system! That's a serious security concern. Others or malicious programs in your subnet are able to gain root access!
  \nPlease set a strong password by typing the command 'passwd' in the console."

  echo -n "[openHABian] Checking for default Raspbian user:passwd combination... "
  if is_pi; then
    # Check for Raspbian defaults (not openhabian.conf)
    USERNAME="pi"
    PASSWORD="raspberry"
  else if is_pine64; then
    # Check for Ubuntu defaults (not openhabian.conf)
    USERNAME="ubuntu"
    PASSWORD="ubuntu"
  else
    echo "SKIPPED (method not implemented)"
    return 0
  fi
  id -u $USERNAME &>/dev/null
  if [ $? -ne 0 ]
  then
    echo "OK (unknown user)"
    return 0
  fi
  export PASSWORD
  ORIGPASS=$(grep -w "$USERNAME" /etc/shadow | cut -d: -f2)
  export ALGO=$(echo $ORIGPASS | cut -d'$' -f2)
  export SALT=$(echo $ORIGPASS | cut -d'$' -f3)
  GENPASS=$(perl -le 'print crypt("$ENV{PASSWORD}","\$$ENV{ALGO}\$$ENV{SALT}\$")')
  if [ "$GENPASS" == "$ORIGPASS" ]; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Default Password Detected!" --msgbox "$introtext" 12 60
    fi
    echo "FAILED"
  else
    echo "OK"
  fi

}

#TODO: Unused
change_admin_password() {
  introtext="Choose which services to change password for:"
  failtext="Something went wrong in the change process. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."

  matched=false
  canceled=false
  FAILED=0

  if [ -n "$INTERACTIVE" ]; then
    accounts=$(whiptail --title "Choose accounts" --yes-button "Continue" --no-button "Back" --checklist "$introtext" 20 90 10 \
          "Linux account" "The account to login to this computer" on \
          "Openhab2" "The karaf console which is used to manage openhab" on \
          "Samba" "The fileshare for configuration files" on \
          3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      while [ "$matched" = false ] && [ "$canceled" = false ]; do
        passwordChange=$(whiptail --title "Authentication Setup" --passwordbox "Enter a new password for $username:" 15 80 3>&1 1>&2 2>&3)
        if [[ "$?" == 1 ]]; then return 0; fi
        secondpasswordChange=$(whiptail --title "Authentication Setup" --passwordbox "Please confirm the new password:" 15 80 3>&1 1>&2 2>&3)
        if [[ "$?" == 1 ]]; then return 0; fi
        if [ "$passwordChange" = "$secondpasswordChange" ] && [ ! -z "$passwordChange" ]; then
          matched=true
        else
          password=$(whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3)
        fi
      done
    else
        return 0
    fi
  else
    passwordChange=$1
    accounts=("Linux account" "Openhab2" "Samba")
  fi

  for i in "${accounts[@]}"
  do
    echo "$i"
    if [ "$i" == "Linux account" ]; then
      echo -n "[openHABian] Changing password for linux account $username... "
      cond_redirect echo "$username:$passwordChange" | chpasswd
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
    if [ "$i" == "Openhab2" ]; then
      echo -n "[openHABian] Changing password for samba (fileshare) account $username... "
      (echo "$passwordChange"; echo "$passwordChange") | /usr/bin/smbpasswd -s -a $username
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
    if [ "$i" == "Samba" ]; then
      echo -n "[openHABian] Changing password for karaf console account $username... "
      cond_redirect sed -i "s/$username = .*,/$username = $passwordChange,/g" /var/lib/openhab2/etc/users.properties
      cond_redirect service openhab2 stop
      cond_redirect service openhab2 start
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
  done

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "Password set successfully set for accounts: $accounts" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

system_upgrade() {
  echo -n "[openHABian] Updating repositories and upgrading installed packages... "
  cond_redirect apt update
  cond_redirect apt --yes upgrade
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

get_git_revision() {
  local branch=$(git -C $SCRIPTDIR rev-parse --abbrev-ref HEAD)
  local shorthash=$(git -C $SCRIPTDIR log --pretty=format:'%h' -n 1)
  local revcount=$(git -C $SCRIPTDIR log --oneline | wc -l)
  local latesttag=$(git -C $SCRIPTDIR describe --tags --abbrev=0)
  local revision="[$branch]$latesttag-$revcount($shorthash)"
  echo "$revision"
}

show_about() {
  whiptail --title "About openHABian and openhabian-config" --msgbox "openHABian Configuration Tool $(get_git_revision)
  \nThis tool provides a few routines to make your openHAB experience as comfortable as possible. The menu options help with the setup and configuration of your system. Please select a menu entry to learn more.
  \nVisit the following websites for more information:
  - Documentation: http://docs.openhab.org/installation/openhabian.html
  - Development: http://github.com/openhab/openhabian
  - Discussion: https://community.openhab.org/t/13379" 17 80
}

basic_setup() {
  introtext="If you continue, this step will update the openHABian basic system settings.\n\nThe following steps are included:
  - Set your timezone and locale acording to '/etc/openhabian.conf'
  - Install recommended packages (vim, git, htop, ...)
  - Install an improved bash configuration
  - Install an improved vim configuration
  - Set up FireMotD
  - Make some permission changes ('adduser', 'chown', ...)"

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 20 80) then return 0; fi
  fi

  locale_timezone_settings
  basic_packages
  needed_packages
  bashrc_copy
  vimrc_copy
  firemotd
  misc_system_settings
}

openhab2_full_setup() {
  openhab2_addrepo
  openhab2_install
  openhab2_service
  vim_openhab_syntax
  nano_openhab_syntax
}

show_main_menu() {
  calc_wt_size

  choice=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Exit --ok-button Execute \
  "00 | About openHABian"       "Get information about the openHABian project an this tool" \
  "01 | Update"                 "Pull the latest version of the openHABian Configuration Tool" \
  "02 | Upgrade System"         "Upgrade all installed software packages to their newest version" \
  "10 | Basic Setup"            "Perform basic setup steps (packages, bash, permissions, ...)" \
  "11a| Zulu OpenJDK"           "Install Zulu Embedded OpenJDK Java 8 (ARMv7 only)" \
  "11b| Oracle Java 8"          "Install Oracle Java 8 provided by WebUpd8Team (i386+ARM)" \
  "12 | openHAB 2"              "Install openHAB 2.0 (stable)" \
  "13 | Samba"                  "Install the Samba file sharing service and set up openHAB 2 shares" \
  "14 | Karaf SSH Console"      "Bind the Karaf SSH console to all external interfaces" \
  "15 | NGINX Setup"            "Setup a reverse proxy with password authentication or HTTPS access" \
  "20 | Optional: KNX"          "Set up the KNX daemon knxd" \
  "21 | Optional: Homegear"     "Set up the Homematic CCU2 emulation software Homegear" \
  "22 | Optional: Mosquitto"    "Set up the MQTT broker Mosquitto" \
  "23 | Optional: 1wire"        "Set up owserver and related packages for working with 1wire" \
  "24 | Optional: Grafana"      "Set up InfluxDB+Grafana as a powerful graphing solution" \
  "30 | Serial Port"            "Enable the RPi serial port for peripherals like Razberry, SCC, ..." \
  "31 | RPi3 Wifi"              "Configure build-in Raspberry Pi 3 Wifi" \
  "32 | Move root to USB"       "Move the system root from the SD card to a USB device (SSD or stick)" \
  3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 1
  elif [ $RET -eq 0 ]; then
    case "$choice" in
      00\ *) show_about ;;
      01\ *) openhabian_update ;;
      02\ *) system_upgrade ;;
      10\ *) basic_setup ;;
      11a*) java_zulu_embedded ;;
      11b*) java_webupd8 ;;
      12\ *) openhab2_full_setup ;;
      13\ *) samba_setup ;;
      14\ *) openhab_shell_interfaces ;;
      15\ *) nginx_setup ;;
      20\ *) knxd_setup ;;
      21\ *) homegear_setup ;;
      22\ *) mqtt_setup ;;
      23\ *) 1wire_setup ;;
      24\ *) influxdb_grafana_setup ;;
      30\ *) prepare_serial_port ;;
      31\ *) wifi_setup_rpi3 ;;
      32\ *) move_root2usb ;;
      40\ *) change_admin_password ;;
      *) whiptail --msgbox "Error: unrecognized option" 10 60 ;;
    esac || whiptail --msgbox "There was an error running option:\n\n  \"$choice\"" 10 60
    return 0
  else
    echo "Bye Bye! :)"
    exit 1
  fi
}

if [[ -n "$UNATTENDED" ]]; then
  #unattended installation (from within raspbian-ua-netinst chroot)
  locale_timezone_settings
  if is_pi; then first_boot_script; fi # TODO: Remove after new RPi image includes this
  if is_pi; then memory_split; fi
  basic_packages
  needed_packages
  bashrc_copy
  vimrc_copy
  firemotd
  java_zulu_embedded
  openhab2_full_setup
  samba_setup
  etckeeper
  misc_system_settings
else
  while show_main_menu; do
    true
  done
  system_check_default_password
  echo -e "\n[openHABian] We hope you got what you came for! See you again soon ;)"
fi

# vim: filetype=sh
