#!/usr/bin/env bash
# shellcheck disable=SC2034,2154

# openHABian - hassle-free openHAB installation and configuration tool
# for the Raspberry Pi and other Linux systems
#
# Documentation: https://www.openhab.org/docs/installation/openhabian.html
# Development: http://github.com/openhab/openhabian
# Discussion: https://community.openhab.org/t/13379
#

configFile="/etc/openhabian.conf"
if ! [[ -f $configFile ]]; then
  cp /opt/openhabian/build-image/openhabian.conf "$configFile"
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
timestamp() { printf "%(%F_%T_%Z)T\\n" "-1"; }

# Make sure only root can run our script
echo -n "$(timestamp) [openHABian] Checking for root privileges... "
if [[ $EUID -ne 0 ]]; then
  echo
  echo "This script must be run as root. Did you mean 'sudo openhabian-config'?" 1>&2
  echo "More info: https://www.openhab.org/docs/installation/openhabian.html"
  exit 1
else
  echo "OK"
fi

# shellcheck disable=SC1090
source "$configFile"

# script will be called with 'unattended' argument by openHABian images else retrieve values from openhabian.conf
if [[ $1 == "unattended" ]]; then
  UNATTENDED="1"
  SILENT="1"
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

export UNATTENDED SILENT DEBUGMAX INTERACTIVE

# Include all subscripts
# shellcheck source=/dev/null
for shfile in "${BASEDIR:-/opt/openhabian}"/functions/*.bash; do source "$shfile"; done

# avoid potential crash when deleting directory we started from
OLDWD="$(pwd)"
cd /opt || exit 1

# update openhabian.conf to have latest set of parameters
update_openhabian_conf

# Fix cpufreq being removed by uninstalling raspi-config, could be removed
# eventually (late 2022?) once we are sure that there are no longer systems that
# have the issue.
if ! [[ -f /etc/init.d/openhabian-config ]]; then
  cond_redirect wget -nv -O /etc/init.d/openhabian-config https://github.com/RPi-Distro/raspi-config/raw/master/debian/raspi-config.init
  sed -i -e 's/raspi-config/openhabian-config/' /etc/init.d/openhabian-config
fi

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
  install_tailscale "install" && setup_tailscale
  misc_system_settings
  add_admin_ssh_key
  firemotd_setup
  java_install "${java_opt:-11}"
  openhab_setup "${clonebranch:-openHAB3}" "stable"
  import_openhab_config
  openhab_shell_interfaces
  vim_openhab_syntax
  nano_openhab_syntax
  multitail_openhab_scheme
  srv_bind_mounts
  samba_setup
  clean_config_userpw
  frontail_setup
  custom_frontail_log "add" "$custom_log_files"
  jsscripting_npm_install "openhab_rules_tools"
  zram_setup
  exim_setup
  nut_setup
  permissions_corrections
  setup_mirror_SD "install"
  install_cleanup
else
  apt_update
  whiptail_check
  load_create_config
  openhabian_console_check
  openhabian_update_check
  jsscripting_npm_check "openhab"
  jsscripting_npm_check "openhab_rules_tools"
  bashrc_copy    # TODO: Remove sometime mid 2022
  while show_main_menu; do
    true
  done
  system_check_default_password
  echo -e "$(timestamp) [openHABian] We hope you got what you came for! See you again soon ;)"
fi
# shellcheck disable=SC2164
cd "$OLDWD"

# vim: filetype=sh
