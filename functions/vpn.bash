#!/usr/bin/env bash

# shellcheck disable=SC2154

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
  textReady="In order to access your system from the Internet using Wireguard, you need to setup a couple of prerequisites. Do so now if you have not already done so.\\nYou need to have a (dynamically adapting) DNS name point to your router. Get it from any of the free providers such as DuckDNS or selfhost.de.\\nYou also need to forward an UDP port from the router to your system to allow for establishing the VPN (default 51900/UDP).\\nYou need to have this information available and your router should be setup to forward the VPN port. Are you ready to proceed?"
  textInstallation="We will now install Wireguard VPN on your system. That'll take some time.\\n\\nMake use of this waiting time to install the client side part.\\nYou need to install the Wireguard client from either http://www.wireguard.com/install to your local PC or from PlayStore/AppStore to your mobile device.\\nopenHABian will display a QR code at the end of this installation to let you easily transfer the configuration."

  if [[ $1 == "remove" ]]; then
    echo -n "$(timestamp) [openHABian] Removing Wireguard service... "
    if ! cond_redirect systemctl stop wg-quick@wg0.service; then echo "FAILED (stop service)"; return 1; fi
    if ! rm -f /lib/systemd/system/wg-quick*; then echo "OK"; else echo "FAILED (remove service)"; return 1; fi
    if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi

    echo -n "$(timestamp) [openHABian] Uninstalling Wireguard... "
    if ! cond_redirect apt-get remove --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" wireguard wireguard-dkms wireguard-tools; then echo "FAILED"; return 1; fi
    if ! rm -f /etc/apt/sources.list.d/wireguard.list; then echo "FAILED (remove apt list)"; return 1; fi
    if ! cond_redirect rmmod wireguard; then echo "FAILED (remove module)"; return 1; fi
    if cond_redirect apt-get update; then echo "OK"; else echo "FAILED (update apt lists)"; return 1; fi

    if [[ -n "$INTERACTIVE" ]]; then
      whiptail --title "Wireguard VPN removed" --msgbox "We permanently removed the Wireguard installation from your system." 7 80
    fi
    return 0
  fi
  if [[ $1 != "install" ]]; then return 1; fi

  echo -n "$(timestamp) [openHABian] Installing Wireguard and enabling VPN remote access... "
  if [[ -n "$INTERACTIVE" ]]; then
    if ! whiptail --title "DynDNS hostname" --yesno --defaultno "$textReady" 15 85; then return 1; fi
    whiptail --title "Wireguard VPN installed" --msgbox "$textInstallation" 15 85
  fi

  if is_ubuntu; then
    add-apt-repository ppa:wireguard/wireguard
  else
    if is_pi || is_raspbian || is_raspios; then
      if is_buster; then
        echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/wireguard.list
        cond_redirect apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
        cond_redirect apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138

        # important to avoid release mixing:
        # prevent RPi from using the Debian distro for normal Raspbian packages
        echo -e "Package: *\\nPin: release a=unstable\\nPin-Priority: 90\\n" > /etc/apt/preferences.d/limit-unstable
      fi

      # headers required for wireguard-dkms module to be built "live"
      cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" raspberrypi-kernel-headers
    else
      if is_debian; then
        echo 'deb http://deb.debian.org/debian buster-backports main contrib non-free' > /etc/apt/sources.list.d/wireguard.list
      else
        echo "FAILED (unsupported OS)"; return 1
      fi
    fi
    if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
  fi
  cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" wireguard qrencode

  # unclear if really needed but should not do harm and does not require input so better safe than sorry
  if ! running_in_docker; then
    cond_redirect dpkg-reconfigure wireguard-dkms
    cond_redirect modprobe wireguard
  fi
  umask 077
  wg genkey | tee "$configdir"/server_private_key | wg pubkey > "$configdir"/server_public_key
  wg genkey | tee "$configdir"/client_private_key | wg pubkey > "$configdir"/client_public_key

  chown -R root:root "$configdir"

  # enable IP forwarding
  sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sed -i 's/net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' /etc/sysctl.conf
  if ! running_in_docker; then
    sysctl net.ipv4.ip_forward=1
    sysctl net.ipv6.conf.all.forwarding=1
    systemctl enable --now wg-quick@wg0
  fi

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
  local interface
  local wgServerIp wgClientIp vpnServer port
  local serverPrivate serverPublic clientPrivate clientPublic

  if ! [[ -x $(command -v dig) ]]; then
    echo -n "$(timestamp) [openHABian] Installing Wireguard required packages (dnsutils)... "
    if install_dnsutils; then echo "OK"; else echo "FAILED"; return 1; fi
  fi

  if ! pubIP="$(get_public_ip)"; then echo "FAILED (public ip)"; return 1; fi
  configdir=/etc/wireguard
  interface=${1:-eth0}
  port="${2:-51900}"
  wgServerIp="${3:-10.253.4}.1"
  wgClientIp="${3:-10.253.4}.2"
  vpnServer="${4:-$pubIP}"
  serverPrivate=$(cat "$configdir"/server_private_key)
  serverPublic=$(cat "$configdir"/server_public_key)
  clientPrivate=$(cat "$configdir"/client_private_key)
  clientPublic=$(cat "$configdir"/client_public_key)

  mkdir -p "$configdir"
  sed -e "s|%IFACE|${interface}|g" -e "s|%PORT|${port}|g" -e "s|%VPNSERVER|${vpnServer}|g" -e "s|%WGSERVERIP|${wgServerIp}|g" -e "s|%WGCLIENTIP|${wgClientIp}|g" -e "s|%SERVERPRIVATE|${serverPrivate}|g" -e "s|%CLIENTPUBLIC|${clientPublic}|g" "${BASEDIR:-/opt/openhabian}"/includes/wireguard-server.conf-template > "$configdir"/wg0.conf
  sed -e "s|%IFACE|${interface}|g" -e "s|%PORT|${port}|g" -e "s|%VPNSERVER|${vpnServer}|g" -e "s|%WGSERVERIP|${wgServerIp}|g" -e "s|%WGCLIENTIP|${wgClientIp}|g" -e "s|%SERVERPUBLIC|${serverPublic}|g" -e "s|%CLIENTPRIVATE|${clientPrivate}|g" "${BASEDIR:-/opt/openhabian}"/includes/wireguard-client.conf-template > "$configdir"/wg0-client.conf

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
  textConfigured="We have configured Wireguard to provide remote VPN access to your system.\\nInstall the Wireguard client no if you have not yet done so. Download from either http://www.wireguard.com/install to your local PC or from PlayStore/AppStore for mobile devices.\\nUse the configuration file $configdir/wg0-client.conf from this system to load the tunnel. Use the QR code displayed at the end of this installation to transfer. If you missed the output, use qrencode -t ansiutf8 </etc/wireguard/wg0-client.conf from the command line generate it again.\\nDouble-check the Endpoint parameter to match the public IP of your openHABian system before using and double-check the Address parameter in config files for both, client (wg0-client.conf) and server (wg0.conf)."

  # iface=eth0 or wlan0
  if [[ -n "$INTERACTIVE" ]]; then
    if ! iface=$(whiptail --title "VPN interface" --inputbox "Which interface do you want to setup the VPN on?" 10 60 "$iface" 3>&1 1>&2 2>&3); then return 1; fi
    if ! defaultNetwork=$(whiptail --title "VPN network" --inputbox "What's the IP network to be assigned to the VPN?\\nSpecify the first 3 octets." 10 60 "$defaultNetwork" 3>&1 1>&2 2>&3); then return 1; fi
    if ! dynDNS=$(whiptail --title "dynamic domain name" --inputbox "Which dynamic DNS name is your router running found as from the Internet?" 10 60 3>&1 1>&2 2>&3); then return 1; fi
    if ! port=$(whiptail --title "VPN port" --inputbox "Which port do you want to expose for establishing the VPN?" 10 60 "$port" 3>&1 1>&2 2>&3); then return 1; fi
  fi
  create_wireguard_config "$iface" "$port" "$defaultNetwork" "$dynDNS"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Wireguard VPN setup" --msgbox "$textConfigured" 20 85
  fi

  echo -n "$(timestamp) [openHABian] Generating QR to load config on the client side (download Wireguard app from PlayStore or AppStore)... "
  qrencode -t ansiutf8 </etc/wireguard/wg0-client.conf
}


## Install tailscale from their own repo
## Valid arguments: "install" or "remove"
##
##   install_tailscale(String action)
##
install_tailscale() {
  local installText="We will install the tailscale VPN client on your system. Use it to securely interconnect multiple openHAB(ian) instances.\\nSee https://tailscale.com/blog/how-tailscale-works/ for a comprehensive explanation how it creates a secure VPN. For personal use, you can get a free solo service from tailscale.com."
  local removeText="We will remove the tailscale VPN client from your system.\\n\\nDouble-check ~/.ssh/authorized_keys and eventually remove the admin key."
  local serviceTargetDir="/lib/systemd/system"
  local sudoersFile="011_openhab-tailscale"
  local sudoersPath="/etc/sudoers.d"
  local keyName="tailscale-archive-keyring"

  if [[ -n "$UNATTENDED" ]]; then
    if [[ ! -v preauthkey ]]; then echo "$(timestamp) [openHABian] tailscale VPN installation... SKIPPED (no preauthkey defined)"; return 1; fi
  fi

  if [[ "$1" == "remove" ]]; then
    if [[ -n "$INTERACTIVE" ]]; then
      if (whiptail --title "Remove tailscale VPN" --yes-button "Continue" --no-button "Cancel" --yesno "$removeText" 12 80); then echo "OK"; else echo "CANCELED"; return 1; fi
    fi
    echo "$(timestamp) [openHABian] Removing tailscale VPN... "
    cond_redirect systemctl disable tailscaled.service
    rm -f ${serviceTargetDir}/tailscale*
    if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
    if ! apt-get purge --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" tailscale; then echo "FAILED (purge tailscale)"; return 1; fi
    if ! rm -f /etc/apt/sources.list.d/tailscale.list "${sudoersPath}/${sudoersFile}"; then echo "FAILED (purge tailscale)"; return 1; fi
    return 0
  fi

  if [[ "$1" != "install" ]]; then return 1; fi
  if ! dpkg -s 'mailutils' 'exim4' &> /dev/null; then
    exim_setup
  fi
  if [[ -n "$INTERACTIVE" ]]; then
    if (whiptail --title "Tailscale VPN setup" --yes-button "Continue" --no-button "Cancel" --yesno "$installText" 12 80); then echo "OK"; else echo "CANCELED"; return 1; fi
  fi
  echo "$(timestamp) [openHABian] Installing tailscale VPN... "
  # Add tailscale's GPG key
  add_keys "https://pkgs.tailscale.com/stable/raspbian/bullseye.gpg" "$keyName"
  # Add the tailscale repository
  echo "deb [signed-by=/usr/share/keyrings/${keyName}.gpg] https://pkgs.tailscale.com/stable/raspbian bullseye main" > /etc/apt/sources.list.d/tailscale.list
  if ! cond_redirect apt-get update; then echo "FAILED (update apt lists)"; return 1; fi
  # Install tailscale
  if cond_redirect apt-get install --yes -o DPkg::Lock::Timeout="$APTTIMEOUT" tailscale; then echo "OK"; else echo "FAILED (install tailscale)"; return 1; fi
  cp "${BASEDIR:-/opt/openhabian}/includes/${sudoersFile}" "${sudoersPath}/"

  return 0
}


## add node to private tailscale network
##
##   setup_tailscale(String action)
##
## argument 1 is tailscape key
## argument 2 is tailscale tags
##
setup_tailscale() {
  local preAuthKey="${1:-${preauthkey}}"
  local tags="${2:-${tstags}}"
  local consoleProperties="${OPENHAB_USERDATA:-/var/lib/openhab}/etc/org.apache.karaf.shell.cfg"
  local tailscaleIP

  if [[ -n $UNATTENDED ]] && [[ -z $preAuthKey ]]; then
    echo "$(timestamp) [openHABian] Installing tailscale VPN... SKIPPED (no pre auth key provided)"
    return 0
  fi
  if [[ -n "$INTERACTIVE" ]]; then
    if ! preAuthKey="$(whiptail --title "Enter pre auth key" --inputbox "\\nIf you have not received / created the tailscale pre auth key at this stage, please do so now or tell your administrator to. This can be done on the admin console. There's a menu option on the tailscale Windows client to lead you there.\\n\\nPlease enter the tailscale pre auth key for this system:" 13 80 "$preAuthKey" 3>&1 1>&2 2>&3)"; then echo "CANCELED"; return 0; fi
  fi

  # if ${tags}/${tstags} is empty, this will reset existing tags
  if ! tailscale up --reset --authkey "${preAuthKey}" --advertise-tags="${tags}"; then echo "FAILED (join tailscale VPN)"; return 1; fi
  [[ -n "$adminmail" ]] && tailscale status | mail -s "openHABian client joined tailscale VPN" "$adminmail"
  tailscaleIP=$(ip a show tailscale0 | awk '/inet / { print substr($2,1,length($2)-3)}')
  if [[ -n "$tailscaleIP"  ]]; then
    sed -ri "s|^(sshHost.*)|\\1,${tailscaleIP}|g" "$consoleProperties"
  fi
  if cond_redirect sed -i -e 's|^preauthkey=.*$|preauthkey=xxxxxxxx|g' /etc/openhabian.conf; then echo "OK"; else echo "FAILED (remove tailscale pre-auth key)"; exit 1; fi

  return 0
}


## reset tailscale VPN auth with new key
##
##   reset_tailscale_auth(String tskey, tags)
##
## argument 1 is tailscape key
## argument 2 is tailscale tags
##
reset_tailscale_auth() {
  local preAuthKey="${1:-${preauthkey}}"
  local tags="${2:-${tstags}}"

  tailscale up --reset --authkey "${preAuthKey}" --advertise-tags="${tags}"
}

