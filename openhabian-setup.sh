#!/usr/bin/env bash

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

# install Oracle Java 8 - prerequisite for openHAB
# install apt-transport-https - update packages through https repository (https://openhab.ci.cloudbees.com/...)
# install samba - network sharing
# install bc + sysstat - needed for FireMotD
echo -n "[openhabian] Installing additional needed packages (oracle-java8-jdk, apt-transport-https, samba)... "
apt -y install oracle-java8-jdk apt-transport-https samba bc sysstat &>/dev/null
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
#    echo "OK"
#    echo -e "\n\n/opt/FireMotD/FireMotD --theme Modern" >> /home/pi/.bashrc
#else
#    echo "FAILED"
#    exit 1
#fi

# vim: filetype=sh
