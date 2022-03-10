#!/usr/bin/env bash

## Generate/copy openHAB config for a PV inverter and optional a meter, too
## Valid Arguments: pvmanuell | kostal | sungrow | solaredge | fronius
##                  IP address of inverter
##     (optional)   IP address of meter
##
##    setup_pv_config(String inverter type,String inverter IP,String meter IP)
##
setup_pv_config() {
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"


  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] inverter installation... "
    if [[ -z "${1:-$invertertype}" ]]; then echo "SKIPPED (no inverter defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$invertertype}" ]]; then
        if ! invertertype="$(whiptail --title "Wechselrichter Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wechselrichtertyp aus" 15 80 0 "sunspec" "generisch, SunSpec kompatibel" "kostal" "Kostal Plenticore" "sungrow" "Sungrow SH RT" "solaredge" "SolarEdge SE (ungetestet)" "fronius" "Fronius Symo (ungetestet)" "pvmanuell" "keiner (manuelle Konfiguration)" 3>&1 1>&2 2>&3)"; then unset invertertype; return 1; fi
    fi
    if ! inverterip=$(whiptail --title "Wechselrichter IP" --inputbox "Welche IP-Adresse hat der Wechselrichter ?" 10 60 "${inverterip:-192.168.178.100}" 3>&1 1>&2 2>&3); then unset invertertype inverterip; return 1; fi
  fi

  if [[ ! -f /usr/local/sbin/setup_pv_config ]]; then
    if ! cond_redirect ln -s "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_pv_config; then echo "FAILED (install setup_pv_config script)"; return 1; fi
  fi

  for component in things items rules; do
    if [[ ${1:-${invertertype}} == "none" ]]; then
      rm -f "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
    else
      cp "${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${invertertype}}.${component}" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      if [[ $(whoami) == "root" ]]; then
        chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
        chmod 664 "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      fi
    fi
  done
  cp "${OPENHAB_CONF:-/etc/openhab}/icons/STORE/${1:-${invertertype}}.png" /etc/openhab/icons/inverter.png
  if [[ $(whoami) == "root" ]]; then
    chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/icons/inverter.png
    chmod 664 "${OPENHAB_CONF:-/etc/openhab}/icons/inverter.png"
  fi

  sed -i "s|%IP|${2:-${inverterip}}|" "${OPENHAB_CONF:-/etc/openhab}/things/pv.things"
  
  if [[ $# -gt 2 ]]; then
      sed -i "s|%METERIP|${3:-${meterip}}|" "${OPENHAB_CONF:-/etc/openhab}/things/pv.things"
  fi

  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt einen ${1:-${invertertype}} Wechselrichter." 8 80
  fi
}

## Generate/copy openHAB config for a wallbox
## Valid Arguments: wbmanuell | openwb | goe | myenergi
##                  IP address of wallbox
##
##    setup_wb_config(String wallbox type,String wallbox IP)
##
setup_wb_config() {
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"


  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] wallbox installation... "
    if [[ -z "${1:-$wallboxtype}" ]]; then echo "SKIPPED (no wallbox defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$wallboxtype}" ]]; then
        if ! wallboxtype="$(whiptail --title "Wallbox Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wallboxtyp aus" 12 80 0 "openwb" "openWB" "goe" "go-E Charger" "myenergi" "myEnergi Zappi" "keba" "KeContact P20/P30" "wbmanuell" "keine (manuelle Konfiguration)" 3>&1 1>&2 2>&3)"; then unset wallboxtype; return 1; fi
    fi
    if ! wallboxip=$(whiptail --title "Wallbox IP" --inputbox "Welche IP-Adresse hat die Wallbox ?" 10 60 "${wallboxip:-192.168.178.200}" 3>&1 1>&2 2>&3); then unset wallboxtype wallboxip; return 1; fi
  fi

  if [[ ! -f /usr/local/sbin/setup_wb_config ]]; then
    if ! cond_redirect ln -s "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_wb_config; then echo "FAILED (install setup_wb_config script)"; return 1; fi
    #if ! cond_redirect install -m 755 "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_wb_config; then echo "FAILED (install setup_wb_config script)"; return 1; fi
  fi

  for component in things items rules; do
    if [[ ${1:-${wallboxtype}} == "none" ]]; then
      rm -f "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
    else
      cp "${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${wallboxtype}}.${component}" "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
      if [[ $(whoami) == "root" ]]; then
        chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
        chmod 664 "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
      fi
    fi
  done

  sed -i "s|%IP|${2:-${wallboxip}}|" "${OPENHAB_CONF:-/etc/openhab}/things/wb.things"
  
  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt eine ${1:-${wallboxtype}} Wallbox." 8 80
  fi
}

