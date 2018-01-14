#!/bin/bash

timestamp() { date +"%F_%T_%Z"; }

fail_inprogress() {
  echo -e "$(timestamp) [HOST] [openHABian] Initial setup exiting with an error!\\n\\n"
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
if [ ! -f /opt/YAHM/bin/yahm-ctl ]
then
    echo "$(timestamp) [openHABian] ERROR: Please install YAHM first: https://github.com/leonsio/YAHM"
    exit
fi
if [ -d /var/lib/lxc/openhab ]
then
    echo "$(timestamp) [openHABian] ERROR: Openhab LXC Instance found, please delete it first /var/lib/lxc/openhab"
    exit
fi

mkdir -p /var/log/yahm
rm -rf /var/log/yahm/openhabian_install.log

echo "\n$(timestamp) [GLOBAL] [openHABian] Starting the openHABian Host LXC installation.\n"

echo -n "$(timestamp) [HOST] [openHABian] Updating repositories and upgrading installed packages..."
until apt update &>> /var/log/yahm/openhabian_install.log; do sleep 1; done
apt --yes upgrade &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [HOST] [openHABian] Installing dependencies..."
/usr/bin/apt -y install debootstrap &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [HOST] [openHABian] Creating new LXC debian container: openhab..."
lxc-create -n openhab -t debian &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [HOST] [openHABian] Creating LXC network configuration..."
yahm-network -n openhab -f attach_bridge &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi
echo lxc.include=/var/lib/lxc/openhab/config.network >> /var/lib/lxc/openhab/config

echo -n "$(timestamp) [HOST] [openHABian] Starting openhab LXC container..."
lxc-start -n openhab -d 
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo "\n$(timestamp) [GLOBAL] [openHABian] Host Installation done, beginning with LXC preparation.\n"

echo -n "$(timestamp) [LXC] [openHABian] Installing dependencies..."
lxc-attach -n openhab -- apt install -y wget gnupg git lsb-release &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

if is_pithree || is_pizerow; then
    echo "$(timestamp) [INFO] [openHABian] Raspberry Pi Hardware found, setup addition repositories."

    echo -n "$(timestamp) [LXC] [openHABian] Installing repository key..."
    wget -qO - http://archive.raspberrypi.org/debian/raspberrypi.gpg.key  | lxc-attach -n openhab -- apt-key add - &>> /var/log/yahm/openhabian_install.log
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

    echo -n "$(timestamp) [LXC] [openHABian] Installing repository files..."
    echo 'deb http://archive.raspberrypi.org/debian/ stretch main ui' | lxc-attach -n openhab  -- tee /etc/apt/sources.list.d/rpi.list &>> /var/log/yahm/openhabian_install.log
    if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi
fi

echo -n "$(timestamp) [LXC] [openHABian] Creating gpio user..."
lxc-attach -n openhab -- useradd gpio &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Creating openhabian user..."
lxc-attach -n openhab -- useradd -m openhabian &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Setting default password for openhabian user..."
echo openhabian:openhabian | lxc-attach -n openhab -- chpasswd &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Cloning openhabian repository..."
lxc-attach -n openhab -- git clone -b master https://github.com/openhab/openhabian.git /opt/openhabian &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Linking openhabian configuration utility to /usr/bin..."
lxc-attach -n openhab -- ln -sfn /opt/openhabian/openhabian-setup.sh /usr/bin/openhabian-config &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [LXC] [openHABian] Creating openhabian default configuration..."
echo -e "hostname=openHABian\nusername=openhabian\nuserpw=openhabian\ntimeserver=0.pool.ntp.org\nlocales='en_US.UTF-8 de_DE.UTF-8'\nsystem_default_locale=en_US.UTF-8\ntimezone=Europe/Berlin" > /var/lib/lxc/openhab/rootfs/etc/openhabian.conf &>> /var/log/yahm/openhabian_install.log
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo  "$(timestamp) [LXC] [openHABian] Starting openhabian installation, this can take a lot of time....."
lxc-attach -n openhab -- /opt/openhabian/openhabian-setup.sh unattended 

echo  "$(timestamp) [LXC] [openHABian] Starting openHAB2 Service."
lxc-attach -n openhab -- systemctl start openhab2.service

echo  "\n$(timestamp) [GLOBAL] [openHABian] Done.\n"
lxc-info -n openhab

