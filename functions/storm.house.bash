#!/usr/bin/env bash

<<<<<<< HEAD
## Generate/copy openHAB config for a PV inverter and optional a meter, too
## Valid Arguments: manuell | kostal | sungrow | solaredge | fronius
##                  IP address of inverter
##     (optional)   IP address of meter
##
##    setup_pv_config(String inverter type,String inverter IP,String meter IP)
##
setup_pv_config() {
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"


  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] inverter installation... "
    if [[ ! -v invertertype ]]; then echo "SKIPPED (no inverter defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$invertertype}" ]]; then
        if ! invertertype="$(whiptail --title "Wechselrichter Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wechselrichtertyp aus" 13 80 0 "sunspec" "generisch, SunSpec kompatibel" "kostal" "Kostal Plenticore" "sungrow" "Sungrow SH RT" "solaredge" "SolarEdge SE (ungetestet)" "fronius" "Fronius Symo (ungetestet)" "manuell" "keiner (manuelle Konfiguration)" 3>&1 1>&2 2>&3)"; then unset invertertype; return 1; fi
    fi
    if ! inverterip=$(whiptail --title "Wechselrichter IP" --inputbox "Welche IP-Adresse hat der Wechselrichter ?" 10 60 "${inverterip:-192.168.178.100}" 3>&1 1>&2 2>&3); then unset invertertype inverterip; return 1; fi
  fi

  if [[ ! -f /usr/local/sbin/setup_pv ]]; then
    if ! cond_redirect install -m 755 "${includesDir}/setup_pv" /usr/local/sbin; then echo "FAILED (install setup_pv)"; return 1; fi
  fi

  for component in things items rules; do
    if [[ ${1:-${invertertype}} == "none" ]]; then
      rm -f "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
    else
      cp "${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${invertertype}}.${component}" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      chown "${username:-openhabian}:${username:-openhabian}" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
    fi
  done

  sed -i "s|%IP|${2:-${inverterip}}|" "${OPENHAB_CONF:-/etc/openhab}/things/pv.things"
  
  if [[ $# -gt 2 ]]; then
      sed -i "s|%METERIP|${3:-${meterip}}|" "${OPENHAB_CONF:-/etc/openhab}/things/pv.things"
  fi

  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Operation successful" --msgbox "The Energy Management System is now setup to use a ${1:-${invertertype}} PV inverter." 8 80
  fi
=======
## Generate/copy openHAB config for a PV inverter
## Valid Arguments: kostal, sungrow
##
##    setup_inverter_config(String inverter)
##
setup_inverter_config() {
  for component in things items rules; do
    cp "${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1,,}.${component}" "${OPENHAB_CONF:-/etc/openhab}/${component}/"
  done
  whiptail --title "Operation successful" --msgbox "The Energy Management System is now setup to use a $1 inverter." 8 80
>>>>>>> 56fcb89 (Add menu 04 to setup storm.house EMS inverter config)
}

