#!/usr/bin/env bash

wifi_setup() {
  echo -n "$(timestamp) [openHABian] Setting up Wifi (PRi3 or Pine A64)... "
  if ! is_pithree && ! is_pizerow && ! is_pine64; then
    if [ -n "$INTERACTIVE" ]; then
      whiptail --title "Incompatible Hardware Detected" --msgbox "Wifi setup: This option is for the Pi3, Pi0W or the Pine A64 system only." 10 60
    fi
    echo "FAILED"; return 1
  fi
  if [ -n "$INTERACTIVE" ]; then
    SSID=$(whiptail --title "Wifi Setup" --inputbox "Which Wifi (SSID) do you want to connect to?" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 1; fi
    PASS=$(whiptail --title "Wifi Setup" --inputbox "What's the password for that Wifi?" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then return 1; fi
  else
    echo -n "Setting default SSID and password in 'wpa_supplicant.conf' "
    SSID="myWifiSSID"
    PASS="myWifiPassword"
  fi
  if is_pithree; then cond_redirect apt -y install firmware-brcm80211; fi
  cond_redirect apt -y install wpasupplicant wireless-tools
  echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1" > /etc/wpa_supplicant/wpa_supplicant.conf
  echo -e "network={\n\tssid=\"$SSID\"\n\tpsk=\"$PASS\"\n}" >> /etc/wpa_supplicant/wpa_supplicant.conf
  if grep -q "wlan0" /etc/network/interfaces; then
    cond_echo ""
    cond_echo "Not writing to '/etc/network/interfaces', wlan0 entry already available. You might need to check, adopt or remove these lines."
    cond_echo ""
  else
    echo -e "\nallow-hotplug wlan0\niface wlan0 inet manual\nwpa-roam /etc/wpa_supplicant/wpa_supplicant.conf\niface default inet dhcp" >> /etc/network/interfaces
  fi
  cond_redirect wpa_cli reconfigure
  cond_redirect ifdown wlan0
  cond_redirect ifup wlan0
  if [ -n "$INTERACTIVE" ]; then
    whiptail --title "Operation Successful!" --msgbox "Setup was successful. Your Wifi credentials were NOT tested. Please reboot now." 15 80
  fi
  echo "OK (Reboot needed)"
}
