#!/usr/bin/env bash

## install wireguard from unstable Debian
## as long as it is not in the Raspbian repo
##
##   install_wireguard
##
install_wireguard() {
  echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/wireguard.list
  apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
  apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 648ACFD622F3D138

  # important to avoid release mixing:
  # prevent RPi from using the Debian distro for normal Raspbian packages
  sh -c 'printf "Package: *\nPin: release a=unstable\nPin-Priority: 90\n" > /etc/apt/preferences.d/limit-unstable'
  apt_update

  # headers required for wireguard-dkms module to be built "live"
  apt-get install --yes wireguard raspberrypi-kernel-headers

  # unclear if really needed but should not do harm and does not require input so better safe than sorry
  dpkg-reconfigure wireguard-dkms

  cd /etc/wireguard || return 1
  umask 077
  wg genkey | tee server_private_key | wg pubkey > server_public_key
  wg genkey | tee client_private_key | wg pubkey > client_public_key

  # enable IP forwarding
  sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

  chown -R root:root /etc/wireguard/
  systemctl enable wg-quick@wg0
}

## create a wireguard config
## argument 1 is network interface (eth0 or wlan0)
## argument 2 is VPN network of Allowed Clients in format 10.253.46.10/24
## with .1 = IP of the WG server and .10 as the first IP from the VPN range to assign to clients
##
##   create_wireguard_config(String iface, String private network (3 octets), String VPN server public IP (optional))
##
create_wireguard_config() {

  pubIP=$(dig +short myip.opendns.com @resolver1.opendns.com | tail -1)

  local IFACE=${1:eth0}
  local WGSERVERIP="${2:-10.253.4}.1"
  local WGCLIENTIP="${2:-10.253.4}.2"
  local VPNSERVER="${3:-$pubIP}"
  local PORT=51900
  SERVERPRIVATE=$(cat /etc/wireguard/server_private_key)
  SERVERPUBLIC=$(cat /etc/wireguard/server_public_key)
  CLIENTPRIVATE=$(cat /etc/wireguard/client_private_key)
  CLIENTPUBLIC=$(cat /etc/wireguard/client_public_key)


  sed -e "s|%IFACE|${IFACE}|g" -e "s|%PORT|${PORT}|g" -e "s|%VPNSERVER|${VPNSERVER}|g" -e "s|%WGSERVERIP|${WGSERVERIP}|g" -e "s|%WGCLIENTIP|${WGCLIENTIP}|g" -e "s|%SERVERPRIVATE|${SERVERPRIVATE}|g" -e "s|%CLIENTPUBLIC|${CLIENTPUBLIC}|g" "$BASEDIR"/includes/wireguard-server.conf > /etc/wireguard/wg0.conf
  sed -e "s|%IFACE|${IFACE}|g" -e "s|%PORT|${PORT}|g" -e "s|%VPNSERVER|${VPNSERVER}|g" -e "s|%WGSERVERIP|${WGSERVERIP}|g" -e "s|%WGCLIENTIP|${WGCLIENTIP}|g" -e "s|%SERVERPUBLIC|${SERVERPUBLIC}|g" -e "s|%CLIENTPRIVATE|${CLIENTPRIVATE}|g" "$BASEDIR"/includes/wireguard-client.conf > /etc/wireguard/wg0-client.conf

  chmod -R og-rwx /etc/wireguard/*
}

## setup wireguard for VPN access
## argument 1 is network interface (eth0 or wlan0)
## argument 2 is VPN network of Allowed Clients in format 10.253.46.10/24
## with .1 = WG server and .10 as first IP to assign to clients
##
##   setup_wireguard(String iface)
##
setup_wireguard() {
  local iface="eth0"
  local defaultnetwork="10.253.4"

  # iface=eth0 or wlan0
  if [[ -n "$INTERACTIVE" ]]; then
  	iface=$(whiptail --title "VPN interface" --inputbox "Do you want to setup to the VPN ?\\nSpecify the first 3 octets." 10 60 $defaultnetwork 3>&1 1>&2 2>&3)
  	network=$(whiptail --title "VPN network" --inputbox "What's the IP network to be assigned to the VPN ?\\nSpecify the first 3 octets." 10 60 $defaultnetwork 3>&1 1>&2 2>&3)
  fi
  create_wireguard_config "$iface" "$network"
}

