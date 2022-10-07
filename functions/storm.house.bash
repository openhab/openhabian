#!/usr/bin/env bash

## TODO: (unfertig), implementiert nich nicht die Spec !

## #1=bat & #2=hybrid -> pv=#1 & bat=#1, ansonsten was definiert wurde
## #1=meter & #2=inverter -> meter=#1, ansonsten was definiert wurde

## Generate/copy openHAB config for a PV inverter
##
## Valid Arguments:
## #1 = pv | bat | meter
## #2 = device type #1=pv:    e3dc | fronius | huawei | kostal | senec | sma | solaredge | solax | sungrow (default) | victron | custom
##                  #1=bat:   hybrid (default) |
##                            e3dc | fronius | huawei | kostal | senec | sma | solaredge | solax | sungrow | victron | custom
##                  #1=meter: inverter (default) | sma | smashm | custom
## #3 = device ip
## #4 = modbus ID of device
## #5 (optional when #2/#3 = "bat hybrid|meter|inverter"): inverter (see #1=pv)
## #5 (optional) cardinal number of inverter
## #5 (optional) Modbus ID of logger
##
##    setup_pv_config(String element,String device type,String device IP,Number modbus ID,Number inverter number)
##
setup_pv_config() {
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"
  local inverterPNG="${OPENHAB_CONF:-/etc/openhab}/icons/classic/inverter.png"
  local srcfile
  local destfile


  if [[ ! -f /usr/local/sbin/setup_pv_config && $(whoami) == "root" ]]; then
    if ! cond_redirect ln -fs "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_pv_config; then echo "FAILED (install setup_pv_config script)"; return 1; fi
  fi

  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] PV ${1} installation... "
    if [[ -z "${2:-$invertertype}" ]]; then echo "SKIPPED (no device defined)"; return 1; fi
  fi

  for configdomain in things items rules; do
    device="${1:-pv}"
    # shellcheck disable=SC2154
    case "${device}" in
      pv) default=${invertertype}; ip=${3:-inverterip}; mbid=${4:-${invertermodbusid}};;
      bat) default=${batterytype}; ip=${3:-batteryip}; mbid=${4:-${batterymodbusid}};;
      meter) default=${metertype}; ip=${3:-meterip}; mbid=${4:-${metermodbusid}};;
    esac

    file="${2:-${default}}"
    if [[ "${device}" == "bat" && "${2:-$batterytype}" == "hybrid" ]]; then
      file="inv/${5:-${invertertype}}"
    fi
    if [[ "${device}" == "meter" && "${2:-${metertype}}" == "inverter" ]]; then
      file="inv/${5:-${invertertype}}"
    fi

    srcfile="${OPENHAB_CONF:-/etc/openhab}/${configdomain}/STORE/${device}/${file:-${default}}.${configdomain}"
    destfile="${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
    rm -f "$destfile"

    if [[ -f ${srcfile} ]]; then
      cp "$srcfile" "${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
      if [[ $(whoami) == "root" ]]; then
        chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
        chmod 664 "${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
      fi

      if [[ "${device}" == "pv" && "${2:-$invertertype}" == "huaweilogger" ]]; then
        # %HUAWEI1 bzw 2 = 51000 + 25 * (MBID - 1) + 5 bzw 9 berechnen
        Erzeugung=$((51000 + 25 * (mbid - 1) + 5))
        PVStatus=$((Erzeugung + 4))
        sed -i "s|%HUAWEI1|${Erzeugung}|;s|%HUAWEI2|${PVStatus}|" "${destfile}"
        mbid="${5:-${loggermodbusid}}"  # diese ID muss angesprochen werden
      fi
      sed -i "s|%IP|${ip}|;s|%MBID|${mbid}|" "${destfile}"
    fi
  done


  if [[ "${device}" == "pv" ]]; then
    srcfile="${OPENHAB_CONF:-/etc/openhab}/icons/STORE/inverter/${2:-${invertertype}}.png"
    if [[ -f $srcfile ]]; then
      cp "$srcfile" "$inverterPNG"
    fi
    if [[ $(whoami) == "root" ]]; then
      chown "${username:-openhabian}:openhab" "$inverterPNG"
      chmod 664 "$inverterPNG"
    fi
  fi

  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt eine ${2:-${invertertype}} Konfiguration." 8 80
  fi
}


## Generate/copy openHAB config for a PV inverter and optional a meter, too
## Valid Arguments: e3dc | fronius | huawei | kostal | senec | sma | solaredge | solax | sungrow | victron | custom
##                  IP address of inverter
##     (optional)   IP address of meter
##
##    setup_inv_config(String inverter type,String inverter IP,String meter IP)
##
setup_inv_config() {
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"
  local inverterPNG="${OPENHAB_CONF:-/etc/openhab}/icons/classic/inverter.png"
  local srcfile
  local destfile


  if [[ ! -f /usr/local/sbin/setup_inv_config  && $(whoami) == "root" ]]; then
    if ! cond_redirect ln -fs "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_inv_config; then echo "FAILED (install setup_inv_config script)"; return 1; fi
  fi

  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] inverter installation... "
    if [[ -z "${1:-$invertertype}" ]]; then echo "SKIPPED (no inverter defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$invertertype}" ]]; then
      if ! invertertype="$(whiptail --title "Wechselrichter Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wechselrichtertyp aus" 18 100 9 "e3dc" "E3DC Hauskraftwerk" "fronius" "Fronius Symo" "huawei" "Huawei Sun 2000/Luna" "kostal" "Kostal Plenticore" "senec" "Senec Home" "sma" "SMA (experimental)" "solaredge" "SolarEdge SE (noch in Arbeit)" "solax" "Solax X1/X3" "sungrow" "Sungrow SH RT" "victron" "Victron mit Gateway (experimental)" "custom" "manuelle Konfiguration" 3>&1 1>&2 2>&3)"; then unset invertertype; return 1; fi
    fi
    if ! inverterip=$(whiptail --title "Wechselrichter IP" --inputbox "Welche IP-Adresse hat der Wechselrichter ?" 10 60 "${inverterip:-192.168.178.100}" 3>&1 1>&2 2>&3); then unset invertertype inverterip; return 1; fi
  fi

  if [[ "${2:-$batterytype}" == "hybrid" ]]; then
      bat = ${1:-${invertertype}}
  else
    bat=${2:-${batterytype}}
  fi
  for configdomain in things items rules; do
    device="${1:-pv}"
    # shellcheck disable=SC2154
    case "${device}" in
      pv) default=${invertertype}; ip=${inverterip}; mbid=${invertermbid};;
      bat) default=${batterytype}; ip=${batteryip}; mbid=${batterymbid};;
      meter) default=${metertype}; ip=${meterip}; mbid=${metermbid};;
    esac

  for component in things items rules; do
    srcfile="${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${invertertype}}.${component}"
    destfile="${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
    if [[ ${1:-${invertertype}} == "custom" && -f ${destfile} ]]; then
        break
    fi
    rm -f "$destfile"

    if [[ "${device}" == "meter" && "${2:-${default}}" == "inverter" ]]; then
      break
    fi

    if [[ -f ${srcfile} ]]; then
      cp "$srcfile" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      if [[ $(whoami) == "root" ]]; then
        chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
        chmod 664 "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      fi
    fi

    sed -i "s|%IP|${3:-${ip}}|;s|%MBID|${4:-${mbid}}|" "${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
  done


  if [[ "${device}" == "pv" ]]; then
    srcfile="${OPENHAB_CONF:-/etc/openhab}/icons/STORE/inverter/${2:-${invertertype}}.png"
    if [[ -f $srcfile ]]; then
      cp "$srcfile" "$inverterPNG"
    fi
    if [[ $(whoami) == "root" ]]; then
      chown "${username:-openhabian}:openhab" "$inverterPNG"
      chmod 664 "$inverterPNG"
    fi
  fi

  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt eine ${2:-${invertertype}} Konfiguration." 8 80
  fi
}


## TODO: als einzelnes Skript benötigt oder wird dies Teil von setup_pv_config() ?

## Generate/copy openHAB config for a Smart Meter
## Valid Arguments: none | viaInverter | sma | smashm | custom
##                  IP address of meter
##
##    setup_meter_config(String device type,String device IP)
##
setup_meter_config() {
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"
  local linkName="/usr/local/sbin/setup_meter_config"

  if [[ ! -f ${linkName} && $(whoami) == "root" ]]; then
    if ! cond_redirect ln -fs "${includesDir}/setup_ems_hw" ${linkName}; then echo "FAILED (install ${linkName} script)"; return 1; fi
  fi
}


## Generate/copy openHAB config for a PV inverter and optional a meter, too
## Valid Arguments: e3dc | fronius | huawei | kostal | senec | sma | solaredge | solax | sungrow | victron | custom
##                  IP address of inverter
##     (optional)   IP address of meter
##
##    setup_inv_config(String inverter type,String inverter IP,String meter IP)
##
setup_inv_config() {
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
      if ! invertertype="$(whiptail --title "Wechselrichter Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wechselrichtertyp aus" 18 100 9 "e3dc" "E3DC Hauskraftwerk" "fronius" "Fronius Symo" "huawei" "Huawei Sun 2000/Luna" "kostal" "Kostal Plenticore" "senec" "Senec Home" "sma" "SMA (experimental)" "solaredge" "SolarEdge SE (noch in Arbeit)" "solax" "Solax X1/X3" "sungrow" "Sungrow SH RT" "victron" "Victron mit Gateway (experimental)" "custom" "manuelle Konfiguration" 3>&1 1>&2 2>&3)"; then unset invertertype; return 1; fi
    fi
    if ! inverterip=$(whiptail --title "Wechselrichter IP" --inputbox "Welche IP-Adresse hat der Wechselrichter ?" 10 60 "${inverterip:-192.168.178.100}" 3>&1 1>&2 2>&3); then unset invertertype inverterip; return 1; fi
  fi

  if [[ ! -f /usr/local/sbin/setup_inv_config  && $(whoami) == "root" ]]; then
    if ! cond_redirect ln -fs "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_inv_config; then echo "FAILED (install setup_inv_config script)"; return 1; fi
  fi

  for component in things items rules; do
    srcfile="${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${invertertype}}.${component}"
    destfile="${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
    if [[ ${1:-${invertertype}} == "custom" && -f ${destfile} ]]; then
        break
    fi
    rm -f "$destfile"
    if [[ -f ${srcfile} ]]; then
      cp "$srcfile" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      if [[ $(whoami) == "root" ]]; then
        chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
        chmod 664 "${OPENHAB_CONF:-/etc/openhab}/${component}/pv.${component}"
      fi
    fi
  done


  srcfile="${OPENHAB_CONF:-/etc/openhab}/icons/STORE/inverter/${1:-${invertertype}}.png"
  if [[ -f $srcfile ]]; then
    cp "$srcfile" "$inverterPNG"
  fi
  if [[ $(whoami) == "root" ]]; then
    chown "${username:-openhabian}:openhab" "$inverterPNG"
    chmod 664 "$inverterPNG"
  fi


  srcfile="${OPENHAB_CONF:-/etc/openhab}/icons/STORE/inverter/${1:-${invertertype}}.png"
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
## #1 wallbox type (from EVCC)
## abl cfos easee eebus evsewifi go-e go-e-v3 heidelberg keba mcc nrgkick-bluetooth nrgkick-connect
## openwb phoenix-em-eth phoenix-ev-eth phoenix-ev-ser simpleevse wallbe warp
## #2 IP address of wallbox
## #3 EVCC token
## #4 car 1 type (from EVCC)
## audi bmw carwings citroen ds opel peugeot fiat ford kia hyundai mini nissan niu tesla
## renault ovms porsche seat skoda enyaq vw id volvo tronity
## #5 car 1 name
## #6 car 1 capacity
## #7 car 1 VIN Vehicle Identification Number
## #8 car 1 username in car manufacturer's online portal
## #9 car 1 password for account in car manufacturer's online portal
## #10 car 2 type (from EVCC)
## audi bmw carwings citroen ds opel peugeot fiat ford kia hyundai mini nissan niu tesla
## renault ovms porsche seat skoda enyaq vw id volvo tronity
## #11 car 2 name
## #12 car 2 capacity
## #13 car 2 VIN Vehicle Identification Number
## #14 car 2 username in car manufacturer's online portal
## #15 car 2 password for account in car manufacturer's online portal
## #16 grid usage cost per kWh in EUR ("0.40")
## #17 grid feedin compensation cost per kWh in EUR
##
##    setup_wb_config(String wallbox typ, .... )  - all arguments are of type String
##
setup_wb_config() {
  local temp
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"
  local wallboxPNG="${OPENHAB_CONF:-/etc/openhab}/icons/classic/wallbox.png"
  local srcfile
  local destfile
  local evccConfig="/home/${username:-openhabian}/evcc.yaml"


  if [[ ! -f /usr/local/sbin/setup_wb_config && $(whoami) == "root" ]]; then
    if ! cond_redirect ln -fs "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_wb_config; then echo "FAILED (install setup_wb_config script)"; return 1; fi
  fi

  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] wallbox installation... "
    if [[ -z "${1:-$wallboxtype}" ]]; then echo "SKIPPED (no wallbox defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$wallboxtype}" ]]; then
      if ! wallboxtype="$(whiptail --title "Wallbox Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wallboxtyp aus" 12 80 0 "abl" "ABL eMH1" "cfos" "cFos PowerBrain charger" "easee" "Easee Home Wallbox" "evsewifi" "Wallboxen mit SimpleEVSE Controller" "go-e" "go-E Charger" "heidelberg" "Heidelberg Energy Control" "keba" "KEBA KeContact P20/P30 und BMW Wallboxen" "mcc" "Mobile Charger Connect (Audi, Bentley Porsche)" "nrgkick-bluetooth" "NRGkick Wallbox mit Bluetooth"
          "nrgkick-connect" "NRGkick Wallbox mit zusätzlichem NRGkick Connect Modul" "openwb" "openWB Wallbox via MQTT" "phoenix-em-eth" "Wallboxen mit dem Phoenix EM-CP-PP-ETH Controller" "phoenix-ev-eth" "Wallboxen mit dem Phoenix EV-CC-**-ETH Controller" "phoenix-ev-ser" "Wallboxen mit dem Phoenix EV-CC-***-SER seriellen Controller" "simpleevse" "Wallboxen mit dem SimpleEVSE Controller" "wallbe" "Wallbe Eco Wallbox" "warp" "Tinkerforge Warp/Warp Pro" "wbcustom" "manuelle Konfiguration" 3>&1 1>&2 2>&3)"; then unset wallboxtype wallboxip autotyp autoname; return 1; fi
    fi
    if ! wallboxip=$(whiptail --title "Wallbox IP" --inputbox "Welche IP-Adresse hat die Wallbox ?" 10 60 "${wallboxip:-192.168.178.200}" 3>&1 1>&2 2>&3); then unset wallboxtype wallboxip autotyp autoname; return 1; fi
    if ! autotyp="$(whiptail --title "Auswahl Autohersteller" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Hersteller Ihres Fahrzeugs aus" 12 80 0 "audi" "Audi" "bmw" "BMW" "carwings" "Nissan z.B. Leaf vor 2019" "citroen" "Citroen" "ds" "DS" "opel" "Opel" "peugeot" "Peugeot" "fiat" "Fiat, Alfa Romeo" "ford" "Ford" "kia" "Kia Motors" "hyundai" "Hyundai" "mini" "Mini" "nissan" "neue Nissan Modelle ab 2019" "niu" "NIU" "tesla" "Tesla Motors" "renault" "Renault, Dacia" "ovms"
        "Open Vehicle Monitoring System" "porsche" "Porsche" "seat" "Seat" "skoda" "Skoda Auto" "enyaq" "Skoda Enyac" "vw" "Volkswagen ausser ID-Modelle" "id" "Volkswagen ID-Modelle" "volvo" "Volvo" "tronity" "Fahrzeuge über Tronity" 3>&1 1>&2 2>&3)"; then unset wallboxtype wallboxip autotyp autoname; return 1; fi
    if ! autoname=$(whiptail --title "Auto Modell" --inputbox "Automodell" 10 60 "${autoname:-tesla}" 3>&1 1>&2 2>&3); then unset wallboxtype wallboxip autotyp autoname; return 1; fi
  fi

  for component in things items rules; do
    rm -f "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
    srcfile="${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${wallboxtype}}.${component}"
    destfile="${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
    if [[ ${1:-${wallboxtype}} == "wbcustom" && -f ${destfile} ]]; then
      break
    fi
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

  srcfile="${OPENHAB_CONF:-/etc/openhab}/icons/STORE/wallbox/${1:-${wallboxtype}}.png"
  if [[ -f $srcfile ]]; then
    cp "$srcfile" "$wallboxPNG"
  fi
  if [[ $(whoami) == "root" ]]; then
    chown "${username:-openhabian}:openhab" "$wallboxPNG"
    chmod 664 "$wallboxPNG"
  fi

  temp="$(mktemp "${TMPDIR:-/tmp}"/evcc.XXXXX)"
  cp "${includesDir}/EVCC/evcc.yaml-template" "$temp"
  sed -e "s|%WBTYPE|${1:-${wallboxtype}}|;s|%IP|${2:-${wallboxip}}|;s|%TOKEN|${3:-${evcctoken}}|;s|%CARTYPE1|${4:-${cartype1}}|;s|%CARNAME1|${5:-${carname1}}|;s|%VIN1|${6:-${vin1}}|;s|%CARCAPACITY1|${7:-${carcapacity1}}|;s|%CARUSER1|${8:-${caruser1}}|;s|%CARPASS1|${9:-${carpass1}}|;s|%CARTYPE2|${10:-${cartype2}}|;s|%CARNAME2|${11:-${carname2}}|;s|%VIN2|${12:-${vin2}}|;s|%CARCAPACITY2|${13:-${carcapacity2}}|;s|%CARUSER2|${14:-${caruser2}}|;s|%CARPASS2|${15:-${carpass2}}|;s|%GRIDCOST|${16:-${gridcost}}|;s|%FEEDINCOMPENSATION|${17:-${feedincompensation}}|" "$temp" > "$evccConfig"
  rm -f "${temp}"
  
  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt eine ${1:-${wallboxtype}} Wallbox mit einem ${3:-${autotyp}}." 8 80
  fi
}

## Generate/copy openHAB config for a wallbox
## Valid Arguments: manuellWallbox | openwb
##                  IP address of wallbox
##
## * wallbox type (from EVCC)
## abl cfos easee eebus evsewifi go-e go-e-v3 heidelberg keba mcc nrgkick-bluetooth nrgkick-connect
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
  local wallboxPNG="${OPENHAB_CONF:-/etc/openhab}/icons/classic/wallbox.png"
  local srcfile
  local destfile
  local evcccfg="${HOME:-/home/admin}/evcc.yaml"


  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] wallbox installation... "
    if [[ -z "${1:-$wallboxtype}" ]]; then echo "SKIPPED (no wallbox defined)"; return 1; fi
  fi

  if [[ -n "$INTERACTIVE" ]]; then
    if [[ -z "${1:-$wallboxtype}" ]]; then
      if ! wallboxtype="$(whiptail --title "Wallbox Auswahl" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Wallboxtyp aus" 12 80 0 "abl" "ABL eMH1" "cfos" "cFos PowerBrain charger" "easee" "Easee Home Wallbox" "evsewifi" "Wallboxen mit SimpleEVSE Controller" "go-e" "go-E Charger" "heidelberg" "Heidelberg Energy Control" "keba" "KEBA KeContact P20/P30 und BMW Wallboxen" "mcc" "Mobile Charger Connect (Audi, Bentley Porsche)" "nrgkick-bluetooth" "NRGkick Wallbox mit Bluetooth"
          "nrgkick-connect" "NRGkick Wallbox mit zusätzlichem NRGkick Connect Modul" "openwb" "openWB Wallbox via MQTT" "phoenix-em-eth" "Wallboxen mit dem Phoenix EM-CP-PP-ETH Controller" "phoenix-ev-eth" "Wallboxen mit dem Phoenix EV-CC-**-ETH Controller" "phoenix-ev-ser" "Wallboxen mit dem Phoenix EV-CC-***-SER seriellen Controller" "simpleevse" "Wallboxen mit dem SimpleEVSE Controller" "wallbe" "Wallbe Eco Wallbox" "warp" "Tinkerforge Warp/Warp Pro" "wbcustom" "manuelle Konfiguration" 3>&1 1>&2 2>&3)"; then unset wallboxtype wallboxip autotyp autoname; return 1; fi
    fi
    if ! wallboxip=$(whiptail --title "Wallbox IP" --inputbox "Welche IP-Adresse hat die Wallbox ?" 10 60 "${wallboxip:-192.168.178.200}" 3>&1 1>&2 2>&3); then unset wallboxtype wallboxip autotyp autoname; return 1; fi
    if ! autotyp="$(whiptail --title "Auswahl Autohersteller" --cancel-button Cancel --ok-button Select --menu "\\nWählen Sie den Hersteller Ihres Fahrzeugs aus" 12 80 0 "audi" "Audi" "bmw" "BMW" "carwings" "Nissan z.B. Leaf vor 2019" "citroen" "Citroen" "ds" "DS" "opel" "Opel" "peugeot" "Peugeot" "fiat" "Fiat, Alfa Romeo" "ford" "Ford" "kia" "Kia Motors" "hyundai" "Hyundai" "mini" "Mini" "nissan" "neue Nissan Modelle ab 2019" "niu" "NIU" "tesla" "Tesla Motors" "renault" "Renault, Dacia" "ovms"
        "Open Vehicle Monitoring System" "porsche" "Porsche" "seat" "Seat" "skoda" "Skoda Auto" "enyaq" "Skoda Enyac" "vw" "Volkswagen ausser ID-Modelle" "id" "Volkswagen ID-Modelle" "volvo" "Volvo" "tronity" "Fahrzeuge über Tronity" 3>&1 1>&2 2>&3)"; then unset wallboxtype wallboxip autotyp autoname; return 1; fi
    if ! autoname=$(whiptail --title "Auto Modell" --inputbox "Automodell" 10 60 "${autoname:-tesla}" 3>&1 1>&2 2>&3); then unset wallboxtype wallboxip autotyp autoname; return 1; fi
  fi

  if [[ ! -f /usr/local/sbin/setup_wb_config && $(whoami) == "root" ]]; then
    if ! cond_redirect ln -fs "${includesDir}/setup_ems_hw" /usr/local/sbin/setup_wb_config; then echo "FAILED (install setup_wb_config script)"; return 1; fi
  fi

  for component in things items rules; do
    rm -f "${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
    srcfile="${OPENHAB_CONF:-/etc/openhab}/${component}/STORE/${1:-${wallboxtype}}.${component}"
    destfile="${OPENHAB_CONF:-/etc/openhab}/${component}/wb.${component}"
    if [[ ${1:-${wallboxtype}} == "wbcustom" && -f ${destfile} ]]; then
        break
    fi
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

  srcfile="${OPENHAB_CONF:-/etc/openhab}/icons/STORE/wallbox/${1:-${wallboxtype}}.png"
  if [[ -f $srcfile ]]; then
    cp "$srcfile" "$wallboxPNG"
  fi
  if [[ $(whoami) == "root" ]]; then
    chown "${username:-openhabian}:openhab" "$wallboxPNG"
    chmod 664 "$wallboxPNG"
  fi

  cp "${includesDir}/EVCC/evcc.yaml-template" "$evcccfg"
  sed -i "s|%WBTYP|${1:-${wallboxtype}}|" "$evcccfg"
  sed -i "s|%IP|${2:-${wallboxip}}|" "$evcccfg"
  sed -i "s|%AUTOTYP|${3:-${autotyp}}|" "$evcccfg"
  
  echo "OK"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt eine ${1:-${wallboxtype}} Wallbox mit einem ${3:-${autotyp}}." 8 80
  fi
}


## replace OH logo
## Attention needs to work across versions, logo has to be SVG (use inkscape to embed PNG in SVG)
##
##    replace_logo()
##
replace_logo() {
  # shellcheck disable=SC2125
  local JAR=/usr/share/openhab/runtime/system/org/openhab/ui/bundles/org.openhab.ui/3.*/org.openhab.ui-3.*.jar
  local logoInJAR=app/images/openhab-logo.svg
  local logoNew="${BASEDIR:-/opt/openhabian}/includes"/logo.svg

  rm -rf "$logoInJAR"
  # shellcheck disable=SC2086
  unzip -qq $JAR "$logoInJAR"
  cp "$logoNew" "$logoInJAR"
  # shellcheck disable=SC2086
  if ! cond_redirect zip -r $JAR "$logoInJAR"; then echo "FAILED (replace logo)"; fi
  rm -rf "$logoInJAR"
}


## Retrieve latest EMS code from website
##
##    update_ems()
##
update_ems() {
	local tempdir
	local temp
	local fullpkg=https://storm.house/download/initialConfig.zip
	local updateonly=https://storm.house/download/latestUpdate.zip
	local introText="ACHTUNG\\n\\nWenn Sie eigene Änderungen auf der Ebene von openHAB vorgenommen haben (die \"orangene\" Benutzeroberfläche),dann wählen Sie \"Änderungen beibehalten\". Dieses Update würde alle diese Änderungen ansonsten überschreiben, sie wäre verloren.\\Ihre Einstellungen und historischen Daten bleiben in beiden Fällen erhalten und vor dem Update wird ein Backup der aktuellen Konfiguration erstellt.  Sollten Sie das Upgrade rückgängig machen wollen, können Sie jederzeit über den Menüpunkt 51 die Konfiguration des EMS von vor dem Update wieder einspielen."
	local TextVoll="ACHTUNG:\\nWollen Sie wirklich die Konfiguration vollständig durch die aktuelle Version des EMS ersetzen?\\nAlles, was Sie über die grafische Benutzeroberfläche über Einstellungen hinausgehend verändert haben, geht dann verloren. Das betrifft beispielsweise, aber nicht nur, alle Things, Items und Regeln, die Sie selbst angelegt haben."
	local TextTeil="ACHTUNG:\\nWollen Sie das EMS bzw. den von storm.house bereitgestellten Teil Ihres EMS wirklich durch die aktuelle Version ersetzen?"

	tempdir="$(mktemp -d "${TMPDIR:-/tmp}"/updatedir.XXXXX)"
	temp="$(mktemp "${tempdir:-/tmp}"/updatefile.XXXXX)"
	backup_openhab_config

  # user credentials retten
  cp "${OPENHAB_USERDATA:-/var/lib/openhab}/jsondb/users.json" "${tempdir}/"
  # Settings retten
  cp -rp "${OPENHAB_USERDATA:-/var/lib/openhab}/persistence/mapdb" "${tempdir}/"

  # Abfrage ob Voll- oder Teilimport mit Warnung dass eigene Änderungen überschrieben werden
  if whiptail --title "EMS Update" --yes-button "komplettes Update" --no-button "Änderungen beibehalten" --yesno "$introText" 17 80; then
	  if ! whiptail --title "EMS komplettes Update" --yes-button "JA, DAS WILL ICH" --cancel-button "Abbrechen" --defaultno --yesno "$TextVoll" 13 80; then echo "CANCELED"; return 1; fi
	  if ! cond_redirect wget -nv -O "$temp" "$fullpkg"; then echo "FAILED (download patch)"; rm -f "$temp"; return 1; fi
	  restore_openhab_config "$temp"
  else
	  if ! whiptail --title "EMS Update" --yes-button "Ja" --cancel-button "Abbrechen" --defaultno --yesno "$TextTeil" 10 80; then echo "CANCELED"; return 1; fi
	  if ! cond_redirect wget -nv -O "$temp" "$updateonly"; then echo "FAILED (download patch)"; rm -f "$temp"; return 1; fi
	  ( cd /etc/openhab || return 1
	  ln -sf . conf
	  unzip -o "$temp" conf/things\* conf/items\* conf/rules\*
	  rm -f conf )
  fi

  # user credentials und Settings zurückspielen
  cp "${tempdir}/users.json" "${OPENHAB_USERDATA:-/var/lib/openhab}/jsondb/"
  cp -rp "${tempdir}/mapdb" "${OPENHAB_USERDATA:-/var/lib/openhab}/persistence/"
  if [[ -d /opt/zram/persistence.bind/mapdb ]]; then
	  cp -rp "${tempdir}/mapdb" /opt/zram/persistence.bind/
  fi

  permissions_corrections   # sicherheitshalber falls Dateien durch git nicht mehr openhab gehören
  if [[ -n "$INTERACTIVE" ]]; then
	  whiptail --title "EMS update erfolgreich" --msgbox "Das storm.house Energie Management System ist jetzt auf dem neuesten Stand." 8 80
  fi

  rm -rf "${tempdir}"
}


## Install non-standard bindings etc
##
##    install_extras()
##
install_extras() {
	local serviceTargetDir="/etc/systemd/system"
	local includesDir="${BASEDIR:-/opt/openhabian}/includes"
	local jar=org.openhab.binding.solarforecast-3.4.0-SNAPSHOT.jar
	local pkg="https://github.com/weymann/OH3-SolarForecast-Drops/blob/main/3.4/${jar}"
	local dest="/usr/share/openhab/addons/${jar}"


	version=$(dpkg -s 'openhab' 2> /dev/null | grep Version | cut -d' ' -f2 | cut -d'-' -f1 | cut -d'.' -f2)
	if [[ $version -lt 4 ]]; then
		if ! cond_redirect wget -nv -O "$dest" "$pkg"; then echo "FAILED (download solar forecast binding)"; rm -f "$dest"; return 1; fi
	fi

	cp -p "${includesDir}:openhab_rsa*" "${OPENHAB_USERDATA:-/var/lib/openhab}/etc/"

  # lc
  if ! cond_redirect install -m 644 -t "${serviceTargetDir}" "${includesDir}"/generic/lc.timer; then rm -f "$serviceTargetDir"/lc.{service,timer}; echo "FAILED (setup lc)"; return 1; fi
  if ! cond_redirect install -m 644 -t "${serviceTargetDir}" "${includesDir}"/generic/lc.service; then rm -f "$serviceTargetDir"/lc.{service,timer}; echo "FAILED (setup lc)"; return 1; fi
  if ! cond_redirect install -m 755 "${includesDir}/generic/lc" /usr/local/sbin; then echo "FAILED (install lc)"; return 1; fi
  if ! cond_redirect systemctl -q daemon-reload; then echo "FAILED (daemon-reload)"; return 1; fi
  if ! cond_redirect systemctl enable --now lc.timer lc.timer; then echo "FAILED (enable timed lc start)"; return 1; fi
}



##    activate_ems(String enable)
##
## * enable|disable
##
activate_ems() {
	if [[ $1 == "enable" ]]; then
		echo "Korrekte Lizenz, aktiviere ..."
		# shellcheck disable=SC2154
		curl -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "lizensiert" "http://${hostname}:8080/rest/items/LizenzStatus"
		# TODO: eventuell vorhandenen systemd timer löschen der nach 1 Monat modbus disabled
	else
		echo "Falsche Lizenz, deaktiviere ..."
		curl -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "KEINE" "http://${hostname}:8080/rest/items/LizenzStatus"
		# TODO: eventuell systemd timer setzen der in 1 Monat modbus disabled
		whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt eine ${1:-${wallboxtyp}} Wallbox mit einem ${3:-${autotyp}}." 8 80
	fi
}


## Retrieve licensing file from server
## valid arguments: username, password
## Webserver will return an self-encrypted script to contain file with the evcc sponsorship token
##
##    retrieve_license(String username, String password)
##
#retrieve_license() {
#  local licsrc="https://storm.house/liccheck"
#  local cryptlic="/etc/openhab/services/license"
#  local temp
#  local livekey="active"
#  local lifetimekey="lifetime"
#  local licuser=${1}
#  local licpass=${2}
#
#
#  temp="$(mktemp "${TMPDIR:-/tmp}"/update.XXXXX)"
#  # TODO;: Optionen für User + Passwort!!
#  if ! cond_redirect wget -nv --http-user="${licuser}" --http-password="${licpass}" -O "$cryptlic" "$licsrc"; then echo "FAILED (download licensing file)"; rm -f "$cryptlic"; return 1; fi
#
#  if [[ -f "$cryptlic" ]]; then
#	  # decrypten mit public Key der dazu in includes liegen muss
#	  # > $temp
#	  true;
#  fi
#  if grep -qs "^sponsortoken:[[:space:]]" "$lic"; then
#    token=$(grep -E '^sponsortoken' "$temp" |cut -d' '  -f2)
#    curl -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$token" "http://{hostname}:8080/rest/items/EVCCtoken"
#  fi
#
#  lic=$(grep -E '^sponsortoken' "$temp" |cut -d' '  -f2)
#  if [[ "$lic" != "$livekey" && "$lic" != "$lifetimekey" ]]; then
#    activate_ems disable
#  else
#    activate_ems enable
#  fi
#}

# Das Token ist ein mit dem EMS private key verschlüsselte Datei, die enthält:
# a) Username,
# b) eine Gültigkeitsdauer hat (oder "lifetime")
# c) optional das EVCC-Token des Users

# Erneuern ? per systemd-timer 1x wöchentlich holen

# TODO:
# wie gelangt ems-privkey nach /etc/ssl/private/ems.key ?
# wie Lizenz-Widget an/aus ?
# 
# systemd-timer, der 1x wöchentlich lizenz
# OPTION: systemd-timer, der modbus disabled
# wie Karenzzeit ?

## Retrieve licensing file from server
## valid arguments: username, password
## Webserver will return an self-encrypted script to contain file with the evcc sponsorship token
##
##    retrieve_license(String username, String password)
##
retrieve_license() {
  local licsrc="https://storm.house/licchk"
  local temp
  local deckey="/etc/ssl/private/ems.key"
  local lifetimekey="lifetime"
  local licuser=${1}
  local licfile="/etc/openhab/services/license"
  local httpuser=dummyuser
  local httppass=dummypass
  local licdir


  if [[ $licuser == "" ]]; then
    licuser=$(curl -X GET  http://localhost:8080/rest/items/LizenzUser|jq '.state' | tr -d '"')
  fi
  licdir="$(mktemp -d "${TMPDIR:-/tmp}"/lic.XXXXX)"
  ( cd "$licdir" || exit; 
  if ! cond_redirect wget -nv --http-user="${httpuser}" --http-password="${httppass}" "${licsrc}/${licuser}"; then echo "FAILED (download licensing file)"; rm -f "$licuser"; return 1; fi
  if [[ -f "$licuser" ]]; then
    # decrypten mit public Key der dazu in includes liegen muss
    # XOR mitgeliefert ist (durch rsaCrypt)
    # shellcheck disable=SC2091

    mv "$licuser" "${licuser}.enc.sh"
    chmod +x "${licuser}.enc.sh"
    # shellcheck disable=SC2091
    $(./"${licuser}.enc.sh" -i "$deckey")
    cp "${licuser}" "${licfile}"
  fi
  )

  if grep -qs "^sponsortoken:[[:space:]]" "$licfile"; then
    token=$(grep -E '^evcctoken' "$licfile" |cut -d' '  -f2)
    curl -X POST --header "Content-Type: text/plain" --header "Accept: application/json" -d "$token" "http://{hostname}:8080/rest/items/EVCCtoken"
  fi

  # wenn licfile im laufenden Monat heruntergeladen wird muss darin (nach Entschlüsseln) der 
  lic=$(grep -E '^emsuser' "$licfile" |cut -d' '  -f2)
  if [[ "$lic" != "$licuser" && "$lic" != "$lifetimekey" ]]; then
    activate_ems disable
  else
    activate_ems enable
  fi
}


## Install non-standard bindings etc
##
##    install_openhab_extras()
##
install_openhab_extras() {
  local jar=org.openhab.binding.solarforecast-3.4.0-SNAPSHOT.jar
  local pkg="https://github.com/weymann/OH3-SolarForecast-Drops/blob/main/3.4/${jar}"
  local dest="/usr/share/openhab/addons/${jar}"


  version=$(dpkg -s 'openhab' 2> /dev/null | grep Version | cut -d' ' -f2 | cut -d'-' -f1 | cut -d'.' -f2)
  if [[ $version -lt 4 ]]; then
    if ! cond_redirect wget -nv -O "$dest" "$pkg"; then echo "FAILED (download solar forecast binding)"; rm -f "$dest"; return 1; fi
  fi
}


## (unfertig)

##    evcc-sponsorship(String token)
##
##    valid argument: EVCC sponsor token
##
##    "sponsortoken: "-Zeile aus evcc.yaml rausgreppen und ersetzen
##    Aus UI bei Änderung des entsprechenden items per exec binding aufrufen
##    sowie aus retrieve_license heraus
##
evcc-sponsorship() {
  temp="$(mktemp "${TMPDIR:-/tmp}"/update.XXXXX)"
  local evccconfig="evcc.yaml"

  echo "$evccconfig"
}


## TODO:
## Systemd-timer, der retrieve_license 1x wöchentlich aufruft und ausführt

## (unfertig)

## Retrieve licensing file from server
## valid argument: username
## Webserver will return an self-encrypted script to contain files:
## * 
## * the evcc sponsorship token
##
##    retrieve_license(String username)
##
retrieve_license() {
  local licsrc="https://storm.house/${jar}"
  temp="$(mktemp "${TMPDIR:-/tmp}"/update.XXXXX)"
  local dest="/usr/share/openhab/addons/${jar}"

  if ! cond_redirect wget -nv -O "$dest" "$licsrc"; then echo "FAILED (download licensing file)"; rm -f "$dest"; return 1; fi
}

