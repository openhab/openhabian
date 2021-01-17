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

# avoid potential crash when deleting directory we started from
OLDWD="$(pwd)"
cd /opt || exit 1

# apt/dpkg commands will not try interactive dialogs
export DEBIAN_FRONTEND="noninteractive"

echo The following command was called: 
echo $1 $2 $3 $4 $5
$1 $2 $3 $4 $5

# shellcheck disable=SC2164
# vim: filetype=sh
