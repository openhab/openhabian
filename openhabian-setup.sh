#!/usr/bin/env bash
# shellcheck disable=SC2034

# openHABian - hassle-free openHAB installation and configuration tool
# for the Raspberry Pi and other Linux systems
#
# Documentation: https://www.openhab.org/docs/installation/openhabian.html
# Development: http://github.com/openhab/openhabian
# Discussion: https://community.openhab.org/t/13379
#

CONFIGFILE="/etc/openhabian.conf"
if ! [[ -f $CONFIGFILE ]]; then
  cp /opt/openhabian/openhabian.conf.dist "$CONFIGFILE"
fi

# Find the absolute script location dir (e.g. BASEDIR=/opt/openhabian)
SOURCE="${BASH_SOURCE[0]}"
while [[ -h $SOURCE ]]; do
  BASEDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="${BASEDIR:-/opt/openhabian}/$SOURCE"
done
BASEDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTNAME="$(basename "$SOURCE")"

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

# shellcheck disable=SC1090
source "$CONFIGFILE"

# script will be called with 'unattended' argument by openHABian images else retrieve values from openhabian.conf
if [[ $1 == "unattended" ]]; then
  UNATTENDED="1"
  SILENT="1"
elif [[ $1 == "migration" ]]; then
  MIGRATION="1"
  INTERACTIVE="1"
else
  INTERACTIVE="1"
fi

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


export UNATTENDED MIGRATION SILENT DEBUGMAX INTERACTIVE

# Include all subscripts
# shellcheck source=/dev/null
for shfile in "${BASEDIR:-/opt/openhabian}"/functions/*.bash; do source "$shfile"; done

# avoid potential crash when deleting directory we started from
OLDWD="$(pwd)"
cd /opt || exit 1

# update openhabian.conf to have latest set of parameters
update_openhabian_conf

# disable ipv6 if requested in openhabian.conf (eventually reboots)
config_ipv6

if [[ -n "$UNATTENDED" ]]; then
  # apt/dpkg commands will not try interactive dialogs
  export DEBIAN_FRONTEND="noninteractive"
  wait_for_apt_to_finish_update
  load_create_config
  change_swapsize
  timezone_setting
  setup_ntp "enable"
  locale_setting
  hostname_change
  memory_split
  enable_rpi_audio
  basic_packages
  needed_packages
  bashrc_copy
  vimrc_copy
  firemotd_setup
  java_install_or_update "${java_opt:-Zulu11-32}"
  openhab_setup "openHAB3" "stable"
  vim_openhab_syntax
  nano_openhab_syntax
  multitail_openhab_scheme
  srv_bind_mounts
  misc_system_settings
  samba_setup
  permissions_corrections
  add_admin_ssh_key
  clean_config_userpw
  frontail_setup
  zram_setup
  exim_setup
  install_tailscale "install" && setup_tailscale
  setup_mirror_SD "install"
  install_cleanup
else
  apt_update
  whiptail_check
  load_create_config
  openhabian_console_check
  openhabian_update_check
  if [[ -n "$MIGRATION" ]]; then
    bashrc_copy
  fi
  while show_main_menu; do
    true
  done
  system_check_default_password
  echo -e "$(timestamp) [openHABian] We hope you got what you came for! See you again soon ;)"
fi
# shellcheck disable=SC2164
cd "$OLDWD"

# vim: filetype=sh
