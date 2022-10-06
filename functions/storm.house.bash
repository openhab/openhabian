#!/usr/bin/env bash

## TODO: (unfertig), implementiert nich nicht die Spec !

## #1=bat & #2=hybrid -> pv=#1 & bat=#1, ansonsten was definiert wurde
## #1=meter & #2=inverter -> meter=#1, ansonsten was definiert wurde

## Generate/copy openHAB config for a PV inverter
##
## Valid Arguments:
## #1 = pv | bat | meter      ## alternativ: hybrid | pvonly | batonly 
## #2 = device type #1=pv:    e3dc | fronius | huawei | kostal | senec | sma | solaredge | solax | sungrow (default) | victron | custom
##                  #1=bat:   hybrid (default) |
##                            e3dc | fronius | huawei | kostal | senec | sma | solaredge | solax | sungrow | victron | custom
##                  #1=meter: inverter (default) | sma | smashm | custom
## #3 = device ip
## #4 = modbus ID of device
## #5 (optional) cardinal number of inverter
##
##    setup_pv_config(String element,String device type,String device IP,Number modbus ID,Number inverter number)
##
setup_pv_config() {
  local includesDir="${BASEDIR:-/opt/openhabian}/includes"
  local inverterPNG="${OPENHAB_CONF:-/etc/openhab}/icons/classic/inverter.png"
  local srcfile
  local destfile


  if [[ -n "$UNATTENDED" ]]; then
    echo -n "$(timestamp) [storm.house] inverter installation... "
    if [[ -z "${2:-$invertertype}" ]]; then echo "SKIPPED (no inverter defined)"; return 1; fi
  fi

  if [[ "${2:-$batterytype}" == "hybrid" ]]; then
    bat=${1:-${invertertype}}
  else
    bat=${2:-${batterytype}}
  fi
  for configdomain in things items rules; do
    for device in pv bat meter; do
      # shellcheck disable=SC2154
      case "$device" in
        pv) default=${invertertype}; ip=${inverterip}; mbid=${invertermbid};;
        bat) default=${batterytype}; ip=${batteryip}; mbid=${batterymbid};;
        meter) default=${metertype}; ip=${meterip}; mbid=${metermbid};;
      esac
      srcfile="${OPENHAB_CONF:-/etc/openhab}/${configdomain}/STORE/${device}/${bat:-${default}}.${configdomain}"
      destfile="${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
      if [[ ${bat:-${default}} == "custom" && -f ${destfile} ]]; then
          break
      fi

      rm -f "$destfile"
      if [[ -f ${srcfile} ]]; then
        cp "$srcfile" "${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
        if [[ $(whoami) == "root" ]]; then
          chown "${username:-openhabian}:openhab" "${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
          chmod 664 "${OPENHAB_CONF:-/etc/openhab}/${configdomain}/${device}.${configdomain}"
        fi
      fi
    done

    # TODO .things, .items, (.rules auch?) in pv/ bat/ meter/ aufteilen
    # %MBID einbauen
    sed -i "s|%IP|${3:-${ip}}|" -i "s|%MBID|${4:-${mbid}}|" "${OPENHAB_CONF:-/etc/openhab}/things/${device}.things"
    #if [[ $# -gt 4 ]]; then
    #    sed -i "s|%METERIP|${3:-${meterip}}|" "${OPENHAB_CONF:-/etc/openhab}/things/${device}.things"
    #fi
  done


  srcfile="${OPENHAB_CONF:-/etc/openhab}/icons/STORE/inverter/${1:-${invertertype}}.png"
  if [[ -f $srcfile ]]; then
    cp "$srcfile" "$inverterPNG"
  fi
  if [[ $(whoami) == "root" ]]; then
    chown "${username:-openhabian}:openhab" "$inverterPNG"
    chmod 664 "$inverterPNG"
  fi


  echo "OK"
  # TODO: welche Ausgabe bei Änderung des Batterie-WR? des Meters?
  # TODO: invertertype,batterytype(?),metertype(?) in build-image/openhabian*.conf
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "Installation erfolgreich" --msgbox "Das Energie Management System nutzt jetzt einen ${1:-${invertertype}} Wechselrichter." 8 80
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
  local temp
  local pkg=https://storm.house/download/latest_update.zip
  local introText="ACHTUNG\\n\\nWenn Sie eigene Änderungen der Benutzeroberfläche und/oder auf Ebene von openHAB vorgenommen haben, wählen Sie \"Änderungen beibehalten\". Das Update würde alle diese Änderungen ansonsten überschreiben, sie wäre verloren.\\In jedem Fall wird vor dem Update ein Backup der aktuellen Konfiguration erstellt und Ihre Einstellungen und historischen Daten bleiben erhalten. Sollten Sie das Upgrade rückgängig machen wollen, können Sie jederzeit über den Menüpunkt 51 die Konfiguration des EMS von vor dem Update wieder einspielen."
  local TextVoll="ACHTUNG:\\nWollen Sie wirklich die Konfiguration vollständig durch die aktuelle Version des EMS ersetzen?\\nAlles, was Sie über die grafische Benutzeroberfläche über Einstellungen hinausgehend verändert haben, geht dann verloren. Das betrifft beispielsweise, aber nicht nur, alle Things, Items und Regeln, die Sie selbst angelegt haben."
  local TextTeil="ACHTUNG:\\nWollen Sie das EMS bzw. den von storm.house bereitgestellten Teil Ihres EMS wirklich durch die aktuelle Version ersetzen?"

  temp="$(mktemp "${TMPDIR:-/tmp}"/update.XXXXX)"
  if ! cond_redirect wget -nv -O "$temp" "$pkg"; then echo "FAILED (download patch)"; rm -f "$temp"; return 1; fi
  backup_openhab_config

  # Abfrage ob Voll- oder Teilimport mit Warnung dass eigene Änderungen überschrieben werden
  if whiptail --title "EMS Update" --yes-button "komplettes Update" --no-button "Änderungen beibehalten" --yesno "$introText" 17 80; then
    if ! whiptail --title "EMS komplettes Update" --yes-button "JA, DAS WILL ICH" --cancel-button "Abbrechen" --defaultno --yesno "$TextVoll" 13 80; then echo "CANCELED"; return 1; fi
    restore_openhab_config "$temp"
  else
    if ! whiptail --title "EMS Update" --yes-button "Ja" --cancel-button "Abbrechen" --defaultno --yesno "$TextTeil" 10 80; then echo "CANCELED"; return 1; fi
    ( cd /etc/openhab || return 1
    ln -sf . conf
    unzip -o "$temp" conf/things\* conf/items\* conf/rules\* )
  fi

  rm -f "$temp conf"
  if [[ -n "$INTERACTIVE" ]]; then
    whiptail --title "EMS update erfolgreich" --msgbox "Das storm.house Energie Management System ist jetzt auf dem neuesten Stand." 8 80
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

