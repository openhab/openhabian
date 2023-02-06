#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2155

## Check if Network UPS Tools is installed
##
##  nut_is_installed()
##
nut_is_installed() {
  if dpkg -s 'nut' &> /dev/null; then return 0; fi
  return 1
}

## (Un)Install Network UPS Tools
## Supports both INTERACTIVE and UNATTENDED mode.
##
## Valid arguments: "install" or "remove"
##
##   nut_install(String action)
##
nut_install() {
  if [[ $1 == "remove" ]]; then
    if [[ -n $INTERACTIVE ]]; then
      whiptail --title "nut removal" --msgbox "This will remove Network UPS Tools (nut)." 7 80
    fi
    echo -n "$(timestamp) [openHABian] Removing Network UPS Tools... "
    if cond_redirect apt purge -y nut; then echo "OK"; else echo "FAILED"; return 1; fi
    return;
  fi

  if [[ $1 != "install" ]]; then return 1; fi
  if [[ -n $INTERACTIVE ]]; then
    whiptail --title "nut installation" --msgbox "This will install Network UPS Tools (nut)." 8 80
  fi

  echo -n "$(timestamp) [openHABian] Installing Network UPS Tools... "
  if cond_redirect apt install -y nut; then echo "OK"; else echo "FAILED (package installation)"; return 1; fi

  ## Do service activation later as nut-server & nut-client depend on the setup!
}

## Configure Network UPS Tools
## Supports only UNATTENDED mode
##
## Variables used:
##   - "nutmode": "netserver" or "netclient"
##   for "netserver":
##   - "nutupsdriver": driver for local UPS
##   - "nutupsdescr": description for local UPS
##  for "netclient":
##   - "nutupsname": name of network UPS
##   - "nutupshost": host of network UPS
##   - "nutupsuser": username for network UPS
##   - "nutupspw": password for network UPS
##
##   nut_setup()
##
nut_setup() {
  if [[ -n $UNATTENDED ]] && [[ -z $nutmode ]]; then
    echo "$(timestamp) [openHABian] Beginning Network UPS Tools setup... SKIPPED (no configuration provided)"
    return 0
  fi

  local upsmasterpw="$(openssl rand -base64 12)"
  local upsslavepw="$(openssl rand -base64 12)"

  local upsmonitor="MONITOR ups@localhost 1 upsmaster ${upsmasterpw} master"

  if ! nut_is_installed; then nut_install "install"; fi

  echo -n "$(timestamp) [openHABian] Setting up nut... "
  if [[ -z $nutmode ]]; then echo "FAILED (nutmode is not set)"; return 1; fi
  if ! (sed -e "s|%NUTMODE|${nutmode}|g" "${BASEDIR:-/opt/openhabian}"/includes/nut/nut.conf > /etc/nut/nut.conf); then echo "FAILED (nut.conf file update)"; return 1; fi

  # Setup local host as nut server; therefore UPS is attached to the local host
  if [[ $nutmode == "netserver" ]]; then
    # Setup nut-server
    if ! (sed -e "s|%NUTUPSDRIVER|${nutupsdriver:-usbhid-ups}|g" -e "s|%NUTUPSDESCR|${nutupsdescr:-UPS on ${hostname}}|g" "${BASEDIR:-/opt/openhabian}"/includes/nut/ups.conf > /etc/nut/ups.conf); then echo "FAILED (ups.conf file update)"; return 1; fi
    if ! cond_redirect upsdrvctl start; then echo "FAILED (connection test)"; return 1; fi
    if ! cp "${BASEDIR:-/opt/openhabian}/includes/nut/upsd.conf" "/etc/nut/upsd.conf"; then echo "FAILED (upsd.conf file update)"; return 1; fi
    if ! (sed -e "s|%NUTUPSMASTERPW|${upsmasterpw}|g" -e "s|%NUTUPSSLAVEPW|${upsslavepw}|g" "${BASEDIR:-/opt/openhabian}"/includes/nut/upsd.users > /etc/nut/upsd.users); then echo "FAILED (upsd.users file update)"; return 1; fi
    # Enable and start nut-server.service
    if ! cond_redirect systemctl enable nut-server.service; then echo "FAILED (enable nut-server.service)"; return 1; fi
    if ! cond_redirect systemctl restart nut-server.service; then echo "FAILED (restart nut-server.service)"; return 1; fi

    # Setup nut-client for local server
    if ! (sed -e "s|%NUTMONITOR|${upsmonitor}|g" "${BASEDIR:-/opt/openhabian}"/includes/nut/upsmon.conf > /etc/nut/upsmon.conf); then echo "FAILED (upsmon.conf file update)"; return 1; fi
  fi

  # Setup local host as nut client; therefore monitor an UPS on the network
  if [[ $nutmode == "netclient" ]]; then
    if [[ -z $nutupshost ]]; then echo "FAILED (nutupshost is not set)"; return 1; fi

    # Disable nut-server.service
    if ! cond_redirect systemctl disable --now nut-server.service; then echo "FAILED (disable & stop nut-server.service)"; return 1; fi

    # Setup nut-client for remote server
    upsmonitor="MONITOR ${nutupsname:-ups}@${nutupshost} 1 ${nutupsuser:-monuser} ${nutupspw:-secret} slave"
    if ! (sed -e "s|%NUTMONITOR|${upsmonitor}|g" "${BASEDIR:-/opt/openhabian}"/includes/nut/upsmon.conf > /etc/nut/upsmon.conf); then echo "FAILED (upsmon.conf file update)"; return 1; fi
  fi

  if ! cond_redirect systemctl enable nut-client.service; then echo "FAILED (enable nut-client.service)"; return 1; fi
  if ! cond_redirect systemctl restart nut-client.service; then echo "FAILED (restart nut-client.service)"; return 1; fi
  echo "OK"
}
