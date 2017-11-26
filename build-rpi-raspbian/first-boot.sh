#!/bin/bash

# Log everything to file
exec &> >(tee -a "/boot/first-boot.log")

timestamp() { date +"%F_%T_%Z"; }

fail_inprogress() {
  rm -f /opt/openHABian-install-inprogress
  touch /opt/openHABian-install-failed
  echo "$(timestamp) [openHABian] Initial setup exiting with an error."
  exit 1
}

echo "$(timestamp) [openHABian] Starting the openHABian initial setup. This might take a few minutes."
echo "$(timestamp) [openHABian] If you see this message more than once, something went wrong!"
rm -f /opt/openHABian-install-failed
touch /opt/openHABian-install-inprogress

echo -n "$(timestamp) [openHABian] Storing configuration... "
cp /boot/openhabian.conf /etc/openhabian.conf
source /etc/openhabian.conf
echo "OK"

userdef="pi"
echo -n "$(timestamp) [openHABian] Changing default username and password... "
if [ -z ${username+x} ] || ! id $userdef &>/dev/null || id $username &>/dev/null; then
  echo "SKIPPED"
else
  usermod -l $username $userdef
  usermod -m -d /home/$username $username
  groupmod -n $username $userdef
  chpasswd <<< "$username:$userpw"
  echo "OK"
fi

# While setup: show log to logged in user, will be overwritten by openhabian-setup.sh
echo "watch cat /boot/first-boot.log" > "/home/$username/.bash_profile"

echo -n "$(timestamp) [openHABian] Setting up Wifi connection... "
if [ -z ${wifi_ssid+x} ]; then
  echo "SKIPPED"
else
  echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1" > /etc/wpa_supplicant/wpa_supplicant.conf
  echo -e "network={\n\tssid=\"$wifi_ssid\"\n\tpsk=\"$wifi_psk\"\n}" >> /etc/wpa_supplicant/wpa_supplicant.conf
  wpa_cli reconfigure &>/dev/null
  echo "OK"
fi

echo -n "$(timestamp) [openHABian] Ensuring network connectivity... "
cnt=0
until ping -c1 8.8.8.8 &>/dev/null || [ "$(wget -qO- http://www.msftncsi.com/ncsi.txt)" == "Microsoft NCSI" ]; do
  cnt=$((cnt + 1))
  if [ $cnt -eq 100 ]; then
    echo ""
    echo "$(timestamp) [openHABian] Network unreachable, can't continue. Please reboot and let me try again."
    fail_inprogress
  fi
done
echo "OK"

echo -n "$(timestamp) [openHABian] Waiting for dpkg/apt to get ready... "
until apt update &>/dev/null; do sleep 1; done
echo "OK"

echo -n "$(timestamp) [openHABian] Updating repositories and upgrading installed packages... "
apt update &>/dev/null
apt --yes upgrade &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [openHABian] Installing git package... "
/usr/bin/apt -y install git &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi

echo -n "$(timestamp) [openHABian] Cloning myself... "
/usr/bin/git clone -b master https://github.com/openhab/openhabian.git /opt/openhabian &>/dev/null
#/usr/bin/git clone -b develop https://github.com/openhab/openhabian.git /opt/openhabian &>/dev/null
if [ $? -eq 0 ]; then echo "OK"; else echo "FAILED"; fail_inprogress; fi
ln -sfn /opt/openhabian/openhabian-setup.sh /usr/local/bin/openhabian-config

echo "$(timestamp) [openHABian] Executing 'openhabian-setup.sh unattended'"
if (/bin/bash /opt/openhabian/openhabian-setup.sh unattended); then
#if (/bin/bash /opt/openhabian/openhabian-setup.sh unattended_debug); then
  systemctl start openhab2.service
  rm -f /opt/openHABian-install-inprogress
  touch /opt/openHABian-install-successful
else
  fail_inprogress
fi
echo "$(timestamp) [openHABian] Execution of 'openhabian-setup.sh unattended' completed"
echo "$(timestamp) [openHABian] First time setup successfully finished."
echo "$(timestamp) [openHABian] To gain access to a console now, please reconnect."

# vim: filetype=sh
