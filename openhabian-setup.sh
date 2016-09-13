#!/usr/bin/env bash

# openHABian - hassle-free openHAB 2 installation and configuration tool
# for the Raspberry Pi and other Linux systems
#
# https://community.openhab.org/t/openhabian-hassle-free-rpi-image/13379
# https://github.com/ThomDietrich/openhabian
#
# 2016 Thomas Dietrich
#

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors
ESC="\033["
COL_DEF=$ESC"39;49;00m"
COL_RED=$ESC"31;01m"
COL_GREEN=$ESC"32;01m"
COL_YELLOW=$ESC"33;01m"
COL_BLUE=$ESC"34;01m"
COL_MAGENTA=$ESC"35;01m"
COL_CYAN=$ESC"36;01m"
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

# script will be called with unattended argument by post-install.txt
# execution without "unattended" may later provide an interactive version with more optional components
if [[ "$1" = "unattended" ]]
then
  UNATTENDED=1
  SILENT=1
fi

cond_redirect() {
  if [ -n "$SILENT" ]; then
    "$@" &>/dev/null
    return $?
  else
    echo -e "\n$COL_BLUE\$ $@ $COL_DEF"
    "$@"
    return $?
  fi
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
is_pizero() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]09[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}
get_pi_type() {
  if is_pione; then
    echo 1
  elif is_pitwo; then
    echo 2
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
  WT_HEIGHT=17
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
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

needed_packages() {
  # install raspi-config - configuration tool for the Raspberry Pi + Raspbian
  # install apt-transport-https - update packages through https repository (https://openhab.ci.cloudbees.com/...)
  # install samba - network sharing
  # install bc + sysstat - needed for FireMotD
  echo -n "[openHABian] Installing additional needed packages... "
  cond_redirect apt -y install raspi-config oracle-java8-jdk apt-transport-https samba bc sysstat
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
#     rm $cert
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
  echo "deb https://openhab.ci.cloudbees.com/job/openHAB-Distribution/ws/distributions/openhab-offline/target/apt-repo/ /" >> /etc/apt/sources.list.d/openhab2.list
  echo "deb https://openhab.ci.cloudbees.com/job/openHAB-Distribution/ws/distributions/openhab-online/target/apt-repo/ /" >> /etc/apt/sources.list.d/openhab2.list
  cond_redirect apt update
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

openhab2_install() {
  echo -n "[openHABian] Installing openhab2-offline (force ignore auth)... "
  cond_redirect apt --yes --force-yes install openhab2-offline
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
    #echo -e "\necho\n/opt/FireMotD/FireMotD --theme gray \necho" >> /home/pi/.bashrc
    echo "3 3 * * * root /opt/FireMotD/FireMotD -S &>/dev/null" >> /etc/cron.d/firemotd
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
  #cond_redirect rm /usr/share/openhab2/runtime/karaf/etc/host.key
  cond_redirect systemctl restart openhab2.service
  echo "OK"
}

knxd_setup() {
  echo -n "[openHABian] Setting up EIB/KNX IP Gateway and Router with knxd "
  echo -n "(http://michlstechblog.info/blog/raspberry-pi-eibknx-ip-gateway-and-router-with-knxd)... "
  #TODO serve file from the repository
  cond_redirect wget -O /tmp/install_knxd_systemd.sh http://michlstechblog.info/blog/download/electronic/install_knxd_systemd.sh
  cond_redirect bash /tmp/install_knxd_systemd.sh
  if [ $? -eq 0 ]; then echo "OK. Please restart your system now..."; else echo "FAILED"; fi
  #systemctl start knxd.service
  #if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
}

1wire_setup() {
  echo -n "[openHABian] Installing owserver (1wire)... "
  cond_redirect apt -y install owserver ow-shell usbutils
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
}

openhabian_update() {
  echo -n "[openHABian] Updating myself... "
  cond_redirect git -C $SCRIPTDIR fetch origin
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
  cond_redirect git -C $SCRIPTDIR reset --hard origin/master
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
  whiptail --title "openHABian $(get_git_revision)" --msgbox "The hassle-free openHAB 2 installation and configuration tool.\nhttps://github.com/ThomDietrich/openhabian \nhttps://community.openhab.org/t/openhabian-hassle-free-rpi-image/13379" 20 60 1
}

fresh_raspbian_mods() {
  first_boot_script
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
  "1 Update"                 "Pull the the newest version of the openHABian Configuration Tool from GitHub" \
  "2 Basic Setup"            "Perform all basic setup steps recommended for openHAB 2 on a new system" \
  "3 Java 8"                 "Install the newest Revision of Java 8 provided by WebUpd8Team (needed by openHAB 2)" \
  "4 openHAB 2"              "Prepare and install the latest openHAB 2 snapshot" \
  "5 Samba"                  "Install the filesharing service Samba and set up openHAB 2 shares" \
  "6 Karaf Console"          "Bind the Karaf console to all interfaces" \
  "7 Optional: KNX"          "Prepare and install kndx, the KNX daemon" \
  "8 Optional: 1wire"        "Prepare and install owserver and related packages for working with 1wire" \
  "9 Optional: homegear"     "(not yet implemented)"
  "9 Optional: grafana"      "(not yet implemented)"
  "9 Optional: mosquitto"    "(not yet implemented)"
  "0 About openHABian"       "Information about the openHABian project" \
  3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    echo "We hope you got what you came for! See you again soon ;)"
    exit 0
  elif [ $RET -eq 0 ]; then
    case "$choice" in
      1\ *) openhabian_update ;;
      2\ *) fresh_raspbian_mods ;;
      3\ *) java_webupd8_prepare && java_webupd8_install ;;
      4\ *) openhab2_full_setup ;;
      5\ *) samba_setup ;;
      6\ *) openhab_shell_interfaces ;;
      7\ *) knxd_setup ;;
      8\ *) 1wire_setup ;;
      0\ *) show_about ;;
      *) whiptail --msgbox "Error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option \"$choice\"" 20 60 1
  else
    echo "Bye Bye! :)"
    exit 1
  fi
}

if [[ -n "$UNATTENDED" ]]
then
  #unattended installation (from within raspbian-ua-netinst chroot)
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
