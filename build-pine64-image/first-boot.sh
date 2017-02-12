#!/bin/bash

# Log everything to file
exec &> >(tee -a "$LOG")

timestamp() { date +"%F_%T_%Z"; }

echo "$(timestamp) [openHABian] Booting for the first time!"
rm -f /opt/openHABian-install-failed
touch /opt/openHABian-install-inprogress

echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
apt update &>/dev/null
apt --yes upgrade &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

echo -n "$(timestamp) [openHABian] Installing git package... "
/usr/bin/apt-get -y install git &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

echo -n "$(timestamp) [openHABian] Cloning myself... "
/usr/bin/git clone -b pine64-build https://github.com/openhab/openhabian.git /opt/openhabian &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
ln -sfn /opt/openhabian/openhabian-setup.sh /usr/local/bin/openhabian-config

echo -n "$(timestamp) [openHABian] Copying configuration and first boot script... "
cp /opt/openhabian/build-pine64-image/openhabian.pine64.conf /etc/openhabian.conf
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

echo "$(timestamp) [openHABian] === Executing 'openhabian-setup.sh' ==="
(/bin/bash /opt/openhabian/openhabian-setup.sh unattended)
if [ $? -eq 0 ]; then
  rm -f /opt/openHABian-install-inprogress
  touch /opt/openHABian-install-successful
else
  touch /opt/openHABian-install-failed
fi
echo "$(timestamp) [openHABian] === Finished executing 'openhabian-setup.sh' ==="

echo -n "$(timestamp) [openHABian] Finishing up and rebooting... "
echo "[openHABian] This file was created after the first boot script was executed (see /etc/rc.local). Do not delete." >> $FLAG

# vim: filetype=sh
