#!/bin/bash

if [ `dpkg --print-architecture` = "arm64" ]
then
	ARCH_ADD="--arch arm64"
	ARCH="arm64"
else
	ARCH_ADD=""
	ARCH="armhf"	
fi

timestamp() { date +"%F_%T_%Z"; }

fail_inprogress() {
  echo -e "$(timestamp) [HOST] [openHABian] Initial setup exiting with an error!\n\n"
  cat /var/log/yahm/openhabian_install.log
  exit 1
}

is_pizerow() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[cC][0-9a-fA-F]$" /proc/cpuinfo
  return $?
} 

is_pithree() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]08[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}

# @todo need better checks: bridge installed? bridge name? this script works only with default values (yahmbr0)
if [ ! -f /etc/default/yahm ]
then
    echo "$(timestamp) [openHABian] ERROR: Please install YAHM version 1.9 or newer first: https://github.com/leonsio/YAHM"
    exit
else
    source /etc/default/yahm
fi

if [ $(lxc-info -n ${LXCNAME}|grep STOPPED|wc -l) -eq 1 ]
then
    echo "$(timestamp) [openHABian] ERROR: ${LXCNAME} container is stopped, please start it first (yahm-ctl start)"
    exit
fi

if [ -d /var/lib/lxc/openhabian ]
then
    echo "$(timestamp) [openHABian] ERROR: Openhab LXC Instance found, please delete it first /var/lib/lxc/openhabian"
    exit
fi

mkdir -p /var/log/yahm
rm -rf /var/log/yahm/openhabian_install.log

echo -e "\n$(timestamp) [GLOBAL] [openHABian] Starting the openHABian Host LXC installation.\n"

echo -n "$(timestamp) [HOST] [openHABian] Updating repositories and upgrading installed packages..."
until apt update &>> /var/log/yahm/openhabian_install.log; do sleep 1; done
apt --yes upgrade &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [HOST] [openHABian] Installing dependencies..."
/usr/bin/apt -y install debootstrap rsync &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [HOST] [openHABian] Creating new LXC debian container: openhabian..."
lxc-create -n openhabian -t debian -- ${ARCH_ADD} --packages="wget gnupg git lsb-release ca-certificates iputils-ping" &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [HOST] [openHABian] Creating LXC network configuration..."
yahm-network -n openhabian -f attach_bridge &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi
# attach network configuration
echo lxc.include=/var/lib/lxc/openhabian/config.network >> /var/lib/lxc/openhabian/config
# setup autostart
echo 'lxc.start.auto = 1' >> /var/lib/lxc/openhabian/config

echo -n "$(timestamp) [HOST] [openHABian] Starting openhabian LXC container..."
lxc-start -n openhabian -d 
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -e "\n$(timestamp) [GLOBAL] [openHABian] Host Installation done, beginning with LXC preparation.\n"

if is_pithree || is_pizerow; then
    echo "$(timestamp) [INFO] [openHABian] Raspberry Pi Hardware found, setup addition repositories."

    echo -n "$(timestamp) [LXC] [openHABian] Installing repository key..."
    wget -qO - http://archive.raspberrypi.org/debian/raspberrypi.gpg.key  | lxc-attach -n openhabian -- apt-key add - &>> /var/log/yahm/openhabian_install.log
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

    echo -n "$(timestamp) [LXC] [openHABian] Installing repository files..."
    echo 'deb http://archive.raspberrypi.org/debian/ stretch main ui' | lxc-attach -n openhabian  -- tee /etc/apt/sources.list.d/rpi.list &>> /var/log/yahm/openhabian_install.log
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi
fi

echo -n "$(timestamp) [LXC] [openHABian] Creating gpio user..."
lxc-attach -n openhabian -- useradd gpio &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Creating openhabian user..."
lxc-attach -n openhabian -- useradd -m openhabian &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Setting default password for openhabian user..."
echo openhabian:openhabian | lxc-attach -n openhabian -- chpasswd &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

# wait to get ethernet connection up 
sleep 5

echo -n "$(timestamp) [LXC] [openHABian] Cloning openhabian repository..."
lxc-attach -n openhabian -- git clone -b master https://github.com/openhab/openhabian.git /opt/openhabian &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Linking openhabian configuration utility to /usr/bin..."
lxc-attach -n openhabian -- ln -sfn /opt/openhabian/openhabian-setup.sh /usr/bin/openhabian-config &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Creating openhabian default configuration..."
echo -e "hostname=openHABian\nusername=openhabian\nuserpw=openhabian\ntimeserver=0.pool.ntp.org\nlocales='en_US.UTF-8 de_DE.UTF-8'\nsystem_default_locale=en_US.UTF-8\ntimezone=Europe/Berlin" > /var/lib/lxc/openhabian/rootfs/etc/openhabian.conf &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi
	
if [ $ARCH = "arm64" ]
then
	lxc-attach -n openhabian -- dpkg --add-architecture armhf
fi	

echo  "$(timestamp) [LXC] [openHABian] Starting openhabian installation, this can take a lot of time....."
lxc-attach -n openhabian -- /opt/openhabian/openhabian-setup.sh unattended 

if [ $? -eq 0 ]
then 
	echo  -e "\n$(timestamp) [GLOBAL] [openHABian] Installation Done.\n"
else 
	echo "FAILED"; fail_inprogress; 
fi


# Geting some IP informations
YAHM_LXC_IP=$(lxc-info -i -n ${LXCNAME} | awk '{print $2}')
OH_LXC_IP=$(lxc-info -i -n openhabian | awk '{print $2}')

echo "$(timestamp) [INFO] Homematic  IP: ${YAHM_LXC_IP}"
echo "$(timestamp) [INFO] OpenHABian IP: ${OH_LXC_IP}"
echo -e "\n"

echo  "$(timestamp) [LXC] [openHABian] Setup CCU2 Binding inside openHABian"
OH_CONF_DIR=/var/lib/lxc/openhabian/rootfs/etc/openhab2
sed -i $OH_CONF_DIR/services/addons.cfg -e 's/^#binding.*$/binding=homematic/'
echo "Bridge homematic:bridge:yahm [ gatewayAddress='${YAHM_LXC_IP}' ]" > $OH_CONF_DIR/things/yahm-homematic.things
lxc-attach -n openhabian  -- chown openhab:openhab /etc/openhab2/things/yahm-homematic.things

echo  "$(timestamp) [LXC] [openHABian] Starting openHAB2 Service."
lxc-attach -n openhabian -- systemctl start openhab2.service

echo -e "\n"

echo "$(timestamp) [INFO] OpenHABian Login URL: http://${OH_LXC_IP}:8080"
echo "$(timestamp) [INFO] OpenHABian Console Login: lxc-attach -n openhabian"