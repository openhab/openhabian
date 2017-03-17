#!/bin/bash

# Log everything to file
exec &> >(tee -a "/boot/first-boot.log")

timestamp() { date +"%F_%T_%Z"; }

echo "$(timestamp) [openHABian] Booting for the first time!"
rm -f /opt/openHABian-install-failed
touch /opt/openHABian-install-inprogress

echo "$(timestamp) [openHABian] Storing configuration... "
cp /boot/openhabian.conf /etc/openhabian.conf
source /etc/openhabian.conf

# While setup: show log to logged in user, will be overwritten by openhabian-setup.sh
echo "watch -n 1 cat /boot/first-boot.log" > "/home/$username/.bash_profile"

echo -n "$(timestamp) [openHABian] Setting up Wifi connection... "
if [ -z ${wifi_ssid+x} ]; then
  echo "SKIPPED"
else
  echo ""
  echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1" > /etc/wpa_supplicant/wpa_supplicant.conf
  echo -e "network={\n\tssid=\"$wifi_ssid\"\n\tpsk=\"$wifi_psk\"\n}" >> /etc/wpa_supplicant/wpa_supplicant.conf
  wpa_cli reconfigure &>/dev/null
fi

echo "$(timestamp) [openHABian] Ensuring network connectivity... "
cnt=0
until ping -c1 8.8.8.8 &>/dev/null; do
  sleep 1
  cnt=$((cnt + 1))
  if [ $cnt -eq 100 ]; then
    echo "$(timestamp) [openHABian] Network unreachable, can't continue. Please reboot and let me try again."
    exit 0
  fi
done

echo -n "$(timestamp) [openHABian] Waiting for dpkg/apt to get ready... "
until apt update &>/dev/null; do sleep 1; done
echo "OK"

echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
apt update &>/dev/null
apt --yes upgrade &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

echo -n "$(timestamp) [openHABian] Installing git package... "
/usr/bin/apt -y install git &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

echo -n "$(timestamp) [openHABian] Cloning myself... "
/usr/bin/git clone -b master https://github.com/openhab/openhabian.git /opt/openhabian &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi
ln -sfn /opt/openhabian/openhabian-setup.sh /usr/local/bin/openhabian-config

#echo -n "$(timestamp) [openHABian] Copying configuration and first boot script... "
#cp /opt/openhabian/build-pine64-image/openhabian.pine64.conf /etc/openhabian.conf
#if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; exit 1; fi

echo "$(timestamp) [openHABian] === Executing 'openhabian-setup.sh' ==="
if (/bin/bash /opt/openhabian/openhabian-setup.sh unattended); then
  systemctl start openhab2.service
  rm -f /opt/openHABian-install-inprogress
  touch /opt/openHABian-install-successful
else
  touch /opt/openHABian-install-failed
fi
echo "$(timestamp) [openHABian] === Finished executing 'openhabian-setup.sh' ==="

# vim: filetype=sh
