#!/usr/bin/env bash

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
elif [[ "$1" = "unattended_debug_maximum" ]]; then
  UNATTENDED=1
  MAXDEBUG=1
else
  INTERACTIVE=1
fi

# Include all subscripts
# shellcheck source=/dev/null
for shfile in $BASEDIR/functions/*.bash; do source "$shfile"; done

if [[ -n "$UNATTENDED" ]]; then
  if [ -n "DEBUGMAX" ]; then
    set -x
  fi
  # apt/dpkg commands will not try interactive dialogs
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
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
  java_install_or_update "$java_arch"
  openhab2_setup
  vim_openhab_syntax
  nano_openhab_syntax
  multitail_openhab_scheme
  srv_bind_mounts
  permissions_corrections
  misc_system_settings
# not per default for now
# if is_pione || is_pitwo || is_pithree || is_pithreeplus || is_pifour || is_pine64; then init_zram_mounts install; fi
#  samba_setup
  clean_config_userpw
#  frontail_setup
else
  apt-get update
  whiptail_check
  load_create_config
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
