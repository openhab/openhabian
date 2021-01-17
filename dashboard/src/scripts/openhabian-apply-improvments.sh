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

# update openhabian.conf to have latest set of parameters
update_openhabian_conf

# apt/dpkg commands will not try interactive dialogs
export DEBIAN_FRONTEND="noninteractive"
 
#Install packages if needed
if [[ $1 == "packageSystemPackages" ]]; then
  #Install system packages
  basic_packages
  needed_packages
elif [[ $1 == "packageBashVim" ]]; then
  #install bash vim packages
  bashrc_copy
  vimrc_copy
  vim_openhab_syntax
  nano_openhab_syntax
  multitail_openhab_scheme
elif [[ $1 == "packageSystemTweaks" ]]; then
  #install system tweaks
  srv_bind_mounts
  misc_system_settings
elif [[ $1 == "packagePermissions" ]]; then
  #install permission fixes
  permissions_corrections
elif [[ $1 == "packageFireMotD" ]]; then
  #install FireMotD
  firemotd_setup
elif [[ $1 == "packageSamba" ]]; then
  #install samba shares
  samba_setup
else 
  echo error invalid parameter passed to this function.
fi
  
# shellcheck disable=SC2164
# vim: filetype=sh
