#!/usr/bin/env bash

## Generate/copy openHAB config for a PV inverter
## Valid Arguments: kostal | sungrow
##                  IP address
##
##    setup_inverter_config(String inverter type,String inverter IP)
##
setup_inverter_config() {
  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] inverter installation... "
    if [[ ! -v invertertype ]]; then echo "SKIPPED (no inverter defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "$invertertype" ]]; then
      invertertype="$(whiptail --title "Wechselrichter Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wechselrichtertyp aus" 10 80 0 "Kostal" "Kostal Plenticore" "Sungrow" "Sungrow SH RT" 3>&1 1>&2 2>&3)"
    fi
    if ! inverterip=$(whiptail --title "Wechselrichter IP" --inputbox "Welche IP-Adresse hat der Wechselrichter ?" 10 60 "${inverterip:-192.168.178.100}" 3>&1 1>&2 2>&3); then return 1; fi
  fi

  for component in things items rules; do
    cp "${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1,,}.${component}" "${OPENHAB_CONF:-/etc/openhab}/${component}/inverter.${component}"
    chown "${username:-openhabian}:${username:-openhabian}" "${OPENHAB_CONF:-/etc/openhab}/${component}/inverter.${component}"
  done

  sed -ie "s|%IP|${2:-${inverterip}}|" "${OPENHAB_CONF:-/etc/openhab}/things/inverter.things"

  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Operation successful" --msgbox "The Energy Management System is now setup to use a $1 inverter." 8 80
  fi
}

