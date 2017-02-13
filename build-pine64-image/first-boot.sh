#!/bin/bash

# Log everything to file
exec &> >(tee -a "/var/log/first-boot.log")

timestamp() { date +"%F_%T_%Z"; }

echo "$(timestamp) [openHABian] Booting for the first time!"
rm -f /opt/openHABian-install-failed
touch /opt/openHABian-install-inprogress

echo "$(timestamp) [openHABian] Ensuring network connectivity... "
sleep 60
if ! ping -c 1 8.8.8.8 > /dev/null; then
  echo "$(timestamp) [openHABian] Network unreachable, can't continue. Please reboot and let me try again."
  exit 0
fi

echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
apt update &>/dev/null
apt --yes upgrade &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fi # exit 1; fi

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

# vim: filetype=sh
