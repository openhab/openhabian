#!/usr/bin/env bash

# openHABian - hassle-free openHAB 2 installation and configuration tool
# for the Raspberry Pi and other Linux systems
#
# Documentation: https://www.openhab.org/docs/installation/openhabian.html
# Development: http://github.com/openhab/openhabian
# Discussion: https://community.openhab.org/t/13379
#


# Find the absolute script location dir (e.g. BASEDIR=/opt/openhabian)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  BASEDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$BASEDIR/$SOURCE"
done
BASEDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTNAME="$(basename $SOURCE)"

REPOSITORYURL="https://github.com/openhab/openhabian"
CONFIGFILE="/etc/openhabian.conf"

# Trap CTRL+C, CTRL+Z and quit singles
trap '' SIGINT SIGQUIT SIGTSTP

# Log with timestamp
timestamp() { date +"%F_%T_%Z"; }

# Make sure only root can run our script
echo -n "$(timestamp) [openHABian] Checking for root privileges... "
if [[ $EUID -ne 0 ]]; then
  echo ""
  echo "This script must be run as root. Did you mean 'sudo openhabian-config'?" 1>&2
  echo "More info: https://www.openhab.org/docs/installation/openhabian.html"
  exit 1
else
  echo "OK"
fi

# script will be called with 'unattended' argument by openHABian images
if [[ "$1" = "unattended" ]]; then
  UNATTENDED=1
  SILENT=1
elif [[ "$1" = "unattended_debug" ]]; then
  UNATTENDED=1
else
  INTERACTIVE=1
fi

# Include all subscripts
# shellcheck source=/dev/null
for shfile in $BASEDIR/functions/*.sh; do source "$shfile"; done

if [[ -n "$UNATTENDED" ]]; then
  load_create_config
  timezone_setting
  locale_setting
  hostname_change
  if is_pi; then memory_split; enable_rpi_audio; fi
  if is_pine64; then pine64_platform_scripts; fi
  if is_pine64; then pine64_fixed_mac; fi
  if is_pine64; then pine64_fix_systeminfo_binding; fi
  basic_packages
  needed_packages
  bashrc_copy
  vimrc_copy
  firemotd_setup
  java_zulu
  openhab2_setup
  vim_openhab_syntax
  nano_openhab_syntax
  multitail_openhab_scheme
  srv_bind_mounts
  permissions_corrections
  misc_system_settings
  samba_setup
  clean_config_userpw
  nodejs_setup
  frontail_setup
else
  whiptail_check
  load_create_config
  openhabian_hotfix
  ua-netinst_check
  openhabian_console_check
  openhabian_update_check
  while show_main_menu; do
    true
  done
  system_check_default_password
  echo -e "$(timestamp) [openHABian] We hope you got what you came for! See you again soon ;)"
fi

# vim: filetype=sh
