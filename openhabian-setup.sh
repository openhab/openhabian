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

# Log with timestamp
timestamp() { date +"%F_%T_%Z"; }

# Make sure only root can run our script
echo -n "$(timestamp) [openHABian] Checking for root privileges... "
if [[ $EUID -ne 0 ]]; then
  echo ""
  echo "This script must be run as root. Did you mean 'sudo openhabian-config'?" 1>&2
  echo "More info: http://docs.openhab.org/installation/openhabian.html"
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
is_pizerow() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[cC][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
is_pione() {
  if grep -q "^Revision\s*:\s*00[0-9a-fA-F][0-9a-fA-F]$" /proc/cpuinfo; then
    return 0
  elif  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[0-36][0-9a-fA-F]$" /proc/cpuinfo; then
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
  # needed for raspbian-ua-netinst chroot env
  if [ "$hostname" == "openHABianPi" ] || [ "$boot_volume_label" == "openHABian" ]; then return 0; fi
  # normal conditions
  if is_pizero || is_pizerow || is_pione || is_pitwo || is_pithree; then return 0; fi
  return 1
}
is_pine64() {
  [[ $(uname -r) =~ "pine64-longsleep" ]]
  return $?
}
is_arm() {
  case "$(uname -m)" in
    armv6l|armv7l|armhf|arm64|aarch64) return 0 ;;
    *) return 1 ;;
  esac
}
is_ubuntu() {
  [[ $(lsb_release -d) =~ "Ubuntu" ]]
  return $?
}
is_debian() {
  [[ $(lsb_release -d) =~ "Debian" ]]
  return $?
}
is_jessie() {
  [[ $(lsb_release -c) =~ "jessie" ]]
  return $?
}

load_create_config() {
  if [ -f "$CONFIGFILE" ]; then
    echo -n "$(timestamp) [openHABian] Loading configuration file '$CONFIGFILE'... "
  elif [ ! -f "$CONFIGFILE" ] && [ -f /boot/installer-config.txt ]; then
    echo -n "$(timestamp) [openHABian] Copying and loading configuration file '$CONFIGFILE'... "
    cp /boot/installer-config.txt $CONFIGFILE
  elif [ ! -f "$CONFIGFILE" ] && [ -n "$UNATTENDED" ]; then
    echo "$(timestamp) [openHABian] Error in unattended mode: Configuration file '$CONFIGFILE' not found... FAILED" 1>&2
    exit 1
  else
    echo -n "$(timestamp) [openHABian] Setting up and loading configuration file '$CONFIGFILE' in manual setup... "
    question="Welcome to openHABian!\n\nPlease provide the name of your Linux user i.e. the account you normally log in with.\nTypical user names are 'pi' or 'ubuntu'."
    input=$(whiptail --title "openHABian Configuration Tool - Manual Setup" --inputbox "$question" 15 80 3>&1 1>&2 2>&3)
    if ! id -u "$input" &>/dev/null; then
      echo "FAILED"
      echo "$(timestamp) [openHABian] Error: The provided user name is not a valid system user. Please try again. Exiting ..." 1>&2
      exit 1
    fi
    cp $SCRIPTDIR/openhabian.conf.dist $CONFIGFILE
    sed -i "s/username=.*/username=$input/g" $CONFIGFILE
  fi
  source "$CONFIGFILE"
  echo "OK"
}

clean_config_userpw() {
  cond_redirect sed -i "s/^userpw=.*/\#userpw=xxxxxxxx/g" $CONFIGFILE
}

whiptail_check() {
  if ! command -v whiptail &>/dev/null; then
    echo -n "$(timestamp) [openHABian] Installing whiptail... "
    cond_redirect apt update
    cond_redirect apt -y install whiptail
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  fi
}

ua-netinst_check() {
  if [ -f "/boot/config-reinstall.txt" ]; then
    introtext="Attention: It was brought to our attention that the old openHABian ua-netinst based image has a problem with a lately updated Linux package.
If you upgrade(d) the package 'raspberrypi-bootloader-nokernel' your Raspberry Pi will run into a Kernel Panic upon reboot!
\nDo not Upgrade, do not Reboot!
\nA preliminary solution is to not upgrade the system (via the Upgrade menu entry or 'apt upgrade') or to modify a configuration file. In the long run we would recommend to switch over to the new openHABian Raspbian based system image! This error message will keep reapearing even after you fixed the issue at hand.
Please find all details regarding the issue and the resolution of it at: https://github.com/openhab/openhabian/issues/147"
    if ! (whiptail --title "openHABian Raspberry Pi ua-netinst image detected" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 20 80) then return 0; fi
  fi
}

openhabian_hotfix() {
  if ! grep -q "sleep" /etc/cron.d/firemotd; then
    introtext="It was brought to our attention that openHABian systems cause requests spikes on remote package update servers. This unwanted behavior is related to a simple cronjob configuration mistake and the fact that the openHABian user base has grown quite big over the last couple of months. Please continue to apply the appropriate modification to your system. Thank you."
    if ! (whiptail --title "openHABian Hotfix Needed" --yes-button "Continue" --no-button "Cancel" --yesno "$introtext" 15 80) then return 0; fi
    firemotd
  fi
}

timezone_setting() {
  source "$CONFIGFILE"
  if [ -n "$INTERACTIVE" ]; then
    echo -n "$(timestamp) [openHABian] Setting timezone based on user choice... "
    dpkg-reconfigure tzdata
  elif [ ! -z "${timezone+x}" ]; then
    echo -n "$(timestamp) [openHABian] Setting timezone based on openhabian.conf... "
    cond_redirect timedatectl set-timezone $timezone
  else
    echo -n "$(timestamp) [openHABian] Setting timezone based on IP geolocation... "
    if ! command -v tzupdate &>/dev/null; then
      cond_redirect apt update
      cond_redirect apt -y install python-pip
      cond_redirect pip install --upgrade tzupdate
      if [ $? -ne 0 ]; then echo "FAILED (pip)"; return 1; fi
    fi
    cond_redirect pip install --upgrade tzupdate
    cond_redirect tzupdate
  fi
  if [ $? -eq 0 ]; then echo -e "OK ($(cat /etc/timezone))"; else echo "FAILED"; return 1; fi
}

locale_setting() {
  if [ -n "$INTERACTIVE" ]; then
    echo "$(timestamp) [openHABian] Setting locale based on user choice... "
    dpkg-reconfigure locales
    loc=$(grep "LANG=" /etc/default/locale | sed 's/LANG=//g')
    cond_redirect update-locale LANG=$loc LC_ALL=$loc LC_CTYPE=$loc LANGUAGE=$loc
    whiptail --title "Change Locale" --msgbox "For the locale change to take effect, please reboot your system now." 10 60
    return 0
  fi

  echo -n "$(timestamp) [openHABian] Setting locale based on openhabian.conf... "
  source "$CONFIGFILE"
  if is_ubuntu; then
    cond_redirect locale-gen $locales
  else
    for loc in $locales; do sed -i "/$loc/s/^# //g" /etc/locale.gen; done
    cond_redirect locale-gen
  fi
  cond_redirect dpkg-reconfigure --frontend=noninteractive locales
  cond_redirect LANG=$system_default_locale; export LANG &>/dev/null
  cond_redirect LC_ALL=$system_default_locale; export LC_ALL &>/dev/null
  cond_redirect LC_CTYPE=$system_default_locale; export LC_CTYPE &>/dev/null
  cond_redirect LANGUAGE=$system_default_locale; export LANGUAGE &>/dev/null
  cond_redirect update-locale LANG=$system_default_locale LC_ALL=$system_default_locale LC_CTYPE=$system_default_locale LANGUAGE=$system_default_locale
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

hostname_change() {
  echo -n "$(timestamp) [openHABian] Setting hostname of the base system... "
  if [ -n "$INTERACTIVE" ]; then
    new_hostname=$(whiptail --title "Change Hostname" --inputbox "Please enter the new system hostname (no special characters, no spaces):" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 1; fi
    if ( echo "$new_hostname" | grep -q ' ' ) || [ -z "$new_hostname" ]; then
      whiptail --title "Change Hostname" --msgbox "The hostname you've entered is not a valid hostname. Please try again." 10 60
      echo "FAILED"
      return 1
    fi
  else
    source "$CONFIGFILE"
    new_hostname="$hostname"
  fi
  hostnamectl set-hostname "$new_hostname" &>/dev/null
  hostname "$new_hostname" &>/dev/null
  echo "$new_hostname" > /etc/hostname
  sed -i "s/127.0.1.1.*/127.0.1.1 $new_hostname/" /etc/hosts

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Change Hostname" --msgbox "For the hostname change to take effect, please reboot your system now." 10 60
  fi
  echo "OK"
}

memory_split() {
  echo -n "$(timestamp) [openHABian] Setting the GPU memory split down to 16MB for headless system... "
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
  echo -n "$(timestamp) [openHABian] Installing basic can't-be-wrong packages (screen, vim, ...)... "
  if is_pi; then
    #cond_redirect wget -O /usr/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update
    #cond_redirect chmod +x /usr/bin/rpi-update
    cond_redirect rm -f /usr/bin/rpi-update
  fi
  cond_redirect apt update
  apt remove raspi-config &>/dev/null || true
  cond_redirect apt -y install screen vim nano mc vfu bash-completion htop curl wget multitail git bzip2 zip unzip xz-utils software-properties-common man-db whiptail acl usbutils
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

needed_packages() {
  # Install apt-transport-https - update packages through https repository
  # Install bc + sysstat - needed for FireMotD
  # Install avahi-daemon - hostname based discovery on local networks
  # Install python/python-pip - for python packages
  echo -n "$(timestamp) [openHABian] Installing additional needed packages... "
  #cond_redirect apt update
  cond_redirect apt -y install apt-transport-https bc sysstat avahi-daemon python python-pip
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

  if is_pithree || is_pizerow; then
    echo -n "$(timestamp) [openHABian] Installing additional bluetooth packages... "
    cond_redirect apt -y install bluez python-bluez python-dev libbluetooth-dev raspberrypi-sys-mods pi-bluetooth
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  fi
}

bashrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned bash config files to system... "
  cp $SCRIPTDIR/includes/bash.bashrc /etc/bash.bashrc
  cp $SCRIPTDIR/includes/bashrc-root /root/.bashrc
  cp $SCRIPTDIR/includes/bash_profile /home/$username/.bash_profile
  chown $username:$username /home/$username/.bash_profile
  echo "OK"
}

vimrc_copy() {
  echo -n "$(timestamp) [openHABian] Adding slightly tuned vim config file to system... "
  cp $SCRIPTDIR/includes/vimrc /etc/vim/vimrc
  echo "OK"
}

java_webupd8() {
  echo -n "$(timestamp) [openHABian] Preparing and Installing Oracle Java 8 Web Upd8 repository... "
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
  echo -n "$(timestamp) [openHABian] Installing Zulu Embedded OpenJDK... "
  if is_arm; then _arch="[arch=armhf]"; fi
  echo "deb $_arch http://repos.azulsystems.com/debian stable main" > /etc/apt/sources.list.d/zulu-embedded.list
  cond_redirect apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 219BD9C9
  if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
  if is_pine64; then cond_redirect dpkg --add-architecture armhf; fi
  cond_redirect apt update
  cond_redirect apt -y install zulu-embedded-8
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

# Unused
java_zulu_embedded_archive() {
  echo -n "$(timestamp) [openHABian] Installing Zulu Embedded OpenJDK ARM build (archive)... "
  cond_redirect dpkg --add-architecture armhf
  cond_redirect apt update
  cond_redirect apt -y install libc6:armhf libfontconfig1:armhf # https://github.com/openhab/openhabian/issues/93#issuecomment-279401481
  if [ $? -ne 0 ]; then echo "FAILED (prerequisites)"; exit 1; fi
  # Static link, not up to date: https://www.azul.com/downloads/zulu/zdk-8-ga-linux_aarch32hf.tar.gz
  cond_redirect wget -O ezdk.tar.gz http://cdn.azul.com/zulu-embedded/bin/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf.tar.gz
  if [ $? -ne 0 ]; then echo "FAILED (download)"; exit 1; fi
  cond_redirect mkdir /opt/zulu-embedded
  cond_redirect tar xvfz ezdk.tar.gz -C /opt/zulu-embedded
  if [ $? -ne 0 ]; then echo "FAILED (extract)"; exit 1; fi
  cond_redirect rm -f ezdk.tar.gz
  cond_redirect chown -R 0:0 /opt/zulu-embedded
  cond_redirect update-alternatives --auto java
  cond_redirect update-alternatives --auto javac
  cond_redirect update-alternatives --install /usr/bin/java java /opt/zulu-embedded/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf/bin/java 2162
  cond_redirect update-alternatives --install /usr/bin/javac javac /opt/zulu-embedded/ezdk-1.8.0_112-8.19.0.31-eval-linux_aarch32hf/bin/javac 2162
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED (setup)"; exit 1; fi
}

openhab2() {
  echo -n "$(timestamp) [openHABian] Installing openHAB 2.1 (stable)... "
  echo "deb http://dl.bintray.com/openhab/apt-repo2 stable main" > /etc/apt/sources.list.d/openhab2.list
  #echo "deb http://dl.bintray.com/openhab/apt-repo2 testing main" > /etc/apt/sources.list.d/openhab2.list
  #echo "deb http://openhab.jfrog.io/openhab/openhab-linuxpkg unstable main" > /etc/apt/sources.list.d/openhab2.list
  cond_redirect wget -O openhab-key.asc 'https://bintray.com/user/downloadSubjectPublicKey?username=openhab'
  cond_redirect apt-key add openhab-key.asc
  if [ $? -ne 0 ]; then echo "FAILED (key)"; exit 1; fi
  rm -f openhab-key.asc
  cond_redirect apt update
  cond_redirect apt -y install openhab2
  if [ $? -ne 0 ]; then echo "FAILED (apt)"; exit 1; fi
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable openhab2.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  if [ -n "$UNATTENDED" ]; then
    cond_redirect systemctl stop openhab2.service || true
  else
    cond_redirect systemctl start openhab2.service || true
  fi
}

openhab2_unstable() {
  introtext="You are about to switch over to the latest openHAB 2 unstable build. The daily snapshot builds contain the latest features and improvements but may also suffer from bugs or incompatibilities.
If prompted if files should be replaced by newer ones, select Yes. Please be sure to take a full openHAB configuration backup first!"
  successtext="The latest unstable/snapshot build of openHAB 2 is now running on your system. If already available, check the function of your configuration now. If you find any problem or bug, please report it and state the snapshot version you are on. To stay up-to-date with improvements and bug fixes you should upgrade your packages regularly."
  echo -n "$(timestamp) [openHABian] Installing or switching to openHAB 2.2 SNAPSHOT (unstable)... "

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo "deb http://openhab.jfrog.io/openhab/openhab-linuxpkg unstable main" > /etc/apt/sources.list.d/openhab2.list
  cond_redirect apt update
  cond_redirect apt -y install openhab2
  if [ $? -ne 0 ]; then echo "FAILED (apt)"; exit 1; fi
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable openhab2.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  cond_redirect systemctl restart openhab2.service || true

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
}

openhab2_stable() {
  introtext="You are about to switch over to the stable openHAB 2.1.0 build. When prompted if files should be replaced by newer ones, select Yes. Please be sure to take a full openHAB configuration backup first!"
  successtext="The stable release of openHAB 2.1.0 is now installed on your system. Please test the correct behavior of your setup. Check the \"openHAB 2.1 Release Notes\" and the official announcements to learn about additons, fixes and changes:\n
  ➡ http://www.kaikreuzer.de/2017/06/28/openhab21
  ➡ https://github.com/openhab/openhab-distro/releases/tag/2.1.0"
  echo -n "$(timestamp) [openHABian] Installing or switching to openHAB 2.1.0 (stable)... "

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo "deb https://dl.bintray.com/openhab/apt-repo2 stable main" > /etc/apt/sources.list.d/openhab2.list
  cond_redirect wget -O openhab-key.asc 'https://bintray.com/user/downloadSubjectPublicKey?username=openhab'
  cond_redirect apt-key add openhab-key.asc
  if [ $? -ne 0 ]; then echo "FAILED (key)"; exit 1; fi
  rm -f openhab-key.asc
  cond_redirect apt update
  cond_redirect apt -y install openhab2=2.1.0-1
  if [ $? -ne 0 ]; then echo "FAILED (apt)"; exit 1; fi
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable openhab2.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  cond_redirect systemctl restart openhab2.service || true

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 15 80
  fi
}

vim_openhab_syntax() {
  echo -n "$(timestamp) [openHABian] Adding openHAB syntax to vim editor... "
  # these may go to "/usr/share/vim/vimfiles" ?
  mkdir -p /home/$username/.vim/{ftdetect,syntax}
  cond_redirect wget -O /home/$username/.vim/syntax/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/syntax/openhab.vim
  cond_redirect wget -O /home/$username/.vim/ftdetect/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/ftdetect/openhab.vim
  chown -R $username:$username /home/$username/.vim
  echo "OK"
}

nano_openhab_syntax() {
  # add nano syntax highlighting
  echo -n "$(timestamp) [openHABian] Adding openHAB syntax to nano editor... "
  cond_redirect wget -O /usr/share/nano/openhab.nanorc https://raw.githubusercontent.com/airix1/openhabnano/master/openhab.nanorc
  echo -e "\n## openHAB files\ninclude \"/usr/share/nano/openhab.nanorc\"" >> /etc/nanorc
  echo "OK"
}

samba_setup() {
  echo -n "$(timestamp) [openHABian] Setting up Samba network shares... "
  if ! command -v samba &>/dev/null; then
    cond_redirect apt update
    cond_redirect apt -y install samba
    if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
  fi
  cp $SCRIPTDIR/includes/smb.conf /etc/samba/smb.conf
  if ! /usr/bin/smbpasswd -e $username &>/dev/null; then
    ( (echo "$userpw"; echo "$userpw") | /usr/bin/smbpasswd -s -a $username > /dev/null )
  fi
  cond_redirect systemctl enable smbd.service
  cond_redirect systemctl restart smbd.service
  echo "OK"
}

firemotd() {
  echo -n "$(timestamp) [openHABian] Downloading and setting up FireMotD... "
  rm -rf /opt/FireMotD
  #cond_redirect git clone https://github.com/willemdh/FireMotD.git /opt/FireMotD
  cond_redirect git clone https://github.com/ThomDietrich/FireMotD.git /opt/FireMotD
  if [ $? -eq 0 ]; then
    # the following is already in bash_profile by default
    #echo -e "\necho\n/opt/FireMotD/FireMotD --theme gray \necho" >> /home/$username/.bash_profile
    # initial apt updates check
    cond_redirect /bin/bash /opt/FireMotD/FireMotD -S
    # invoke apt updates check every night
    echo "# FireMotD system updates check (randomly execute between 0:00:00 and 5:59:59)" > /etc/cron.d/firemotd
    echo "0 0 * * * root perl -e 'sleep int(rand(21600))' && /bin/bash /opt/FireMotD/FireMotD -S &>/dev/null" >> /etc/cron.d/firemotd
    # invoke apt updates check after every apt action ('apt upgrade', ...)
    echo "DPkg::Post-Invoke { \"if [ -x /opt/FireMotD/FireMotD ]; then echo -n 'Updating FireMotD available updates count ... '; /bin/bash /opt/FireMotD/FireMotD -S; echo ''; fi\"; };" > /etc/apt/apt.conf.d/15firemotd
    #TODO move to a better position
    echo "Acquire { http::User-Agent \"Debian APT-HTTP/1.3 openHABian\"; };" > /etc/apt/apt.conf.d/02useragent
    echo "OK"
  else
    echo "FAILED"
  fi
}

etckeeper() {
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

nodejs() {
  if ! command -v npm &>/dev/null; then
    echo -n "$(timestamp) [openHABian] Installing Node.js (prerequisite for other packages)... "
    FAILED=0
    cond_redirect wget -O /tmp/nodejs-v7.x.sh https://deb.nodesource.com/setup_7.x || FAILED=1
    cond_redirect bash /tmp/nodejs-v7.x.sh || FAILED=1
    if [ $FAILED -eq 1 ]; then echo "FAILED (nodejs preparations)"; exit 1; fi
    #cond_redirect apt update # part of the node script above
    cond_redirect apt -y install nodejs
    if [ $? -ne 0 ]; then echo "FAILED (nodejs installation)"; exit 1; fi
    if command -v npm &>/dev/null; then echo "OK"; else echo "FAILED (service)"; exit 1; fi
  fi
}

frontail() {
  nodejs
  echo -n "$(timestamp) [openHABian] Installing the openHAB Log Viewer (frontail)... "
  cond_redirect npm install -g frontail
  if [ $? -ne 0 ]; then echo "FAILED (frontail)"; exit 1; fi
  cond_redirect npm update -g frontail
  #
  frontail_base="/usr/lib/node_modules/frontail"
  cp $SCRIPTDIR/includes/frontail-preset.json $frontail_base/preset/openhab.json
  cp $SCRIPTDIR/includes/frontail-theme.css $frontail_base/lib/web/assets/styles/openhab.css
  cp $SCRIPTDIR/includes/frontail.service /etc/systemd/system/frontail.service
  chmod 664 /etc/systemd/system/frontail.service
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable frontail.service
  cond_redirect systemctl restart frontail.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED (service)"; exit 1; fi
}

nodered() {
  nodejs
  echo -n "$(timestamp) [openHABian] Installing Node-RED... "
  FAILED=0
  cond_redirect wget -O /tmp/update-nodejs-and-nodered.sh https://raw.githubusercontent.com/node-red/raspbian-deb-package/master/resources/update-nodejs-and-nodered || FAILED=1
  cond_redirect bash /tmp/update-nodejs-and-nodered.sh || FAILED=1
  if [ $FAILED -eq 1 ]; then echo "FAILED (nodered)"; exit 1; fi
  cond_redirect npm install -g node-red-contrib-bigtimer
  if [ $? -ne 0 ]; then echo "FAILED (nodered bigtimer addon)"; exit 1; fi
  cond_redirect npm update -g node-red-contrib-bigtimer
  cond_redirect npm install -g node-red-contrib-openhab2
  if [ $? -ne 0 ]; then echo "FAILED (nodered openhab2 addon)"; exit 1; fi
  cond_redirect npm update -g node-red-contrib-openhab2
  cond_redirect systemctl daemon-reload
  cond_redirect systemctl enable nodered.service
  cond_redirect systemctl restart nodered.service
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED (service)"; exit 1; fi
}

yo_generator() {
  nodejs
  echo -n "$(timestamp) [openHABian] Installing the Yeoman openHAB generator... "
  cond_redirect npm install -g yo generator-openhab
  if [ $? -ne 0 ]; then echo "FAILED (yo_generator)"; exit 1; fi
  cond_redirect npm update -g generator-openhab
}

srv_bind_mounts() {
  echo -n "$(timestamp) [openHABian] Preparing openHAB folder mounts under /srv/... "
  sed -i "/openhab2/d" /etc/fstab
  sed -i "/^$/d" /etc/fstab
  (
    echo ""
    echo "/usr/share/openhab2          /srv/openhab2-sys           none bind 0 0"
    echo "/etc/openhab2                /srv/openhab2-conf          none bind 0 0"
    echo "/var/lib/openhab2            /srv/openhab2-userdata      none bind 0 0"
    echo "/var/log/openhab2            /srv/openhab2-logs          none bind 0 0"
    echo "/usr/share/openhab2/addons   /srv/openhab2-addons        none bind 0 0"
  ) >> /etc/fstab
  cond_redirect cat /etc/fstab
  cond_redirect mkdir -p /srv/openhab2-{sys,conf,userdata,logs,addons}
  cond_redirect cp $SCRIPTDIR/includes/srv_readme.txt /srv/README.txt
  cond_redirect chmod ugo+w /srv /srv/README.txt
  cond_redirect mount --all --verbose
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

permissions_corrections() {
  echo -n "$(timestamp) [openHABian] Applying file permissions recommendations... "
  if ! id -u openhab &>/dev/null; then
    echo "FAILED (please execute after openHAB was installed)"
    exit 1
  fi
  cond_redirect adduser openhab dialout
  cond_redirect adduser openhab tty
  cond_redirect adduser openhab gpio
  cond_redirect adduser $username openhab
  cond_redirect adduser $username dialout
  cond_redirect adduser $username tty
  cond_redirect adduser $username gpio
  #
  openhab_folders=(/etc/openhab2 /var/lib/openhab2 /var/log/openhab2 /usr/share/openhab2/addons)
  cond_redirect chown openhab:$username /srv /srv/README.txt
  cond_redirect chmod ugo+w /srv /srv/README.txt
  cond_redirect chown -R openhab:openhab /usr/share/openhab2
  cond_redirect chown -R openhab:$username /opt ${openhab_folders[@]}
  cond_redirect chmod -R ug+wX /opt ${openhab_folders[@]}
  cond_redirect chown -R $username:$username /home/$username
  #
  cond_redirect setfacl -R --remove-all ${openhab_folders[@]}
  cond_redirect setfacl -R -m g::rwX ${openhab_folders[@]}
  cond_redirect setfacl -R -m d:g::rwX ${openhab_folders[@]}
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

misc_system_settings() {
  echo -n "$(timestamp) [openHABian] Applying miscellaneous system settings... "
  cond_redirect setcap 'cap_net_raw,cap_net_admin=+eip cap_net_bind_service=+ep' $(realpath /usr/bin/java)
  if is_pine64; then cond_redirect dpkg --add-architecture armhf; fi
  # user home note
  echo -e "This is your linux user's \"home\" folder.\nPlace personal files, programs or scripts here." > /home/$username/README.txt
  # prepare SSH key file for the end user
  mkdir /home/$username/.ssh
  chmod 700 /home/$username/.ssh
  touch /home/$username/.ssh/authorized_keys
  chmod 600 /home/$username/.ssh/authorized_keys
  chown -R $username:$username /home/$username/.ssh
  echo "OK"
}

pine64_platform_scripts() {
  echo -n "$(timestamp) [openHABian] Executing pine64 platform scripts (longsleep)... "
  if [ -f "/usr/local/sbin/pine64_update_kernel.sh" ]; then
    cond_redirect /usr/local/sbin/pine64_update_kernel.sh || echo -n "FAILED (kernel) "
    cond_redirect /usr/local/sbin/pine64_update_uboot.sh || echo -n "FAILED (uboot) "
    cond_redirect /usr/local/sbin/pine64_fix_whatever.sh || echo -n "FAILED (whatever) "
    cond_redirect /usr/local/sbin/resize_rootfs.sh || echo -n "FAILED (resize) "
    echo "OK"
  else
    echo "FAILED"
  fi
}

pine64_fixed_mac() {
  echo -n "$(timestamp) [openHABian] Assigning fixed MAC address to eth0 (longsleep)... "
  if ! grep -q "mac_addr=" /boot/uEnv.txt; then
    MAC=$(cat /sys/class/net/eth0/address)
    sed -i "/^console=/ s/$/ mac_addr=$MAC/" /boot/uEnv.txt
    echo "OK"
  else
    echo "SKIPPED"
  fi
}

openhab_shell_interfaces() {
  introtext="The Karaf console is a powerful tool for every openHAB user. It allows you too have a deeper insight into the internals of your setup. Further details: http://docs.openhab.org/administration/console.html
\nThis routine will bind the console to all interfaces and thereby make it available to other devices in your network. Please provide a secure password for this connection (letters and numbers only! default: habopen):"
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="The Karaf console was successfully opened on all interfaces. openHAB has been restarted. You should be able to reach the console via:
\n'ssh://openhab:<password>@<openhabian-IP> -p 8101'\n
Please be aware, that the first connection attempt may take a few minutes or may result in a timeout due to key generation."

  echo -n "$(timestamp) [openHABian] Binding the Karaf console on all interfaces... "
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
  successtext="All done. After a reboot the serial console will be available via /dev/ttyAMA0 or /dev/ttyS0 (depends on your device)."
  # \nThis might be a good point in time to update your Raspberry Pi firmware (if this is a RPi) and reboot:\n
  # sudo rpi-update
  # sudo reboot"

  echo -n "$(timestamp) [openHABian] Configuring serial console for serial port peripherals... "

  # Find current settings
  if is_pi && grep -q "enable_uart=1" /boot/config.txt; then sel_1="ON"; else sel_1="OFF"; fi
  if is_pithree && grep -q "dtoverlay=pi3-miniuart-bt" /boot/config.txt; then sel_2="ON"; else sel_2="OFF"; fi
  if grep -q "/dev/ttyS0:/dev/ttyS2" /etc/default/openhab2; then sel_3="ON"; else sel_3="OFF"; fi

  if [ -n "$INTERACTIVE" ]; then
    selection=$(whiptail --title "Prepare Serial Port" --checklist --separate-output "$introtext" 20 78 3 \
    "1"  "(RPi) Disable serial console           (Razberry, SCC, Enocean)" $sel_1 \
    "2"  "(RPi3) Disable Bluetooth module        (Razberry)" $sel_2 \
    "3"  "Add common serial ports to openHAB JVM (Razberry, Enocean)" $sel_3 \
    3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then echo "CANCELED"; return 0; fi
  else
    echo "SKIPPED"
    return 0
  fi

  if [[ $selection == *"1"* ]] && is_pi; then
    cond_echo ""
    cond_echo "Adding 'enable_uart=1' to /boot/config.txt"
    if grep -q "enable_uart" /boot/config.txt; then
      sed -i 's/^.*enable_uart=.*$/enable_uart=1/g' /boot/config.txt
    else
      echo "enable_uart=1" >> /boot/config.txt
    fi
    cond_echo "Removing serial console and login shell from /boot/cmdline.txt and /etc/inittab"
    cp /boot/cmdline.txt /boot/cmdline.txt.bak
    cp /etc/inittab /etc/inittab.bak &>/dev/null
    sed -i 's/console=tty.*console=tty1/console=tty1/g' /boot/cmdline.txt
    sed -i 's/console=serial.*console=tty1/console=tty1/g' /boot/cmdline.txt
    sed -i 's/^T0/\#T0/g' /etc/inittab &>/dev/null
    cond_redirect systemctl disable serial-getty@ttyAMA0.service
    cond_redirect systemctl disable serial-getty@serial0.service
    cond_redirect systemctl disable serial-getty@ttyS0.service
  #else
    #TODO this needs to be tested when/if someone actually cares...
    #cp /boot/cmdline.txt.bak /boot/cmdline.txt
    #cp /etc/inittab.bak /etc/inittab
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
    if is_pithree; then
      cond_echo "Removing 'dtoverlay=pi3-miniuart-bt' from /boot/config.txt"
      sed -i '/dtoverlay=pi3-miniuart-bt/d' /boot/config.txt
    fi
  fi

  if [[ $selection == *"3"* ]]; then
    cond_echo "Adding serial ports to openHAB java virtual machine in /etc/default/openhab2"
    sed -i 's#EXTRA_JAVA_OPTS=.*#EXTRA_JAVA_OPTS="-Dgnu.io.rxtx.SerialPorts=/dev/ttyUSB0:/dev/ttyS0:/dev/ttyS2:/dev/ttyACM0:/dev/ttyAMA0"#g' /etc/default/openhab2
  else
    cond_echo "Removing serial ports from openHAB java virtual machine in /etc/default/openhab2"
    sed -i 's#EXTRA_JAVA_OPTS=.*#EXTRA_JAVA_OPTS=""#g' /etc/default/openhab2
  fi

  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "$successtext" 16 80
  fi
  echo "OK (Reboot needed)"
}

wifi_setup() {
  echo -n "$(timestamp) [openHABian] Setting up Wifi (PRi3 or Pine A64)... "
  if ! is_pithree && ! is_pizerow && ! is_pine64; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "Wifi setup: This option is for the Pi3, Pi0W or the Pine A64 system only." 10 60
    fi
    echo "FAILED"; return 1
  fi
  if [ -n "$INTERACTIVE" ]; then
    SSID=$(whiptail --title "Wifi Setup" --inputbox "Which Wifi (SSID) do you want to connect to?" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 1; fi
    PASS=$(whiptail --title "Wifi Setup" --inputbox "What's the password for that Wifi?" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 1; fi
  else
    echo -n "Setting default SSID and password in 'wpa_supplicant.conf' "
    SSID="myWifiSSID"
    PASS="myWifiPassword"
  fi
  if is_pithree; then cond_redirect apt -y install firmware-brcm80211; fi
  cond_redirect apt -y install wpasupplicant wireless-tools
  echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1" > /etc/wpa_supplicant/wpa_supplicant.conf
  echo -e "network={\n\tssid=\"$SSID\"\n\tpsk=\"$PASS\"\n}" >> /etc/wpa_supplicant/wpa_supplicant.conf
  if grep -q "wlan0" /etc/network/interfaces; then
    cond_echo ""
    cond_echo "Not writing to '/etc/network/interfaces', wlan0 entry already available. You might need to check, adopt or remove these lines."
    cond_echo ""
  else
    echo -e "\nallow-hotplug wlan0\niface wlan0 inet manual\nwpa-roam /etc/wpa_supplicant/wpa_supplicant.conf\niface default inet dhcp" >> /etc/network/interfaces
  fi
  cond_redirect wpa_cli reconfigure
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

  if ! is_pi; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "Move root to USB: This option is for the Raspberry Pi only." 10 60
    fi
    echo "FAILED"; return 1
  fi

  if ! (whiptail --title "Move system root to '$NEWROOTPART'" --yes-button "Continue" --no-button "Back" --yesno "$infotext" 18 78) then
    return 0
  fi

  #check if system root is on partion 2 of the SD card
  #since 2017-06, rasbian uses PARTUUID=.... in cmdline.txt and fstab instead of /dev/mmcblk0p2...
  rootonsdcard=false 

  #extract rootpart
  rootpart=$(cat /boot/cmdline.txt | sed "s/.*root=\([a-zA-Z0-9\/=-]*\)\(.*\)/\1/") 

  if [[ $rootpart == *"PARTUUID="* ]]; then
    if blkid -l -t $rootpart | grep -q "/dev/mmcblk0p2"; then
      rootonsdcard=true
    fi
  elif [[ $rootpart == "/dev/mmcblk0p2" ]]; then
    rootonsdcard=true
  fi

  #exit if root is not on SDCARD
  if ! [ $rootonsdcard = true ]; then
    infotext="It seems as if your system root is not on the SD card.
       ***Aborting, process cant be started***"
    whiptail --title "System root not on SD card?" --msgbox "$infotext" 8 78
    return 0
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
  sed -i "s#$rootpart#$NEWROOTPART#" /mnt/etc/fstab

  echo "adjusting system root in kernel bootline"
  #make a copy of the original cmdline
  cp /boot/cmdline.txt /boot/cmdline.txt.sdcard
  #adjust system root in kernel bootline
  sed -i "s#root=$rootpart#root=$NEWROOTPART#" /boot/cmdline.txt

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

  echo -n "Grafana (fg2it)... "
  if is_jessie; then
    if is_pione || is_pizero || is_pizerow; then GRAFANA_REPO_PI1="-rpi-1b"; fi
    echo "deb https://dl.bintray.com/fg2it/deb${GRAFANA_REPO_PI1} jessie main" > /etc/apt/sources.list.d/grafana-fg2it.list || FAILED=2
    cond_redirect apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 379CE192D401AB61 || FAILED=2
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


create_backup_config() {
  config=$1
  confdir=/etc/amanda/${config}
  backupuser=$2
  tapes=$3
  size=$4
  storage=$5
  s3accesskey=$6
  s3secretkey=$7

  introtext="We need to prepare (to \"label\") your removable storage media."
  if [ "${config}" = "openhab-local-SD" ]; then
     introtext="${introtext}\nWe will ask you to insert a specific SD card number (or USB stick) into the device ${storage} and prompt you to confirm it's plugged in. This procedure will be repeated ${tapes} times as that is the number of media you specified to be in rotational use for backup purposes."
  else
     introtext="${introtext}\nFor permanent storage such as USB or NAS mounted storage, as well as for cloud based storage, we will create ${tapes} virtual containers."
  fi
  if [ -n "$INTERACTIVE" ]; then
      if ! (whiptail --title "Storage container creation" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi
  # create virtual 'tapes'
  ln -s ${storage}/slots ${storage}/slots/drive0;ln -s ${storage}/slots ${storage}/slots/drive1		# taper-parallel-write 2 so we need 2 virtual drives
  counter=1
  while [ ${counter} -le ${tapes} ]; do
      if [ "${config}" = "openhab-dir" ]; then
          mkdir -p ${storage}/slots/slot${counter}

          tpchanger="\"chg-disk:${storage}/slots\"    # The tape-changer glue script"
          tapetype="DIRECTORY"
      else
          if [ "${config}" = "openhab-local-SD" ]; then
              introtext="Please insert your removable storage medium number ${counter}."
              if [ -n "$INTERACTIVE" ]; then
	          if ! (whiptail --title "Correct SD card inserted?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
                  /bin/su - ${backupuser} -c "/usr/sbin/amlabel ${config} ${config}-${counter} slot ${counter}"
              fi
              tpchanger="\"chg-single:${sddev}\""
              tapetype="SD"
          else
              /bin/su - ${backupuser} -c "/usr/sbin/amlabel ${config} ${config}-${counter} slot ${counter}"
              tpchanger="\"chg-multi:s3:${s3accesskey}-backup/openhab-AWS/slot-{`seq -s, 1 ${tapes}`}\" # Number of virtual containers in your tapecycle"
              tapetype="AWS"
          fi
      fi

      let counter+=1
  done

# no mailer configured for now
#  if [ -n "$INTERACTIVE" ]; then
#     adminmail=$(whiptail --title "Admin reports" --inputbox "Enter the EMail address to send backup reports to. Note: Mail relaying is not enabled in openHABian yet." 10 60 3>&1 1>&2 2>&3)
#  fi

  /bin/grep -v ${config} /etc/cron.d/amanda; /usr/bin/touch /etc/cron.d/amanda
  
  echo "0 1 * * * ${backupuser} /usr/sbin/amdump ${config} &>/dev/null" >> /etc/cron.d/amanda
  echo "0 18 * * * ${backupuser} /usr/sbin/amcheck -m ${config} &>/dev/null" >> /etc/cron.d/amanda

  mkdir -p ${confdir}
  touch ${confdir}/tapelist
  hostname=`/bin/hostname`
  echo "${hostname} ${backupuser}" > /var/backups/.amandahosts
  echo "${hostname} root amindexd amidxtaped" >> /var/backups/.amandahosts
  echo "localhost ${backupuser}" >> /var/backups/.amandahosts
  echo "localhost root amindexd amidxtaped" >> /var/backups/.amandahosts


  infofile="/var/lib/amanda/${config}/curinfo"	      # Database directory
  logdir="/var/log/amanda/${config}" 		      # Log directory
  indexdir="/var/lib/amanda/${config}/index" 	      # Index directory
  /bin/mkdir -p $infofile $logdir $indexdir
  /bin/chown -R ${backupuser}:${backupuser} /var/backups/.amandahosts ${confdir} ${storage} $infofile $logdir $indexdir
  /bin/chmod -R g+rwx ${storage} 


  /bin/sed -e "s|%CONFIG|${config}|g" -e "s|%CONFDIR|${confdir}|g" -e "s|%BKPDIR|${bkpdir}|g" -e "s|%ADMIN|${adminmail}|g" -e "s|%TAPES|${tapes}|g" -e "s|%SIZE|${size}|g" -e "s|%TAPETYPE|${tapetype}|g" -e "s|%TPCHANGER|${tpchanger}|g" ${SCRIPTDIR}/includes/amanda.conf_template >${confdir}/amanda.conf

  if [ "${config}" = "openhab-AWS" ]; then
      echo "device_property \"S3_ACCESS_KEY\" \"${S3accesskey}\"	# Your S3 Access Key" >>${confdir}/amanda.conf
      echo "device_property \"S3_SECRET_KEY\" \"${S3secretkey}\"	# Your S3 Secret Key" >>${confdir}/amanda.conf
      echo "device_property \"S3_SSL\" \"YES\"				# Curl needs to have S3 Certification Authority (Verisign today) in its CA list. If connection fails, try setting this no NO" >>${confdir}/amanda.conf
  fi

  hostname=`/bin/hostname`
  if [ "${config}" = "openhab-local-SD" -o "${config}" = "openhab-dir" ]; then
      /bin/rm -f ${confdir}/disklist
      # don't backup SD by default as this can cause problems for large cards
      if [ -n "$INTERACTIVE" ]; then
          if (whiptail --title "Backup raw SD card, too ?" --yes-button "Backup SD" --no-button "Do not backup SD." --yesno "Do you want to create raw disk backups of your SD card ? Only recommended if it's 8GB or less, otherwise this can take too long. You can change this at any time by editing ${confdir}/disklist." 15 80) then 
	      echo "${hostname}	/dev/mmcblk0    	        amraw" >>${confdir}/disklist
	  fi   
      fi
      
      echo "${hostname}	/etc/openhab2			user-tar" >>${confdir}/disklist
      echo "${hostname}	/var/lib/openhab2		user-tar" >>${confdir}/disklist
  else
      echo "${hostname}	/etc/openhab2			comp-user-tar" >${confdir}/disklist
      echo "${hostname}	/var/lib/openhab2		comp-user-tar" >>${confdir}/disklist
  fi

  echo "index_server \"localhost\"" >${confdir}/amanda-client.conf
  echo "tapedev \"changer\"" >${confdir}/amanda-client.conf
  echo "auth \"local\"" >${confdir}/amanda-client.conf
}


amanda_setup() {

  introtext="This will setup a backup mechanism to allow for saving your openHAB setup and modifications to either a set of SD cards, USB attached or Amazon cloud storage.\nYou can add your own files/directories to be backed up, and you can store and create clones of your openHABian SD card to have an all-ready replacement in case of card failures."
  failtext="Sadly there was a problem setting up the selected option. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."
  successtext="Setup was successful. Amanda backup tool is now taking backups at 01:00. For further readings, start at http://wiki.zmanda.com/index.php/User_documentation."

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Amanda backup setup, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 15 80) then return 0; fi
  fi

  echo -n "$(timestamp) [openHABian] Setting up the Amanda backup system ... "
  backupuser="backup"


  cond_redirect apt install amanda-common amanda-server amanda-client

  matched=false
  canceled=false
  if [ -n "$INTERACTIVE" ]; then
      while [ "$matched" = false ] && [ "$canceled" = false ]; do
            password=$(whiptail --title "Authentication Setup" --passwordbox "Enter a password for $backupuser:" 15 80 3>&1 1>&2 2>&3)
            secondpassword=$(whiptail --title "Authentication Setup" --passwordbox "Please confirm the password:" 15 80 3>&1 1>&2 2>&3)
            if [ "$password" = "$secondpassword" ] && [ ! -z "$password" ]; then
                matched=true
            else
                password=$(whiptail --title "Authentication Setup" --msgbox "Password mismatched or blank... Please try again!" 15 80 3>&1 1>&2 2>&3)
            fi
      done
  fi
  /usr/sbin/chpasswd <<< "${backupuser}:${password}"
  /usr/bin/chsh -s /bin/bash ${backupuser}

  /bin/rm -f /etc/cron.d/amanda; /usr/bin/touch /etc/cron.d/amanda

# no SD set based config for now, requires latest Amanda which is not available as a package yet
#  if [ -n "$INTERACTIVE" ]; then
#    if (whiptail --title "Create SD card set based backup" --yes-button "Yes" --no-button "No" --yesno "Setup a backup mechanism based on a locally attached SD card writer and a set of SD cards. You can also use USB sticks, BUT you must ensure that the device name to access ALWAYS is the same. This is not guaranteed if you use different USB ports." 15 80) then
#        config=openhab-local-SD
#        sddev=$(whiptail --title "Card writer device" --inputbox "What's the device name of your SD card writer?" 10 60 3>&1 1>&2 2>&3)
#        tapes=$(whiptail --title "Number of SD cards in rotation" --inputbox "How many SD cards will you have available in rotation for backup purposes ?" 10 60 3>&1 1>&2 2>&3)
#        size=$(whiptail --title "SD card capacity" --inputbox "What's your backup SD card capacity in megabytes? If you use different sizes, specify the smallest one. The remaining capacity will remain unused." 10 60 3>&1 1>&2 2>&3)
#        create_backup_config ${config} ${backupuser} ${tapes} ${size} ${sddev}
#    fi
#  fi

  if [ -n "$INTERACTIVE" ]; then
    if (whiptail --title "Create file storage area based backup" --yes-button "Yes" --no-button "No" --yesno "Setup a backup mechanism based on locally attached or NAS mounted storage." 15 80) then
        config=openhab-dir
        dir=$(whiptail --title "Storage directory" --inputbox "What's the directory to store backups into?\nYou can specify any locally accessible directory, no matter if it's located on the internal SD card, an external USB-attached device such as a USB stick or HDD, or a NFS or CIFS share mounted off a NAS or other server in the network." 10 60 3>&1 1>&2 2>&3)
        tapes=15
        capacity=$(whiptail --title "Storage capacity" --inputbox "How much storage do you want to dedicate to your backup in megabytes ? Recommendation: 2-3 times the amount of data to be backed up." 10 60 3>&1 1>&2 2>&3)
	let size=${capacity}/${tapes}
	
        create_backup_config ${config} ${backupuser} ${tapes} ${size} ${dir}
    fi
  fi

  if [ -n "$INTERACTIVE" ]; then
    if (whiptail --title "Create Amazon S3 based backup" --yes-button "Yes" --no-button "No" --yesno "Setup a backup mechanism based on Amazon Web Services. You can get 5 GB of S3 cloud storage for free on https://aws.amazon.com/. See also http://wiki.zmanda.com/index.php/How_To:Backup_to_Amazon_S3" 15 80) then
        config=openhab-AWS
        S3accesskey=$(whiptail --title "S3 access key" --inputbox "Enter the S3 access key you obtained at S3 setup time:" 10 60 3>&1 1>&2 2>&3)
        S3secretkey=$(whiptail --title "S3 secret key" --inputbox "Enter the S3 secret key you obtained at S3 setup time:" 10 60 3>&1 1>&2 2>&3)
	tapes=15
	capacity=$(whiptail --title "Storage capacity" --inputbox "How much storage do you want to dedicate to your backup in megabytes ? Recommendation: 2-3 times the amount of data to be backed up." 10 60 3>&1 1>&2 2>&3)
	let size=${capacity}/${tapes}

        create_backup_config ${config} ${backupuser} ${tapes} ${size} AWS ${S3accesskey} ${S3secretkey}
    fi
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
  echo -n "$(timestamp) [openHABian] Updating myself... "
  read -t 1 -n 1 key
  if [ "$key" != "" ]; then
    echo -e "\nRemote git branches available:"
    git -C $SCRIPTDIR branch -r
    read -e -p "Please enter the branch to checkout: " branch
    branch="${branch#origin/}"
    if ! git -C $SCRIPTDIR branch -r | grep -q "origin/$branch"; then
      echo "FAILED - The custom branch does not exist."
      return 1
    fi
  else
    branch="master"
  fi
  shorthash_before=$(git -C $SCRIPTDIR log --pretty=format:'%h' -n 1)
  git -C $SCRIPTDIR fetch --quiet origin || FAILED=1
  git -C $SCRIPTDIR reset --quiet --hard "origin/$branch" || FAILED=1
  git -C $SCRIPTDIR clean --quiet --force -x -d || FAILED=1
  git -C $SCRIPTDIR checkout --quiet "$branch" || FAILED=1
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
    git -C $SCRIPTDIR --no-pager log --pretty=format:'%Cred%h%Creset - %s %Cgreen(%ar) %C(bold blue)<%an>%Creset %C(dim yellow)%G?' --reverse --abbrev-commit --stat $shorthash_before..$shorthash_after
    echo -e "\n"
    echo "openHABian configuration tool successfully updated."
    echo "Visit the development repository for more details: $REPOSITORYURL"
    echo "You need to restart the tool. Exiting now... "
    exit 0
  fi
  git -C $SCRIPTDIR config user.email 'openhabian@openHABian'
  git -C $SCRIPTDIR config user.name 'openhabian'
}

system_check_default_password() {
  introtext="The default password was detected on your system! That's a serious security concern. Others or malicious programs in your subnet are able to gain root access!
  \nPlease set a strong password by typing the command 'passwd'!"

  echo -n "$(timestamp) [openHABian] Checking for default openHABian username:password combination... "
  if is_pi && id -u pi &>/dev/null; then
    USERNAME="pi"
    PASSWORD="raspberry"
  elif is_pi || is_pine64; then
    USERNAME="openhabian"
    PASSWORD="openhabian"
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
      whiptail --title "Default Password Detected!" --msgbox "$introtext" 12 70
    fi
    echo "FAILED"
  else
    echo "OK"
  fi
}

change_password() {
  introtext="Choose which services to change the password for:"
  failtext="Something went wrong in the password change process. Please report this problem in the openHAB community forum or as a openHABian GitHub issue."

  matched=false
  canceled=false
  FAILED=0

  if [ -n "$INTERACTIVE" ]; then
    accounts=$(whiptail --title "Choose accounts" --yes-button "Continue" --no-button "Back" --checklist "$introtext" 20 90 10 \
          "Linux account" "The account to login to this computer" off \
          "openHAB Console" "The Karaf console which is used to manage openHAB" off \
          "Samba" "The fileshare for configuration files" off \
          3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      while [ "$matched" = false ] && [ "$canceled" = false ]; do
        passwordChange=$(whiptail --title "Authentication Setup" --passwordbox "Enter a new password:" 15 80 3>&1 1>&2 2>&3)
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
    accounts=("Linux account" "openHAB Console" "Samba")
  fi

  for i in "${accounts[@]}"
  do
    if [[ $i == *"Linux account"* ]]; then
      echo -n "$(timestamp) [openHABian] Changing password for linux account \"$username\"... "
      echo "$username:$passwordChange" | chpasswd
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
    if [[ $i == *"Samba"* ]]; then
      echo -n "$(timestamp) [openHABian] Changing password for samba (fileshare) account \"$username\"... "
      (echo "$passwordChange"; echo "$passwordChange") | /usr/bin/smbpasswd -s -a $username
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
    if [[ $i == *"openHAB Console"* ]]; then
      echo -n "$(timestamp) [openHABian] Changing password for openHAB console account \"openhab\"... "
      sed -i "s/openhab = .*,/openhab = $passwordChange,/g" /var/lib/openhab2/etc/users.properties
      cond_redirect systemctl restart openhab2.service
      if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
    fi
  done

  if [ -n "$INTERACTIVE" ]; then
    if [ $FAILED -eq 0 ]; then
      whiptail --title "Operation Successful!" --msgbox "Password successfully set for: $accounts" 15 80
    else
      whiptail --title "Operation Failed!" --msgbox "$failtext" 10 60
    fi
  fi
}

system_upgrade() {
  echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
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
  - Install recommended packages (vim, git, htop, ...)
  - Install an improved bash configuration
  - Install an improved vim configuration
  - Set up FireMotD
  - Set up the /srv/openhab2-... link structure
  - Make some permission changes ('adduser', 'chown', ...)"

  if [ -n "$INTERACTIVE" ]; then
    if ! (whiptail --title "Description, Continue?" --yes-button "Continue" --no-button "Back" --yesno "$introtext" 20 80) then return 0; fi
  fi

  basic_packages
  needed_packages
  bashrc_copy
  vimrc_copy
  vim_openhab_syntax
  nano_openhab_syntax
  firemotd
  srv_bind_mounts
  permissions_corrections
  misc_system_settings
  if is_pine64; then pine64_platform_scripts; fi
}

show_main_menu() {
  choice=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" 21 116 14 --cancel-button Exit --ok-button Execute \
  "00 | About openHABian"       "Information about the openHABian project and this tool" \
  "" "" \
  "01 | Update"                 "Pull the latest revision of the openHABian Configuration Tool" \
  "02 | Upgrade System"         "Upgrade all installed software packages to their newest version" \
  "" "" \
  "10 | Apply Improvements"     "Apply the latest improvements to the basic openHABian setup ►" \
  "20 | Optional Components"    "Choose from a set of optional software components ►" \
  "30 | System Settings"        "A range of system and hardware related configuration steps ►" \
  "40 | openHAB related"        "Switch the installed openHAB version or apply tweaks ►" \
  "50 | Backup/Restore"         "Manage backups and restore your system ►" \
  "60 | Manual/Fresh Setup"     "Go through all openHABian setup steps manually ►" \
  "" "" \
  "99 | Help"                   "Further options and guidance with Linux and openHAB" \
  3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ] || [ $RET -eq 255 ]; then
    # "Exit" button selected or <Esc> key pressed two times
    return 255
  fi

  if [[ "$choice" == "" ]]; then
    true
  
  elif [[ "$choice" == "00"* ]]; then
    show_about
  
  elif [[ "$choice" == "01"* ]]; then
    openhabian_update
  
  elif [[ "$choice" == "02"* ]]; then
    system_upgrade
  
  elif [[ "$choice" == "10"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" 12 116 5 --cancel-button Back --ok-button Execute \
    "11 | Packages"               "Install needed and recommended system packages" \
    "12 | Bash&Vim Settings"      "Update customized openHABian settings for bash, vim and nano" \
    "13 | System Tweaks"          "Add /srv mounts and update settings typical for openHAB" \
    "14 | Fix Permissions"        "Update file permissions of commonly used files and folders" \
    "15 | FireMotD"               "Upgrade the program behind the system overview on SSH login" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    case "$choice2" in
      11\ *) basic_packages && needed_packages ;;
      12\ *) bashrc_copy && vimrc_copy && vim_openhab_syntax && nano_openhab_syntax ;;
      13\ *) srv_bind_mounts && misc_system_settings ;;
      14\ *) permissions_corrections ;;
      15\ *) firemotd ;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "20"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" 14 116 7 --cancel-button Back --ok-button Execute \
    "21 | Log Viewer"          "The openHAB Log Viewer webapp (frontail)" \
    "22 | openHAB Generator"   "The openHAB items, sitemap and HABPanel dashboard generator" \
    "23 | Mosquitto"           "The MQTT broker Eclipse Mosquitto" \
    "24 | Grafana"             "InfluxDB+Grafana as a powerful persistence and graphing solution" \
    "25 | NodeRED"             "Flow-based programming for the Internet of Things" \
    "26 | Homegear"            "Homematic specific, the CCU2 emulation software Homegear" \
    "27 | knxd"                "KNX specific, the KNX router/gateway daemon knxd" \
    "28 | 1wire"               "1wire specific, owserver and related packages" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    case "$choice2" in
      21\ *) frontail ;;
      22\ *) yo_generator ;;
      23\ *) mqtt_setup ;;
      24\ *) influxdb_grafana_setup ;;
      25\ *) nodered ;;
      26\ *) homegear_setup ;;
      27\ *) knxd_setup ;;
      28\ *) 1wire_setup ;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "30"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" 14 116 7 --cancel-button Back --ok-button Execute \
    "31 | Change Hostname"        "Change the name of this system, currently '$(hostname)'" \
    "32 | Set System Locale"      "Change system language, currently '$(env | grep "LANG=" | sed 's/LANG=//')'" \
    "33 | Set System Timezone"    "Change the your timezone, execute if it's not '$(date +%H:%M)' now" \
    "34 | Change Passwords"       "Change passwords for Samba, openHAB Console or the system user" \
    "35 | Serial Port"            "Prepare serial ports for peripherals like Razberry, SCC, Pine64 ZWave, ..." \
    "36 | Wifi Setup"             "Configure the build-in Raspberry Pi 3 / Pine A64 wifi" \
    "37 | Move root to USB"       "Move the system root from the SD card to a USB device (SSD or stick)" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    case "$choice2" in
      31\ *) hostname_change ;;
      32\ *) locale_setting ;;
      33\ *) timezone_setting ;;
      34\ *) change_password ;;
      35\ *) prepare_serial_port ;;
      36\ *) wifi_setup ;;
      37\ *) move_root2usb ;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "40"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" 11 116 4 --cancel-button Back --ok-button Execute \
    "41 | openHAB 2.1 stable"     "Switch to the openHAB 2.1 release" \
    "   | openHAB 2.2 unstable"   "Switch to the latest openHAB 2.2 snapshot" \
    "42 | Karaf SSH Console"      "Bind the Karaf SSH console to all external interfaces" \
    "43 | Reverse Proxy"          "Setup Nginx with password authentication and/or HTTPS access" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    case "$choice2" in
      41\ *) openhab2_stable ;;
      *openHAB\ 2.2\ unstable) openhab2_unstable ;;
      42\ *) openhab_shell_interfaces ;;
      43\ *) nginx_setup ;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "50"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" 10 116 3 --cancel-button Back --ok-button Execute \
    "51 | Amada Backup"           "Set up a backup solution on top of Amanda" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    case "$choice2" in
      51\ *) amanda_setup ;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "60"* ]]; then
    choice2=$(whiptail --title "Welcome to the openHABian Configuration Tool $(get_git_revision)" --menu "Setup Options" 17 116 10 --cancel-button Back --ok-button Execute \
    "61 | Upgrade System"         "Upgrade all installed software packages to their newest version" \
    "62 | Packages"               "Install needed and recommended system packages" \
    "63 | Zulu OpenJDK"           "Install Zulu Embedded OpenJDK Java 8" \
    "   | Oracle Java 8"          "(Alternative) Install Oracle Java 8 provided by WebUpd8Team" \
    "64 | openHAB 2"              "Install openHAB 2.1 (stable)" \
    "   | openHAB 2 unstable"     "(Alternative) Install the latest openHAB 2.2 snapshot (unstable)" \
    "65 | System Tweaks"          "Configure system permissions and settings typical for openHAB" \
    "66 | Samba"                  "Install the Samba file sharing service and set up openHAB 2 shares" \
    "67 | Log Viewer"             "The openHAB Log Viewer webapp (frontail)" \
    "68 | FireMotD"               "Configure FireMotD to present a system overview on SSH login (optional)" \
    "69 | Bash&Vim Settings"      "Apply openHABian settings for bash, vim and nano (optional)" \
    3>&1 1>&2 2>&3)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then return 0; fi
    case "$choice2" in
      61\ *) system_upgrade ;;
      62\ *) basic_packages && needed_packages ;;
      63\ *) java_zulu_embedded ;;
      *Oracle\ Java*) java_webupd8 ;;
      64\ *) openhab2 ;;
      *openHAB\ 2\ unstable) openhab2_unstable ;;
      65\ *) srv_bind_mounts && permissions_corrections && misc_system_settings ;;
      66\ *) samba_setup ;;
      67\ *) frontail ;;
      68\ *) firemotd ;;
      69\ *) bashrc_copy && vimrc_copy && vim_openhab_syntax && nano_openhab_syntax ;;
      "") return 0 ;;
      *) whiptail --msgbox "A not supported option was selected (probably a programming error):\n  \"$choice2\"" 8 80 ;;
    esac

  elif [[ "$choice" == "99"* ]]; then
    show_about

  else whiptail --msgbox "Error: unrecognized option \"$choice\"" 10 60
  fi

  if [ $? -ne 0 ]; then whiptail --msgbox "There was an error or interruption during the execution of:\n  \"$choice\"\n\nPlease try again. Open a Ticket if the error persists: $REPOSITORYURL/issues" 12 60; return 0; fi
}

if [[ -n "$UNATTENDED" ]]; then
  #unattended installation (from within openHABian images)
  load_create_config
  timezone_setting
  locale_setting
  hostname_change
  if is_pi; then memory_split; fi
  if is_pine64; then pine64_platform_scripts; fi
  if is_pine64; then pine64_fixed_mac; fi
  basic_packages
  needed_packages
  bashrc_copy
  vimrc_copy
  firemotd
  etckeeper
  java_zulu_embedded
  openhab2
  vim_openhab_syntax
  nano_openhab_syntax
  srv_bind_mounts
  permissions_corrections
  misc_system_settings
  samba_setup
  clean_config_userpw
  if is_pione || is_pizero || is_pizerow; then true; else nodejs && frontail && yo_generator; fi
else
  whiptail_check
  load_create_config
  openhabian_hotfix
  ua-netinst_check
  while show_main_menu; do
    true
  done
  system_check_default_password
  echo -e "$(timestamp) [openHABian] We hope you got what you came for! See you again soon ;)"
fi

# vim: filetype=sh
