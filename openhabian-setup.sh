#!/usr/bin/env bash

# Make sure only root can run our script
echo -n "[openhabian] checking for root privileges... "
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
fi

#if [[ -n "$UNATTENDED" ]]
#then
#    #dosomething
#else
#    #dosomethingelse
#fi

# make green LED blink as heartbeat on finished first boot
echo -n "[openhabian] Activating heartbeat on first boot... "
cp /opt/openhabian/includes/rc.local /etc/rc.local
echo "OK"

# install basic packages
echo -n "[openhabian] Installing basic can't-be-wrong packages (screen, vim, ...)... "
apt -y install screen vim nano mc vfu bash-completion htop curl wget git bzip2 zip unzip xz-utils software-properties-common &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# add a slightly better bashrc
echo -n "[openhabian] Adding .bashrc to users profile... "
cp /opt/openhabian/includes/.bashrc /home/pi/.bashrc
chown pi:pi /home/pi/.bashrc
echo "OK"

# add a slightly better vimrc
echo -n "[openhabian] Adding .vimrc to users profile... "
cp /opt/openhabian/includes/.vimrc /home/pi/.vimrc
chown pi:pi /home/pi/.vimrc
echo "OK"

# install raspi-config - configuration tool for the Raspberry Pi + Raspbian
# install Oracle Java 8 - prerequisite for openHAB
# install apt-transport-https - update packages through https repository (https://openhab.ci.cloudbees.com/...)
# install samba - network sharing
# install bc + sysstat - needed for FireMotD
echo -n "[openhabian] Installing additional needed packages (raspi-config oracle-java8-jdk, apt-transport-https, samba)... "
apt -y install raspi-config oracle-java8-jdk apt-transport-https samba bc sysstat &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# add openHAB 2 repository
echo -n "[openhabian] Adding openHAB 2 Snapshot repositories to sources.list.d... "
cat <<EOT >> /etc/apt/sources.list.d/openhab2.list
deb https://openhab.ci.cloudbees.com/job/openHAB-Distribution/ws/distributions/openhab-offline/target/apt-repo/ /
deb https://openhab.ci.cloudbees.com/job/openHAB-Distribution/ws/distributions/openhab-online/target/apt-repo/ /
EOT
echo "OK"

# apt-get update after adding repository needed
echo -n "[openhabian] Updating package lists... "
apt update &>/dev/null
echo "OK"

## add openhab system user
#echo -n "[openhabian] Manually adding openhab user to system (for manual installation?)... "
#adduser --system --no-create-home --group --disabled-login openhab &>/dev/null
#echo "OK"

# openhab2-offline install
echo -n "[openhabian] Installing openhab2-offline (force ignore auth)... "
apt --yes --force-yes install openhab2-offline &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# openhab service activate
echo -n "[openhabian] Activating openHAB... "
systemctl daemon-reload &> /dev/null
if [ $? -eq 0 ]; then echo -n "OK "; else echo -n "FAILED "; fi
systemctl enable openhab2.service &> /dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi

# samba config
echo -n "[openhabian] Modifying Samba config... "
cp /opt/openhabian/includes/smb.conf /etc/samba/smb.conf
echo "OK"

# samba user
echo -n "[openhabian] Adding openhab as Samba user... "
( (echo "habopen"; echo "habopen") | /usr/bin/smbpasswd -s -a openhab > /dev/null )
chown -hR openhab:openhab /etc/openhab2
echo "OK"

# samba activate
echo -n "[openhabian] Activating Samba... "
/bin/systemctl enable smbd.service &>/dev/null
echo "OK"

## provide system statistics as message-of-the-day
#echo -n "[openhabian] Downloading FireMotD... "
#git clone https://github.com/willemdh/FireMotD.git /opt/FireMotD &>/dev/null
#if [ $? -eq 0 ]; then
#  echo "OK"
#  echo -e "\n\n/opt/FireMotD/FireMotD --theme Modern" >> /home/pi/.bashrc
#else
#  echo "FAILED"
#fi

# install etckeeper packages
echo -n "[openhabian] Installing etckeeper (git based /etc backup)... "
apt -y install etckeeper &>/dev/null
if [ $? -eq 0 ]; then
  sed -i 's/VCS="bzr"/\#VCS="bzr"/g' /etc/etckeeper/etckeeper.conf
  sed -i 's/\#VCS="git"/VCS="git"/g' /etc/etckeeper/etckeeper.conf
  /bin/bash -c "cd /etc && etckeeper init && git config user.email 'etckeeper@localhost' && git config user.name 'openhabian' && git commit -m 'initial checkin' && git gc" &>/dev/null
  if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi
else
  echo "FAILED";
fi

# vim: filetype=sh
