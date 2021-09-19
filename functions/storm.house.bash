#!/usr/bin/env bash

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
}

