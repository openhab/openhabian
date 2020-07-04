#!/usr/bin/env bash

## Install wireguard from unstable Debian
## as long as it is not in the Raspbian repo
##
##   install_wireguard()
##
install_wireguard() {
  local configdir


  configdir=/etc/wireguard
  if [[ "$1" == "remove" ]]; then
    echo -n "$(timestamp) [openHABian] Removing Wireguard and VPN access... "
    apt remove --yes wireguard

    systemctl stop wg-quick@wg0
    rm -f /lib/systemd/system/wg-quick*
    systemctl -q daemon-reload &>/dev/null

    rm -f /etc/apt/sources.list.d/wireguard.list
    if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Wireguard VPN removed" --msgbox "We permanently removed the Wireguard installation from your box." 8 80 3>&1 1>&2 2>&3
    fi
    echo "OK"
    return 0
  fi
  if [[ "$1" != "install" ]]; then return 1; fi

  echo -n "$(timestamp) [openHABian] Installing Wireguard and enabling VPN remote access... "
  echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/wireguard.list
  apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
  apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 648ACFD622F3D138

  # important to avoid release mixing:
  # prevent RPi from using the Debian distro for normal Raspbian packages
  echo -e "Package: *\\nPin: release a=unstable\\nPin-Priority: 90\\n" > /etc/apt/preferences.d/limit-unstable
  if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi

  # headers required for wireguard-dkms module to be built "live"
  apt-get install --yes wireguard raspberrypi-kernel-headers

  # unclear if really needed but should not do harm and does not require input so better safe than sorry
  dpkg-reconfigure wireguard-dkms

  umask 077
  wg genkey | tee "$configdir"/server_private_key | wg pubkey > "$configdir"/server_public_key
  wg genkey | tee "$configdir"/client_private_key | wg pubkey > "$configdir"/client_public_key

  # enable IP forwarding
  sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

  chown -R root:root "$configdir"
  systemctl enable wg-quick@wg0

  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Wireguard VPN installed" --msgbox "We installed the Wireguard VPN on your box." 8 80 3>&1 1>&2 2>&3
  else
    echo "OK"
  fi
}

## Create a wireguard config
## argument 1 is network interface (eth0 or wlan0)
## argument 2 is VPN network of Allowed Clients in format 10.253.46.10/24
## with .1 = IP of the WG server and .10 as the first IP from the VPN range to assign to clients
##
##   create_wireguard_config(String iface, String private network (first 3 octets),
##                           String VPN server public IP (optional))
##
create_wireguard_config() {
  local configdir
  local pubIP
  local IFACE
  local WGSERVERIP WGCLIENTIP VPNSERVER PORT
  local SERVERPRIVATE SERVERPUBLIC CLIENTPRIVATE CLIENTPUBLIC 


  if ! [[ -x $(command -v dig) ]]; then
    echo -n "$(timestamp) [openHABian] Installing Wireguard required packages (dnsutils)... "
    if cond_redirect apt-get install --yes dnsutils; then echo "OK"; else echo "FAILED"; return 1; fi
  fi
  pubIP=$(dig +short myip.opendns.com @resolver1.opendns.com | tail -1)

  configdir=/etc/wireguard
  WGSERVERIP="${2:-10.253.4}.1"
  WGCLIENTIP="${2:-10.253.4}.2"
  VPNSERVER="${3:-$pubIP}"
  PORT=51900
  SERVERPRIVATE=$(cat "$configdir"/server_private_key)
  SERVERPUBLIC=$(cat "$configdir"/server_public_key)
  CLIENTPRIVATE=$(cat "$configdir"/client_private_key)
  CLIENTPUBLIC=$(cat "$configdir"/client_public_key)


  sed -e "s|%IFACE|${IFACE}|g" -e "s|%PORT|${PORT}|g" -e "s|%VPNSERVER|${VPNSERVER}|g" -e "s|%WGSERVERIP|${WGSERVERIP}|g" -e "s|%WGCLIENTIP|${WGCLIENTIP}|g" -e "s|%SERVERPRIVATE|${SERVERPRIVATE}|g" -e "s|%CLIENTPUBLIC|${CLIENTPUBLIC}|g" "$BASEDIR"/includes/wireguard-server.conf > "$configdir"/wg0.conf
  sed -e "s|%IFACE|${IFACE}|g" -e "s|%PORT|${PORT}|g" -e "s|%VPNSERVER|${VPNSERVER}|g" -e "s|%WGSERVERIP|${WGSERVERIP}|g" -e "s|%WGCLIENTIP|${WGCLIENTIP}|g" -e "s|%SERVERPUBLIC|${SERVERPUBLIC}|g" -e "s|%CLIENTPRIVATE|${CLIENTPRIVATE}|g" "$BASEDIR"/includes/wireguard-client.conf > "$configdir"/wg0-client.conf

  chmod -R og-rwx "$configdir"/*

  if [[ -n "$INTERACTIVE" ]]; then
	  whiptail --title "Wireguard VPN setup" --msgbox "We have installed and preconfigured Wireguard to provide remote VPN access to your box.\\nYou need to install the Wireguard client from http://www.wireguard.com/install on your local PC or mobile device that you want to use for access.\\nUse the configuration file $configdir/wg0-client.conf from this box to load the tunnel.\\nDouble-check the Endpoint parameter to match the public IP of your openHABian box and double-check the Address parameter in config files for both, client (wg0-client.conf) and server (wg0.conf)." 8 80 3>&1 1>&2 2>&3
  fi
}

## Setup wireguard for VPN access
## argument 1 is network interface (eth0 or wlan0)
## argument 2 is VPN network of Allowed Clients in format 10.253.46.10/24
## with .1 = WG server and .10 as first IP to assign to clients
##
##   setup_wireguard(String iface, String network (first 3 octets))
##
setup_wireguard() {
  local iface
  local defaultnetwork
  
  
  iface="${1:-eth0}"
  defaultnetwork="${2:-10.253.4}"

  # iface=eth0 or wlan0
  if [[ -n "$INTERACTIVE" ]]; then
  	iface=$(whiptail --title "VPN interface" --inputbox "Which interface do you want to setup the VPN on ?" 10 60 "$iface" 3>&1 1>&2 2>&3)
  	network=$(whiptail --title "VPN network" --inputbox "What's the IP network to be assigned to the VPN ?\\nSpecify the first 3 octets." 10 60 "$defaultnetwork" 3>&1 1>&2 2>&3)
  fi
  create_wireguard_config "$iface" "$network"
}

