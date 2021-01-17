#!/bin/bash

# Check config file
CONFIGFILE="/etc/openhabian.conf"
if ! [[ -f $CONFIGFILE ]]; then
  cp /opt/openhabian/openhabian.conf.dist "$CONFIGFILE"
fi

# Log with timestamp
timestamp() { date +"%F_%T_%Z"; }

# shellcheck disable=SC1090
source "$CONFIGFILE"

# shellcheck disable=SC2154
if [[ $debugmode == "off" ]]; then
  SILENT=1
  unset DEBUGMAX
elif [[ $debugmode == "on" ]]; then
  unset SILENT
  unset DEBUGMAX
elif [[ $debugmode == "maximum" ]]; then
  unset SILENT
  DEBUGMAX=1
  set -x
fi

# Include all subscripts
# shellcheck source=/dev/null
for shfile in "${BASEDIR:-/opt/openhabian}"/functions/*.bash; do source "$shfile"; done

# apt/dpkg commands will not try interactive dialogs
export DEBIAN_FRONTEND="noninteractive"
 
if [[ openhab2_is_installed == 1 ]]
then
  echo openHAB2
else
  echo openHAB3
fi
  
# vim: filetype=sh