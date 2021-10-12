#!/usr/bin/env bash

## Generate/copy openHAB config for a PV inverter
## Valid Arguments: kostal | sungrow
##                  IP address
##
##    setup_inverter_config(String inverter type,String inverter IP)
##
setup_inverter_config() {
  local sdIncludesDir="${BASEDIR:-/opt/openhabian}/includes/SD"


  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] inverter installation... "
    if [[ ! -v invertertype ]]; then echo "SKIPPED (no inverter defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$invertertype}" ]]; then
      if ! invertertype="$(whiptail --title "Wechselrichter Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wechselrichtertyp aus" 12 80 0 "kostal" "Kostal Plenticore" "sungrow" "Sungrow SH RT" "solaredge" "SolarEdge SE" 3>&1 1>&2 2>&3)"; then unset invertertype; return 1; fi
    fi
    if ! inverterip=$(whiptail --title "Wechselrichter IP" --inputbox "Welche IP-Adresse hat der Wechselrichter ?" 10 60 "${inverterip:-192.168.178.100}" 3>&1 1>&2 2>&3); then unset invertertype inverterip; return 1; fi
  fi

  if [[ ! -f /usr/local/sbin/setup_inverter ]]; then
    if ! cond_redirect install -m 755 "${sdIncludesDir}/setup_inverter" /usr/local/sbin; then echo "FAILED (install setup_inverter)"; return 1; fi
  fi

  for component in things items rules; do
    cp "${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${invertertype}}.${component}" "${OPENHAB_CONF:-/etc/openhab}/${component}/inverter.${component}"
    chown "${username:-openhabian}:${username:-openhabian}" "${OPENHAB_CONF:-/etc/openhab}/${component}/inverter.${component}"
  done

  sed -ie "s|%IP|${2:-${inverterip}}|" "${OPENHAB_CONF:-/etc/openhab}/things/inverter.things"

  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Operation successful" --msgbox "The Energy Management System is now setup to use a ${1:-${invertertype}} inverter." 8 80
  fi
}

