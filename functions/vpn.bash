#!/usr/bin/env bash

## Install wireguard from unstable Debian as long as it is not in the Raspbian repo
## Valid arguments: "install" or "remove"
##
##   install_wireguard(String action)
##
install_wireguard() {
  local configdir
  local textReady
  local textInstallation


  configdir="/etc/wireguard"
  textReady="In order to access your system from the Internet using Wireguard, you need to setup a couple of prerequisites. Do so now if you have not already done so.\\nYou need to have a (dynamically adapting) DNS name point to your router. Get it from any of the free providers such as DuckDNS or selfhost.de.\\nYou also need to forward an UDP port from the router to your system to allow for establishing the VPN (default 51900/UDP).\\nYou need to have this information available and your router should be setup to forward the VPN port. Are you ready to proceed ?"
  textInstallation="We will now install Wireguard VPN on your system. That'll take some time.\\n\\nMake use of this waiting time to install the client side part.\\nYou need to install the Wireguard client from either http://www.wireguard.com/install to your local PC or from PlayStore/AppStore to your mobile device.\\nopenHABian will display a QR code at the end of this installation to let you easily transfer the configuration."

  if [[ "$1" == "remove" ]]; then
    echo -n "$(timestamp) [openHABian] Removing Wireguard and VPN access... "
    apt remove --yes wireguard wireguard-dkms wireguard-tools

    systemctl stop wg-quick@wg0
    rm -f /lib/systemd/system/wg-quick*
    systemctl -q daemon-reload &>/dev/null
    rmmod wireguard

    rm -f /etc/apt/sources.list.d/wireguard.list
    if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Wireguard VPN removed" --msgbox "We permanently removed the Wireguard installation from your system." 8 80
    fi
    echo "OK"
    return 0
  fi
  if [[ $1 != "install" ]]; then return 1; fi

  echo -n "$(timestamp) [openHABian] Installing Wireguard and enabling VPN remote access... "
  if [[ -n "$INTERACTIVE" ]]; then
    if ! whiptail --title "DynDNS hostname" --yesno --defaultno "$textReady" 15 85; then return 1; fi
    whiptail --title "Wireguard VPN installed" --msgbox "$textInstallation" 15 85
  fi

set -x
if is_ubuntu; then
    add-apt-repository ppa:wireguard/wireguard
  else
    if is_pi || is_raspbian || is_raspios; then
      echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/wireguard.list
      apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
      apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 648ACFD622F3D138

      # important to avoid release mixing:
      # prevent RPi from using the Debian distro for normal Raspbian packages
      echo -e "Package: *\\nPin: release a=unstable\\nPin-Priority: 90\\n" > /etc/apt/preferences.d/limit-unstable

      # headers required for wireguard-dkms module to be built "live"
      apt-get install --yes raspberrypi-kernel-headers
    else
      if is_debian; then
        echo 'deb http://deb.debian.org/debian buster-backports main contrib non-free' > /etc/apt/sources.list.d/wireguard.list
      else
        echo "FAILED (unsupported OS)"; return 1
      fi
    fi
    if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
  fi
#  apt-get install --yes wireguard wireguard-dmks wireguard-tools qrencode
  apt-get install --yes wireguard qrencode

  # unclear if really needed but should not do harm and does not require input so better safe than sorry
  dpkg-reconfigure wireguard-dkms
  modprobe wireguard

  umask 077
  wg genkey | tee "$configdir"/server_private_key | wg pubkey > "$configdir"/server_public_key
  wg genkey | tee "$configdir"/client_private_key | wg pubkey > "$configdir"/client_public_key

  # enable IP forwarding
  sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sed -i 's/net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
  sysctl net.ipv4.ip_forward=1
  sysctl net.ipv6.conf.all.forwarding=1

  chown -R root:root "$configdir"
  systemctl enable --now wg-quick@wg0

  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Wireguard VPN installed" --msgbox "Wireguard VPN was successfully installed on your system. We will now move to to configure it for remote access." 8 80
  else
    echo "OK"
  fi
}


## Create a wireguard config
## argument 1 is network interface (eth0 or wlan0)
## argument 2 is VPN network of Allowed Clients in format 10.253.46.10/24
## with .1 = IP of the WG server and .10 as the first IP from the VPN range to assign to clients
##
##   create_wireguard_config(String iface (optional),
##                           String private network (first 3 octets) (optional),
##                           String VPN server public DNS name/IP (optional),
##                           String VPN public port (optional))
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
  pubIP=$(dig -4 +short myip.opendns.com @resolver1.opendns.com | tail -1)
  if [ -z "$pubIP" ]; then
    if pubIP=$(dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com|tr -d '"'); then echo "$pubIP"; else echo "FAILED"; return 1; fi
  fi

  configdir=/etc/wireguard
  IFACE=${1:-eth0}
  PORT="${2:-51900}"
  WGSERVERIP="${3:-10.253.4}.1"
  WGCLIENTIP="${3:-10.253.4}.2"
  VPNSERVER="${4:-$pubIP}"
  SERVERPRIVATE=$(cat "$configdir"/server_private_key)
  SERVERPUBLIC=$(cat "$configdir"/server_public_key)
  CLIENTPRIVATE=$(cat "$configdir"/client_private_key)
  CLIENTPUBLIC=$(cat "$configdir"/client_public_key)


  mkdir -p "$configdir"
  sed -e "s|%IFACE|${IFACE}|g" -e "s|%PORT|${PORT}|g" -e "s|%VPNSERVER|${VPNSERVER}|g" -e "s|%WGSERVERIP|${WGSERVERIP}|g" -e "s|%WGCLIENTIP|${WGCLIENTIP}|g" -e "s|%SERVERPRIVATE|${SERVERPRIVATE}|g" -e "s|%CLIENTPUBLIC|${CLIENTPUBLIC}|g" "$BASEDIR"/includes/wireguard-server.conf-template > "$configdir"/wg0.conf
  sed -e "s|%IFACE|${IFACE}|g" -e "s|%PORT|${PORT}|g" -e "s|%VPNSERVER|${VPNSERVER}|g" -e "s|%WGSERVERIP|${WGSERVERIP}|g" -e "s|%WGCLIENTIP|${WGCLIENTIP}|g" -e "s|%SERVERPUBLIC|${SERVERPUBLIC}|g" -e "s|%CLIENTPRIVATE|${CLIENTPRIVATE}|g" "$BASEDIR"/includes/wireguard-client.conf-template > "$configdir"/wg0-client.conf

  chmod -R og-rwx "$configdir"/*
}


## Setup wireguard for VPN access
## argument 1 is network interface (eth0 or wlan0)
## argument 2 is the port to expose for establishment of the VPN
## argument 3 is VPN network of Allowed Clients in format 10.253.46.10/24
## with .1 = WG server and .10 as first IP to assign to clients
##
##   setup_wireguard(String iface, String port, String network (first 3 octets))
##
setup_wireguard() {
  local iface
  local port
  local defaultNetwork
  local dynDNS
  local textConfigured


  iface="${1:-eth0}"
  port="${2:-51900}"
  defaultNetwork="${3:-10.253.4}"
  textConfigured="We have configured Wireguard to provide remote VPN access to your system.\\Install the Wireguard client no if you have not yet done so. Download from either http://www.wireguard.com/install to your local PC or from PlayStore/AppStore for mobile devices.\\nUse the configuration file $configdir/wg0-client.conf from this system to load the tunnel. Use the QR code displayed at the end of this installation to transfer. If you missed the output, use qrencode -t ansiutf8 </etc/wireguard/wg0-client.conf from the command line generate it again.\\nDouble-check the Endpoint parameter to match the public IP of your openHABian system before using and double-check the Address parameter in config files for both, client (wg0-client.conf) and server (wg0.conf)."

  # iface=eth0 or wlan0
  if [[ -n "$INTERACTIVE" ]]; then
    if ! iface=$(whiptail --title "VPN interface" --inputbox "Which interface do you want to setup the VPN on ?" 10 60 "$iface" 3>&1 1>&2 2>&3); then return 1; fi
    if ! defaultNetwork=$(whiptail --title "VPN network" --inputbox "What's the IP network to be assigned to the VPN ?\\nSpecify the first 3 octets." 10 60 "$defaultNetwork" 3>&1 1>&2 2>&3); then return 1; fi
    if ! dynDNS=$(whiptail --title "dynamic domain name" --inputbox "Which dynamic DNS name is your router running found as from the Internet ?" 10 60 3>&1 1>&2 2>&3); then return 1; fi
    if ! port=$(whiptail --title "VPN port" --inputbox "Which port do you want to expose for establishing the VPN ?" 10 60 "$port" 3>&1 1>&2 2>&3); then return 1; fi
  fi
  create_wireguard_config "$iface" "$port" "$defaultNetwork" "$dynDNS"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Wireguard VPN setup" --msgbox "$textConfigured" 20 85
  fi

  echo -n "$(timestamp) [openHABian] Generating QR to load config on the client side (download Wireguard app from PlayStore or AppStore)... "
  qrencode -t ansiutf8 </etc/wireguard/wg0-client.conf
}
