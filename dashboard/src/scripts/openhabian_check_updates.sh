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

# update openhabian.conf to have latest set of parameters
update_openhabian_conf

branch="${clonebranch:-HEAD}"

echo "[openHABian] openHABian configuration tool version: $(get_git_revision)"
echo -n "$(timestamp) [openHABian] Checking for changes in origin branch ${branch}... "
if ! git -C "${BASEDIR:-/opt/openhabian}" config user.email 'openhabian@openHABian'; then echo "FAILED (git email)"; return 1; fi
if ! git -C "${BASEDIR:-/opt/openhabian}" config user.name 'openhabian'; then echo "FAILED (git user)"; return 1; fi
if ! git -C "${BASEDIR:-/opt/openhabian}" fetch --quiet origin; then echo "FAILED (fetch origin)"; return 1; fi

if [[ $(git -C "${BASEDIR:-/opt/openhabian}" rev-parse "$branch") == $(git -C "${BASEDIR:-/opt/openhabian}" rev-parse @\{u\}) ]]; then
    echo "OK"
else
    echo "Updates available..."
fi
  
# vim: filetype=sh