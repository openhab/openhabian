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
  local inverterPNG="${OPENHAB_CONF:-/etc/openhab}/icons/classic/inverter.png"
  local srcfile
  local destfile


  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] inverter installation... "
    if [[ -z "${1:-$invertertype}" ]]; then echo "SKIPPED (no inverter defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$invertertype}" ]]; then
        if ! invertertype="$(whiptail --title "Wechselrichter Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wechselrichtertyp aus" 15 80 0 "sunspec" "generisch, SunSpec kompatibel" "kostal" "Kostal Plenticore" "sungrow" "Sungrow SH RT" "solaredge" "SolarEdge SE (ungetestet)" "fronius" "Fronius Symo (ungetestet)" "pvmanuell" "manuelle Konfiguration" 3>&1 1>&2 2>&3)"; then unset invertertype; return 1; fi
    fi
    if ! inverterip=$(whiptail --title "Wechselrichter IP" --inputbox "Welche IP-Adresse hat der Wechselrichter ?" 10 60 "${inverterip:-192.168.178.100}" 3>&1 1>&2 2>&3); then unset invertertype inverterip; return 1; fi
  fi

  if [[ ! -f /usr/local/sbin/setup_pv_config  && $(whoami) == "root" ]]; then
    if ! cond_redirect ln -fs "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_pv_config; then echo "FAILED (install setup_pv_config script)"; return 1; fi
  fi

  for component in things items rules; do
    #if [[ ${1:-${invertertype}} == "none" ]]; then
    srcfile="${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${invertertype}}.${component}"
    destfile="${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
    rm -f $destfile
    if [[ -f ${srcfile} ]]; then
      cp "$srcfile" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      if [[ $(whoami) == "root" ]]; then
        chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
        chmod 664 "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      fi
    fi
  done


  srcfile="${OPENHAB_CONF:-/etc/openhab}/icons/STORE/${1:-${invertertype}}.png"
  if [[ -f $srcfile ]]; then
    cp "$srcfile" "$inverterPNG"
  fi
  if [[ $(whoami) == "root" ]]; then
    chown "${username:-openhabian}:openhab" "$inverterPNG"
    chmod 664 "$inverterPNG"
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
## Valid Arguments:
##
## * wallbox type (from EVCC)
## abl cfos easee eebus evsewifi go-e heidelberg keba mcc nrgkick-bluetooth nrgkick-connect
## openwb phoenix-em-eth phoenix-ev-eth phoenix-ev-ser simpleevse wallbe warp
## * IP address of wallbox
## * car type (from EVCC)
## audi bmw carwings citroen ds opel peugeot fiat ford kia hyundai mini nissan niu tesla
## renault ovms porsche seat skoda enyaq vw id volvo tronity
## * car name
##
##    setup_wb_config(String wallbox typ,String wallbox IP,String auto Ttyp,String autoname)
##
setup_wb_config() {
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"
  local srcfile
  local destfile
  local evcccfg="${HOME:-/home/admin}/evcc.yaml"


  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] wallbox installation... "
    if [[ -z "${1:-$wallboxtyp}" ]]; then echo "SKIPPED (no wallbox defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$wallboxtyp}" ]]; then
      if ! wallboxtyp="$(whiptail --title "Wallbox Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wallboxtyp aus" 12 80 0 "abl" "ABL eMH1" "cfos" "cFos PowerBrain charger" "easee" "Easee Home Wallbox" "evsewifi" "Wallboxen mit SimpleEVSE Controller" "go-e" "go-E Charger" "heidelberg" "Heidelberg Energy Control" "keba" "KEBA KeContact P20/P30 und BMW Wallboxen" "mcc" "Mobile Charger Connect (Audi, Bentley Porsche)" "nrgkick-bluetooth" "NRGkick Wallbox mit Bluetooth"
          "nrgkick-connect" "NRGkick Wallbox mit zusätzlichem NRGkick Connect Modul" "openwb" "openWB Wallbox via MQTT" "phoenix-em-eth" "Wallboxen mit dem Phoenix EM-CP-PP-ETH Controller" "phoenix-ev-eth" "Wallboxen mit dem Phoenix EV-CC-**-ETH Controller" "phoenix-ev-ser" "Wallboxen mit dem Phoenix EV-CC-***-SER seriellen Controller" "simpleevse" "Wallboxen mit dem SimpleEVSE Controller" "wallbe" "Wallbe Eco Wallbox" "warp" "Tinkerforge Warp/Warp Pro" "wbmanuell" "manuelle Konfiguration" 3>&1 1>&2 2>&3)"; then unset wallboxtyp wallboxip autotyp autoname; return 1; fi
    fi
    if ! wallboxip=$(whiptail --title "Wallbox IP" --inputbox "Welche IP-Adresse hat die Wallbox ?" 10 60 "${wallboxip:-192.168.178.200}" 3>&1 1>&2 2>&3); then unset wallboxtyp wallboxip autotyp autoname; return 1; fi
    if ! autotyp="$(whiptail --title "Auswahl Autohersteller" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Hersteller Ihres Fahrzeugs aus" 12 80 0 "audi" "Audi" "bmw" "BMW" "carwings" "Nissan z.B. Leaf vor 2019" "citroen" "Citroen" "ds" "DS" "opel" "Opel" "peugeot" "Peugeot" "fiat" "Fiat, Alfa Romeo" "ford" "Ford" "kia" "Kia Motors" "hyundai" "Hyundai" "mini" "Mini" "nissan" "neue Nissan Modelle ab 2019" "niu" "NIU" "tesla" "Tesla Motors" "renault" "Renault, Dacia" "ovms" "Open Vehicle Monitoring System" "porsche" "Porsche" "seat" "Seat" "skoda" "Skoda Auto" "enyaq" "Skoda Enyac" "vw" "Volkswagen ausser ID-Modelle" "id" "Volkswagen ID-Modelle" "volvo" "Volvo" "tronity" "Fahrzeuge über Tronity" "custom" "manuelle Konfiguration" 3>&1 1>&2 2>&3)"; then unset wallboxtyp wallboxip autotyp autoname; return 1; fi
    if ! autoname=$(whiptail --title "Auto Modell" --inputbox "Automodell" 10 60 "${autoname:-tesla}" 3>&1 1>&2 2>&3); then unset wallboxtyp wallboxip autotyp autoname; return 1; fi
  fi

  if [[ ! -f /usr/local/sbin/setup_wb_config && $(whoami) == "root" ]]; then
    if ! cond_redirect ln -fs "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_wb_config; then echo "FAILED (install setup_wb_config script)"; return 1; fi
  fi

  for component in things items rules; do
    #if [[ ${1:-${wallboxtyp}} == "none" ]]; then
    rm -f "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
    srcfile="${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${wallboxtyp}}.${component}"
    destfile="${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
    if ! [[ -f ${srcfile} ]]; then
      srcfile="${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/evcc.${component}"
    fi
    if [[ -f ${srcfile} ]]; then  # evcc.rules existiert ggfs. nicht
      cp "${srcfile}" "${destfile}"
      if [[ $(whoami) == "root" ]]; then
        chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
        chmod 664 "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
      fi
    fi
  done

  cp "${includesDir}/EVCC/evcc.yaml-template" "$evcccfg"
  sed -i "s|%WBTYP|${1:-${wallboxtyp}}|" "$evcccfg"
  sed -i "s|%IP|${2:-${wallboxip}}|" "$evcccfg"
  sed -i "s|%AUTOTYP|${3:-${autotyp}}|" "$evcccfg"
  
  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt eine ${1:-${wallboxtyp}} Wallbox mit einem ${3:-${autotyp}}." 8 80
  fi
}

