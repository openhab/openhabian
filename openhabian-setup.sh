#!/usr/bin/env bash

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
else
  echo "We are sorry, interactive mode not implemented yet."
  exit 1
fi

#if [[ -n "$UNATTENDED" ]]
#then
#    #dosomething
#else
#    #dosomethingelse
#fi

# make green LED blink as heartbeat on finished first boot
echo -n "[openHABian] Activating first boot script... "
cp /opt/openhabian/includes/rc.local /etc/rc.local
echo "OK"

# memory split down to 16MB for graphics card
echo -n "[openHABian] Setting the GPU memory split down to 16MB for headless system... "
if grep -q "gpu_mem" /boot/config.txt; then
  sed -i 's/gpu_mem=.*/gpu_mem=16/g' /boot/config.txt
else
  echo "gpu_mem=16" >> /boot/config.txt
fi
echo "OK"

# install basic packages
echo -n "[openHABian] Installing basic can't-be-wrong packages (screen, vim, ...)... "
apt -y install screen vim nano mc vfu bash-completion htop curl wget multitail git bzip2 zip unzip xz-utils software-properties-common &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# add a slightly better bashrc
echo -n "[openHABian] Adding .bashrc to users profile... "
cp /opt/openhabian/includes/.bashrc /home/pi/.bashrc
chown pi:pi /home/pi/.bashrc
echo "OK"

# add a slightly better vimrc
echo -n "[openHABian] Adding .vimrc to users profile... "
cp /opt/openhabian/includes/.vimrc /home/pi/.vimrc
chown pi:pi /home/pi/.vimrc
echo "OK"

# add vim syntax highlighting, these may go to "/usr/share/vim/vimfiles"
echo -n "[openHABian] Adding openHAB syntax to vim editor... "
mkdir -p /home/pi/.vim/{ftdetect,syntax}
wget -O /home/pi/.vim/syntax/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/syntax/openhab.vim &>/dev/null
wget -O /home/pi/.vim/ftdetect/openhab.vim https://raw.githubusercontent.com/cyberkov/openhab-vim/master/ftdetect/openhab.vim &>/dev/null
chown -R pi:pi /home/pi/.vim
echo "OK"

# add nano syntax highlighting
echo -n "[openHABian] Adding openHAB syntax to nano editor... "
wget -O /usr/share/nano/openhab.nanorc https://raw.githubusercontent.com/airix1/openhabnano/master/openhab.nanorc &>/dev/null
echo -e "\n## openHAB files\ninclude \"/usr/share/nano/openhab.nanorc\"" >> /etc/nanorc
echo "OK"

# install raspi-config - configuration tool for the Raspberry Pi + Raspbian
# install apt-transport-https - update packages through https repository (https://openhab.ci.cloudbees.com/...)
# install samba - network sharing
# install bc + sysstat - needed for FireMotD
echo -n "[openHABian] Installing additional needed packages... "
apt -y install raspi-config oracle-java8-jdk apt-transport-https samba bc sysstat &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# prepare (not install) Oracle Java 8 newest revision
echo -n "[openHABian] Preparing Oracle Java 8 Web Upd8 repository... "
cat <<EOT >> /etc/apt/sources.list.d/webupd8team-java.list
deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main
deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main
EOT
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886 &>/dev/null
if [ $? -ne 0 ]; then echo "FAILED (keyserver)"; exit 1; fi
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
if [ $? -ne 0 ]; then echo "FAILED (debconf)"; exit 1; fi
apt update &>/dev/null
#apt -y install oracle-java8-installer &>/dev/null #FAILS with "readelf: Error: '/proc/self/exe': No such file"
#if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
#apt -y install oracle-java8-set-default &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# add let's encrypt to java keytool
# alternative to installing newest java revision through webupd8team repository, which is not working in chroot
#echo -n "[openHABian] Adding letsencrypt certs to Oracle Java 8 keytool (needed for my.openhab)... "
#FAILED=0
#CERTS="isrgrootx1.der
#lets-encrypt-x1-cross-signed.der
#lets-encrypt-x2-cross-signed.der
#lets-encrypt-x3-cross-signed.der
#lets-encrypt-x4-cross-signed.der
#letsencryptauthorityx1.der
#letsencryptauthorityx2.der"
#for cert in $CERTS
#do
#  namewoext="${cert%%.*}"
#  wget "https://letsencrypt.org/certs/$cert" || ((FAILED++))
#  /usr/bin/keytool -importcert -keystore /usr/lib/jvm/jdk-8-oracle-arm32-vfp-hflt/jre/lib/security/cacerts \
#    -storepass changeit -noprompt -trustcacerts -alias $namewoext -file $cert || ((FAILED++))
#  rm $cert
#done
#if [ $FAILED -eq 0 ]; then echo "OK"; else echo "FAILED"; fi

## add openhab system user
#echo -n "[openHABian] Manually adding openhab user to system (for manual installation?)... "
#adduser --system --no-create-home --group --disabled-login openhab &>/dev/null
#echo "OK"

# add openHAB 2 repository
echo -n "[openHABian] Adding openHAB 2 Snapshot repositories to sources.list.d... "
cat <<EOT >> /etc/apt/sources.list.d/openhab2.list
deb https://openhab.ci.cloudbees.com/job/openHAB-Distribution/ws/distributions/openhab-offline/target/apt-repo/ /
deb https://openhab.ci.cloudbees.com/job/openHAB-Distribution/ws/distributions/openhab-online/target/apt-repo/ /
EOT
apt update &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# openhab2-offline install
echo -n "[openHABian] Installing openhab2-offline (force ignore auth)... "
apt --yes --force-yes install openhab2-offline &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

# openhab service activate
echo -n "[openHABian] Activating openHAB... "
systemctl daemon-reload &> /dev/null
#if [ $? -eq 0 ]; then echo -n "OK "; else echo -n "FAILED "; fi
systemctl enable openhab2.service &> /dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi

# samba config
echo -n "[openHABian] Modifying Samba config... "
cp /opt/openhabian/includes/smb.conf /etc/samba/smb.conf
echo "OK"

# samba user
echo -n "[openHABian] Adding openhab as Samba user... "
( (echo "habopen"; echo "habopen") | /usr/bin/smbpasswd -s -a openhab > /dev/null )
#( (echo "raspberry"; echo "raspberry") | /usr/bin/smbpasswd -s -a pi > /dev/null )
chown -hR openhab:openhab /etc/openhab2
echo "OK"

# samba activate
echo -n "[openHABian] Activating Samba... "
/bin/systemctl enable smbd.service &>/dev/null
echo "OK"

# provide system statistics as message-of-the-day
echo -n "[openHABian] Downloading FireMotD... "
#git clone https://github.com/willemdh/FireMotD.git /opt/FireMotD &>/dev/null
git clone -b issue-15 https://github.com/ThomDietrich/FireMotD.git /opt/FireMotD &>/dev/null
if [ $? -eq 0 ]; then
  #echo -e "\necho\n/opt/FireMotD/FireMotD --theme gray \necho" >> /home/pi/.bashrc
  echo "3 3 * * * root /opt/FireMotD/FireMotD -S &>/dev/null" >> /etc/cron.d/firemotd
  echo "OK"
else
  echo "FAILED"
fi

# install etckeeper packages
echo -n "[openHABian] Installing etckeeper (git based /etc backup)... "
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
