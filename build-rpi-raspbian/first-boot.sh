#!/bin/bash

# Log everything to file
exec &> >(tee -a "/boot/first-boot.log")

timestamp() { date +"%F_%T_%Z"; }

fail_inprogress() {
  rm -f /opt/openHABian-install-inprogress
  touch /opt/openHABian-install-failed
  exit 1
}

echo "$(timestamp) [openHABian] Booting for the first time! The initial setup might take a few minutes."
rm -f /opt/openHABian-install-failed
touch /opt/openHABian-install-inprogress

echo "$(timestamp) [openHABian] Storing configuration... "
cp /boot/openhabian.conf /etc/openhabian.conf
source /etc/openhabian.conf

if id pi &>/dev/null; then
  echo "$(timestamp) [openHABian] Changing default username and password... "
  usermod -l $username pi
  usermod -m -d /home/$username $username
  groupmod -n $username pi
  chpasswd <<< "$username:$userpw"
fi

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
    fail_inprogress
  fi
done

echo "$(timestamp) [openHABian] Waiting for dpkg/apt to get ready... "
until apt update &>/dev/null; do sleep 1; done

echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
apt update &>/dev/null
apt --yes upgrade &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [openHABian] Installing git package... "
/usr/bin/apt -y install git &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [openHABian] Cloning myself... "
/usr/bin/git clone -b master https://github.com/openhab/openhabian.git /opt/openhabian &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi
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
  fail_inprogress
fi
echo "$(timestamp) [openHABian] === Finished executing 'openhabian-setup.sh' ==="
echo "$(timestamp) [openHABian] First time boot setup successfully finished."

# vim: filetype=sh
